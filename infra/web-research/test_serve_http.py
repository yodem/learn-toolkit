"""Unit tests for serve_http.py. Run inside the built image:
python -m unittest -v /app/test_serve_http.py
"""
import asyncio
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from starlette.applications import Starlette
from starlette.responses import PlainTextResponse
from starlette.routing import Route
from starlette.testclient import TestClient

import serve_http


class GuardUrlTests(unittest.TestCase):
    def test_guard_refuses_internal(self):
        for url in [
            "http://169.254.169.254/",
            "http://10.0.0.1/",
            "http://192.168.1.5/",
            "http://100.106.37.39:8765/",
            "http://127.0.0.1/",
            "http://[::1]/",
            "http://searxng:8080/",
            "http://wra:8765/",
        ]:
            with self.subTest(url=url):
                refusal = serve_http.guard_url(url)
                self.assertIsNotNone(refusal)
                self.assertIn("blocked by ssrf guard", refusal)

    def test_guard_refuses_more_internal_forms(self):
        for url in [
            "http://0.0.0.0/",
            "http://[fd00::1]/",
            "http://[fe80::1]/",
            "http://[::ffff:127.0.0.1]/",
            "http://SearXNG./",
            "http://localhost/",
            "http://no-such-host.invalid/",
        ]:
            with self.subTest(url=url):
                self.assertIsNotNone(serve_http.guard_url(url))

    def test_guard_allows_public(self):
        self.assertIsNone(serve_http.guard_url("https://example.com/"))

    def test_guard_rejects_non_http(self):
        self.assertIsNotNone(serve_http.guard_url("file:///etc/passwd"))
        self.assertIsNotNone(serve_http.guard_url("ftp://example.com/"))


class WrapToolTests(unittest.TestCase):
    def _call(self, fn, **kw):
        return asyncio.run(fn(**kw))

    def test_wrapper_blocks_and_passes(self):
        calls = []

        async def crawl_url(url: str, country: str = "") -> str:
            calls.append(url)
            return "content"

        wrapped = serve_http.guarded(crawl_url)
        self.assertIn("blocked by ssrf guard", self._call(wrapped, url="http://searxng:8080/"))
        self.assertEqual(calls, [])
        self.assertIn("country", self._call(wrapped, url="https://example.com/", country="USA"))
        self.assertEqual(self._call(wrapped, url="https://example.com/", country="de"), "content")
        self.assertEqual(self._call(wrapped, url="https://example.com/"), "content")

    def test_wrapper_checks_every_batch_url(self):
        async def batch_crawl_urls(urls: list[str]) -> str:
            return "content"

        wrapped = serve_http.guarded(batch_crawl_urls)
        out = self._call(wrapped, urls=["https://example.com/", "http://10.0.0.1/"])
        self.assertIn("blocked by ssrf guard", out)

    def test_api_docs_name_checked_only_when_url(self):
        async def api_docs(api_name: str) -> str:
            return "content"

        wrapped = serve_http.guarded(api_docs)
        self.assertEqual(self._call(wrapped, api_name="stripe"), "content")
        self.assertIn(
            "blocked by ssrf guard", self._call(wrapped, api_name="http://169.254.169.254/")
        )


def _inner():
    async def ok(request):
        return PlainTextResponse("inner")

    return Starlette(routes=[Route("/mcp", ok, methods=["GET", "POST"]), Route("/healthzX", ok)])


class AuthTests(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(serve_http.BearerAuth(_inner(), b"s3cret"))

    def test_auth_no_header(self):
        self.assertEqual(self.client.post("/mcp").status_code, 401)

    def test_auth_wrong_token(self):
        r = self.client.post("/mcp", headers={"Authorization": "Bearer wrong"})
        self.assertEqual(r.status_code, 401)

    def test_auth_empty_bearer(self):
        r = self.client.post("/mcp", headers={"Authorization": "Bearer "})
        self.assertEqual(r.status_code, 401)

    def test_auth_non_ascii_token(self):
        r = self.client.post(
            "/mcp", headers={"Authorization": "Bearer éé".encode("utf-8")}
        )
        self.assertEqual(r.status_code, 401)

    def test_auth_good_token(self):
        r = self.client.post("/mcp", headers={"Authorization": "Bearer s3cret"})
        self.assertEqual(r.status_code, 200)

    def test_auth_healthz_open(self):
        r = self.client.get("/healthz")
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.text, "ok")

    def test_auth_healthz_variants_need_token(self):
        self.assertEqual(self.client.get("/healthzX").status_code, 401)
        self.assertEqual(self.client.post("/healthz").status_code, 401)
        self.assertEqual(self.client.get("/mcp").status_code, 401)


class BuildAppTests(unittest.TestCase):
    def test_empty_token_exits(self):
        old = os.environ.get("WRA_TOKEN")
        os.environ["WRA_TOKEN"] = ""
        try:
            with self.assertRaises(SystemExit) as cm:
                serve_http.build_app()
            self.assertEqual(cm.exception.code, 1)
        finally:
            if old is None:
                os.environ.pop("WRA_TOKEN", None)
            else:
                os.environ["WRA_TOKEN"] = old

    def test_built_app_requires_token_and_registers_16_tools(self):
        os.environ["WRA_TOKEN"] = "unit-test-token"
        app = serve_http.build_app()
        with TestClient(app, base_url="http://localhost:8765") as client:
            self.assertEqual(client.get("/healthz").status_code, 200)
            self.assertEqual(client.post("/mcp", json={}).status_code, 401)
            r = client.post(
                "/mcp",
                json={"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {
                    "protocolVersion": "2025-03-26", "capabilities": {},
                    "clientInfo": {"name": "t", "version": "0"}}},
                headers={
                    "Authorization": "Bearer unit-test-token",
                    "Accept": "application/json, text/event-stream",
                },
            )
            self.assertEqual(r.status_code, 200, r.text)
            bad_host = client.post(
                "/mcp", json={}, headers={
                    "Authorization": "Bearer unit-test-token", "Host": "evil.example:8765"},
            )
            self.assertEqual(bad_host.status_code, 421)
        self.assertEqual(len(serve_http.mcp._tool_manager._tools), 16)


if __name__ == "__main__":
    unittest.main()
