"""HTTP launcher for web-research-assistant: bearer auth + SSRF guard around the upstream FastMCP server.

Runs inside the container only. Every request except an exact `GET /healthz` needs
`Authorization: Bearer $WRA_TOKEN`. URL-taking tools refuse internal destinations.
"""
from __future__ import annotations

import asyncio
import functools
import hmac
import inspect
import ipaddress
import os
import re
import socket
import sys
from urllib.parse import urlsplit

REFUSAL = "Refused: blocked by ssrf guard"

# Compose service names, refused by name before any DNS lookup.
BLOCKED_NAMES = {"searxng", "wra", "localhost"}

BLOCKED_NETS = [
    ipaddress.ip_network(n)
    for n in (
        "0.0.0.0/8",
        "10.0.0.0/8",
        "100.64.0.0/10",  # CGNAT, includes Tailscale
        "127.0.0.0/8",
        "169.254.0.0/16",  # link-local, includes cloud metadata 169.254.169.254
        "172.16.0.0/12",
        "192.168.0.0/16",
        "::/128",
        "::1/128",
        "fc00::/7",
        "fe80::/10",
    )
]

COUNTRY_RE = re.compile(r"[A-Za-z]{2}")  # used with fullmatch ("$" would accept a trailing newline)
# check_service_status builds a URL from `service` (service_health.py:283, with only spaces, dots
# and dashes stripped), so `x@169254169254#` becomes an internal URL. Real names need none of this.
SERVICE_RE = re.compile(r"[A-Za-z0-9 ._-]{1,100}")
URL_TOOLS = (
    "crawl_url", "batch_crawl_urls", "stealth_scrape", "extract_data", "api_docs", "check_service_status",
)


def _ip_blocked(ip: ipaddress._BaseAddress) -> bool:
    if isinstance(ip, ipaddress.IPv6Address) and ip.ipv4_mapped is not None:
        ip = ip.ipv4_mapped
    return (
        any(ip in net for net in BLOCKED_NETS)
        or ip.is_loopback
        or ip.is_private
        or ip.is_link_local
        or ip.is_unspecified
        or ip.is_multicast
        or ip.is_reserved
    )


def guard_url(url: str) -> str | None:
    """Return a refusal text when `url` must not be fetched, else None."""
    # urlsplit and Chromium parse some URLs differently (backslash, userinfo, control chars),
    # so refuse the ambiguous forms outright instead of guessing which host gets fetched.
    if any(c == "\\" or ord(c) < 32 or ord(c) == 127 or c.isspace() for c in url):
        return f"{REFUSAL}: URL contains a backslash, whitespace or control character"
    try:
        parts = urlsplit(url)
        if "@" in parts.netloc:
            return f"{REFUSAL}: URLs with userinfo are not allowed"
        host = (parts.hostname or "").lower().rstrip(".")
    except ValueError:
        return f"{REFUSAL}: unparsable URL"
    if parts.scheme not in ("http", "https"):
        return f"{REFUSAL}: only http and https URLs are allowed"
    if not host:
        return f"{REFUSAL}: URL has no host"
    if host in BLOCKED_NAMES:
        return f"{REFUSAL}: internal host {host!r}"
    try:
        addrs = [ipaddress.ip_address(host)]
    except ValueError:
        try:
            infos = socket.getaddrinfo(host, None, proto=socket.IPPROTO_TCP)
        except OSError:
            return f"{REFUSAL}: host {host!r} does not resolve"
        addrs = [ipaddress.ip_address(i[4][0].split("%")[0]) for i in infos]
        if not addrs:
            return f"{REFUSAL}: host {host!r} does not resolve"
    for ip in addrs:
        if _ip_blocked(ip):
            return f"{REFUSAL}: {host!r} resolves to an internal address"
    return None


