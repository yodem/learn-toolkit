#!/usr/bin/env python3
"""Smoke client for the web-research backend. Stdlib only.

Exit codes: 0 every case passed, 1 a case failed, 2 could not connect.
The token is read from --token-file and is never printed.
"""
import argparse
import json
import re
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path
from urllib.parse import urlsplit

TOOLS_16 = {
    "web_search", "batch_web_search", "search_examples", "search_images", "crawl_url",
    "batch_crawl_urls", "stealth_scrape", "package_info", "package_search", "github_repo",
    "translate_error", "api_docs", "extract_data", "compare_tech", "get_changelog",
    "check_service_status",
}
PROMPTS = {"research_package", "debug_error", "compare_technologies", "evaluate_repository",
           "check_service_health"}
SSRF_URLS = ["http://searxng:8080/", "http://169.254.169.254/latest/meta-data/",
             "http://100.106.37.39:8765/healthz"]
MARKER = "blocked by ssrf guard"
CASES = ["healthz", "no_token_401", "wrong_token_401", "empty_bearer_401", "tools_16",
         "resources_prompts", "search_results", "stealth_js", "ssrf_blocked", "searxng_direct"]


class ConnectError(Exception):
    pass


def http(url, method="GET", headers=None, body=None, timeout=120):
    """Return (status, headers, text). HTTP error statuses are returned, not raised."""
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers=headers or {})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, r.headers, r.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, e.headers, e.read().decode("utf-8", "replace")
    except (urllib.error.URLError, OSError) as e:
        raise ConnectError(f"cannot connect to {urlsplit(url).netloc}: {type(e).__name__}") from None


def parse_body(text, req_id):
    text = text.strip()
    if text.startswith("{"):
        return json.loads(text)
    for line in text.splitlines():
        if line.startswith("data:"):
            try:
                msg = json.loads(line[5:].strip())
            except ValueError:
                continue
            if msg.get("id") == req_id:
                return msg
    raise RuntimeError("no JSON-RPC response with the expected id in the body")


class Mcp:
    def __init__(self, url, token):
        self.url = url
        self.base = {"Authorization": f"Bearer {token}", "Content-Type": "application/json",
                     "Accept": "application/json, text/event-stream"}
        self.sid = None
        self.n = 0

    def _headers(self):
        h = dict(self.base)
        if self.sid:
            h["Mcp-Session-Id"] = self.sid
        return h

    def start(self):
        status, hdrs, text = http(self.url, "POST", self._headers(), {
            "jsonrpc": "2.0", "id": 0, "method": "initialize",
            "params": {"protocolVersion": "2025-03-26", "capabilities": {},
                       "clientInfo": {"name": "wra-smoke", "version": "1"}}})
        if status != 200:
            raise RuntimeError(f"initialize returned HTTP {status}")
        self.sid = hdrs.get("Mcp-Session-Id")
        http(self.url, "POST", self._headers(),
             {"jsonrpc": "2.0", "method": "notifications/initialized"})

    def call(self, method, params=None):
        self.n += 1
        status, _, text = http(self.url, "POST", self._headers(), {
            "jsonrpc": "2.0", "id": self.n, "method": method, "params": params or {}})
        if status != 200:
            raise RuntimeError(f"{method} returned HTTP {status}")
        msg = parse_body(text, self.n)
        if "error" in msg:
            raise RuntimeError(f"{method} error: {msg['error'].get('message')}")
        return msg["result"]

    def tool(self, name, args):
        res = self.call("tools/call", {"name": name, "arguments": args})
        text = "\n".join(c.get("text", "") for c in res.get("content", []))
        return bool(res.get("isError")), text


def check(cond, msg):
    if not cond:
        raise AssertionError(msg)


def post_status(url, auth):
    headers = {"Content-Type": "application/json", "Accept": "application/json, text/event-stream"}
    if auth is not None:
        headers["Authorization"] = auth
    return http(url, "POST", headers, {"jsonrpc": "2.0", "id": 1, "method": "ping"})[0]