def guarded(fn):
    """Wrap a tool coroutine.

    Checks `url`, `urls`, the keys of `start_chars` (upstream fetches them too,
    server.py:512-513), `api_name` when it is a URL, `service` and `country`.
    """
    sig = inspect.signature(fn)

    @functools.wraps(fn)
    async def wrapper(*args, **kwargs):
        ba = sig.bind(*args, **kwargs)
        bound = ba.arguments
        targets = []
        if isinstance(bound.get("url"), str):
            targets.append(bound["url"])
        if isinstance(bound.get("urls"), (list, tuple)):
            targets.extend(u for u in bound["urls"] if isinstance(u, str))
        name = bound.get("api_name")
        if isinstance(name, str) and re.match(r"^\s*[A-Za-z][A-Za-z0-9+.-]*://", name):
            targets.append(name)
        for target in targets:
            refusal = await asyncio.to_thread(guard_url, target)
            if refusal:
                return refusal
        service = bound.get("service")
        if isinstance(service, str) and not SERVICE_RE.fullmatch(service):
            return f"{REFUSAL}: invalid service name"
        country = bound.get("country")
        if country and not COUNTRY_RE.fullmatch(country):
            return "Refused: country must be a two-letter ISO code or empty"
        notes = []
        offsets = bound.get("start_chars")
        if isinstance(offsets, dict):
            kept = {}
            for key, offset in offsets.items():
                refusal = await asyncio.to_thread(guard_url, str(key))
                if refusal:
                    notes.append(f"{refusal} (start_chars key dropped)")
                else:
                    kept[key] = offset
            if notes:
                bound["start_chars"] = kept
        result = await fn(*ba.args, **ba.kwargs)
        return "\n".join(notes + [result]) if notes else result

    return wrapper


class BearerAuth:
    """ASGI middleware: 401 on every HTTP request except an exact `GET /healthz`."""

    def __init__(self, app, token: bytes):
        if not token:
            raise ValueError("empty token")
        self.app = app
        self.token = token

    async def __call__(self, scope, receive, send):
        if scope["type"] == "lifespan":
            return await self.app(scope, receive, send)
        if scope["type"] != "http":
            if scope["type"] == "websocket":
                await send({"type": "websocket.close", "code": 1008})
            return
        if scope["method"] == "GET" and scope["path"] == "/healthz":
            return await self._respond(send, 200, b"ok")
        given = b""
        for key, value in scope["headers"]:
            if key == b"authorization":
                given = value
                break
        prefix = b"Bearer "
        if given.startswith(prefix) and hmac.compare_digest(given[len(prefix):], self.token):
            return await self.app(scope, receive, send)
        await self._respond(send, 401, b"unauthorized", [(b"www-authenticate", b"Bearer")])

    @staticmethod
    async def _respond(send, status, body, extra=()):
        headers = [(b"content-type", b"text/plain"), (b"content-length", str(len(body)).encode())]
        await send({"type": "http.response.start", "status": status, "headers": headers + list(extra)})
        await send({"type": "http.response.body", "body": body})


def _load_server():
    # Imported lazily so the guard and auth unit tests run without starting the upstream server.
    from searxng_mcp import server

    return server.mcp


mcp = None  # set by build_app()


def build_app():
    global mcp
    token = os.environ.get("WRA_TOKEN", "").strip()
    if not token:
        print("WRA_TOKEN is empty; refusing to start an open server", file=sys.stderr)
        raise SystemExit(1)

    from mcp.server.transport_security import TransportSecuritySettings

    mcp = _load_server()
    bind_ip = os.environ.get("WRA_BIND_IP", "").strip()
    hosts = ["localhost:8765", "127.0.0.1:8765"] + ([f"{bind_ip}:8765"] if bind_ip else [])
    mcp.settings.transport_security = TransportSecuritySettings(
        enable_dns_rebinding_protection=True, allowed_hosts=hosts, allowed_origins=[]
    )

    # PRIVATE API: FastMCP's tool registry. Safe only because upstream is pinned to one commit
    # (see docker-compose.yml). Re-check this when the pin moves. The wrapper keeps the original
    # signature (functools.wraps), and the schema is already built at registration, so tool
    # metadata is unchanged.
    tools = mcp._tool_manager._tools
    for name in URL_TOOLS:
        tools[name].fn = guarded(tools[name].fn)

    return BearerAuth(mcp.streamable_http_app(), token.encode())


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(build_app(), host="0.0.0.0", port=8765)  # container-internal; compose publishes the bind IP only