def run_case(name, url, token, session, compose_file):
    base = url.rsplit("/mcp", 1)[0]
    if name == "healthz":
        status, _, text = http(base + "/healthz")
        check(status == 200 and text.strip() == "ok", f"healthz returned {status}")
    elif name == "no_token_401":
        check(post_status(url, None) == 401, "request without token was not 401")
    elif name == "wrong_token_401":
        check(post_status(url, "Bearer wrong-" + token[::-1][:8]) == 401, "wrong token was not 401")
    elif name == "empty_bearer_401":
        check(post_status(url, "Bearer ") == 401, "empty bearer was not 401")
    elif name == "tools_16":
        names = {t["name"] for t in session().call("tools/list")["tools"]}
        check(names == TOOLS_16, f"tool set differs: missing {sorted(TOOLS_16 - names)}, "
                                 f"extra {sorted(names - TOOLS_16)}")
    elif name == "resources_prompts":
        s = session()
        templates = s.call("resources/templates/list")["resourceTemplates"]
        prompts = {p["name"] for p in s.call("prompts/list")["prompts"]}
        check(len(templates) >= 4, f"only {len(templates)} resource templates")
        check(PROMPTS <= prompts, f"missing prompts {sorted(PROMPTS - prompts)}")
    elif name == "search_results":
        err, text = session().tool("web_search", {"query": "python asyncio tutorial", "reasoning": "smoke"})
        check(not err, "web_search returned isError")
        hosts = [urlsplit(u).hostname for u in re.findall(r"https://[^\s)\]>\"']+", text)]
        check(any(h and h != "searxng" for h in hosts), "no https:// result URL in web_search output")
    elif name == "stealth_js":
        err, text = session().tool("stealth_scrape", {"url": "https://quotes.toscrape.com/js/", "reasoning": "smoke"})
        check(not err and "Albert Einstein" in text, "JS-rendered 'Albert Einstein' not found")
    elif name == "ssrf_blocked":
        s = session()
        for target in SSRF_URLS:
            _, text = s.tool("crawl_url", {"url": target, "reasoning": "smoke"})
            check(MARKER in text, f"crawl_url on {target} was not refused")
    elif name == "searxng_direct":
        code = ("import json,urllib.request as u;"
                "r=json.load(u.urlopen('http://searxng:8080/search?q=python+asyncio&format=json',timeout=30));"
                "print(sum(1 for x in r.get('results',[]) if x.get('url')))")
        out = subprocess.run(["docker", "compose", "-f", compose_file, "exec", "-T", "wra",
                              "python", "-c", code], capture_output=True, text=True, timeout=90)
        check(out.returncode == 0 and out.stdout.strip().isdigit() and int(out.stdout) >= 1,
              "SearXNG returned no results (or docker exec failed)")
    else:
        raise ValueError(f"unknown case {name}")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--url", required=True, help="e.g. http://100.106.37.39:8765/mcp")
    ap.add_argument("--token-file", required=True)
    ap.add_argument("--case", nargs="+", required=True, choices=CASES)
    ap.add_argument("--compose-file", default=str(Path(__file__).with_name("docker-compose.yml")),
                    help="used by the searxng_direct case")
    args = ap.parse_args()
    token = Path(args.token_file).read_text().strip()

    cache = {}

    def session():
        if "s" not in cache:
            m = Mcp(args.url, token)
            m.start()
            cache["s"] = m
        return cache["s"]

    failed = False
    for name in args.case:
        try:
            run_case(name, args.url, token, session, args.compose_file)
            print(f"PASS {name}")
        except ConnectError as e:
            print(f"ERROR {name}: {e}")
            return 2
        except Exception as e:  # noqa: BLE001 - report any failure as a failed case
            msg = str(e).replace(token, "***") if token else str(e)
            print(f"FAIL {name}: {msg}")
            failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
