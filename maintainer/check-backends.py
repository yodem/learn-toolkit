#!/usr/bin/env python3
"""Weekly drift check for learn-toolkit's Exa and Tavily wiring. Never reads API keys.
Exit: 0 clean, 1 breaking drift, 2 informational drift, 3 probe error.
"""
import argparse
import json
import pathlib
import re
import subprocess
import sys
import urllib.error
import urllib.request
from urllib.parse import parse_qs, urlparse

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent / "plugins" / "learn-toolkit"  # the plugin being checked
SNAPSHOT = HERE / "backend-snapshot.json"
UA = "learn-toolkit-check/1.0"
EXA_REGISTRY = "https://raw.githubusercontent.com/exa-labs/exa-mcp-server/main/src/toolRegistry.ts"
TAVILY_MCP = "https://mcp.tavily.com/mcp/"
PACKAGES = {
    "tavily-cli": ("https://pypi.org/pypi/tavily-cli/json", ["info", "version"]),
    "tavily-python": ("https://pypi.org/pypi/tavily-python/json", ["info", "version"]),
    "exa-py": ("https://pypi.org/pypi/exa-py/json", ["info", "version"]),
    "tavily-mcp": ("https://registry.npmjs.org/tavily-mcp/latest", ["version"]),
    "exa-mcp-server": ("https://registry.npmjs.org/exa-mcp-server/latest", ["version"]),
}
DOC_INDEXES = {"exa": "https://exa.ai/docs/llms.txt", "tavily": "https://docs.tavily.com/llms.txt"}
DEPRECATED = {"get_code_context_exa", "company_research_exa", "people_search_exa", "linkedin_search_exa",
              "deep_search_exa", "crawling_exa", "deep_researcher_start", "deep_researcher_check"}


class ProbeError(RuntimeError):
    pass


def http_fetch(url, headers=None, body=None):
    h = {"User-Agent": UA, **(headers or {})}
    req = urllib.request.Request(url, data=body, headers=h, method="POST" if body else "GET")
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            return response.status, response.read().decode(), dict(response.headers)
    except urllib.error.HTTPError as exc:
        return exc.code, "", dict(exc.headers or {})


def parse_exa_registry(ts):
    """Return current and deprecated tool IDs from the Exa registry."""
    current, deprecated = set(), set()
    for tool, name in re.findall(r'^\s{2}([a-z_]+):\s*\{\s*name:\s*"([^"]+)"', ts, re.M):
        (deprecated if "deprecated" in name.lower() else current).add(tool)
    return current, deprecated


def used_exa_tools(mcp_json_path):
    data = json.loads(pathlib.Path(mcp_json_path).read_text(encoding="utf-8"))
    used = set()
    for server in data["mcpServers"].values():
        url = server.get("url", "")
        if "mcp.exa.ai" in url:
            used.update(tool for tool in parse_qs(urlparse(url).query).get("tools", [""])[0].split(",") if tool)
    return used


def _rpc(fetch, url, headers, method, params=None, session=None):
    import itertools
    payload = json.dumps({"jsonrpc": "2.0", "id": next(_rpc.ids), "method": method,
                          **({"params": params} if params is not None else {})}).encode()
    request_headers = {"Content-Type": "application/json", "Accept": "application/json, text/event-stream", **headers}
    if session:
        request_headers["mcp-session-id"] = session
    status, text, response_headers = fetch(url, request_headers, payload)
    if method.startswith("notifications/") and status < 400:
        return {}, response_headers.get("mcp-session-id", response_headers.get("Mcp-Session-Id", session))
    if status >= 400:
        raise ProbeError(f"{urlparse(url).netloc} returned HTTP {status}")
    session = response_headers.get("mcp-session-id", response_headers.get("Mcp-Session-Id", session))
    candidates = re.findall(r"(?m)^data:\s*(\{.*\})\s*$", text)
    if candidates:
        text = candidates[-1]
    try:
        obj = json.loads(text)
    except (ValueError, TypeError) as exc:
        raise ProbeError(f"invalid MCP response from {urlparse(url).netloc}") from exc
    if "error" in obj:
        raise ProbeError(f"MCP {method} failed at {urlparse(url).netloc}")
    return obj.get("result", {}), session


_rpc.ids = iter(range(1, 1000000))


def mcp_tools(fetch, url, headers):
    _, session = _rpc(fetch, url, headers, "initialize", {"protocolVersion": "2025-03-26", "capabilities": {},
                                                          "clientInfo": {"name": "learn-toolkit-check", "version": "1.0"}})
    _rpc(fetch, url, headers, "notifications/initialized", session=session)
    result, _ = _rpc(fetch, url, headers, "tools/list", session=session)
    return sorted(tool["name"] for tool in result.get("tools", []))


def compare_exa(used, current, deprecated, known=None):
    known = set(known or ())
    findings = [{"severity": "breaking", "check": "exa-tools", "detail": f"configured tool {name} is deprecated or absent upstream"}
                for name in sorted(used) if name in deprecated or name not in current]
    findings.extend({"severity": "info", "check": "exa-tools", "detail": f"new upstream tool {name} is not enabled"}
                    for name in sorted(current - used - deprecated - known))
    return findings


def compare_tavily(live, snapshot_list):
    findings = [{"severity": "breaking", "check": "tavily-tools", "detail": f"skill tool {name} is missing"}
                for name in ("tavily_search", "tavily_extract") if name not in live]
    findings.extend({"severity": "info", "check": "tavily-tools", "detail": f"new Tavily tool {name}"}
                    for name in sorted(set(live) - set(snapshot_list)))
    return findings


def compare_live_exa(configured, live):
    if set(configured) == set(live):
        return []
    return [{"severity": "breaking", "check": "exa-live-tools",
             "detail": "live Exa tools/list differs from configured tools="}]


def compare_versions(old, new):
    return [{"severity": "info", "check": "versions", "detail": f"{name}: {old.get(name, 'unknown')} → {version}"}
            for name, version in sorted(new.items()) if old.get(name) != version]


def compare_docs(old_links, new_links):
    added, removed = sorted(set(new_links) - set(old_links)), sorted(set(old_links) - set(new_links))
    changes = ([f"added: {', '.join(added[:20])}"] if added else []) + ([f"removed: {', '.join(removed[:20])}"] if removed else [])
    return [{"severity": "info", "check": "docs", "detail": detail} for detail in changes]


def _json_path(value, path):
    for key in path:
        value = value[key]
    return value


def _get_links(text):
    return sorted(set(re.findall(r'\]\((https?://[^)]+)\)', text)))


def run(fetch=http_fetch, offline=False):
    snapshot = json.loads(SNAPSHOT.read_text(encoding="utf-8")) if SNAPSHOT.exists() else {
        "versions": {}, "exa_known_tools": [], "tavily_tools": [], "doc_links": {}}
    findings = []
    try:
        lint = subprocess.run(["bash", str(ROOT / "scripts/lint-skill.sh")], capture_output=True, text=True)
        if lint.returncode:
            findings.append({"severity": "breaking", "check": "static-lint", "detail": "lint-skill.sh failed"})
        if offline:
            return {"status": "breaking" if findings else "clean", "findings": findings, "snapshot": snapshot}
        registry_status, registry_text, _ = fetch(EXA_REGISTRY)
        if registry_status != 200:
            raise ProbeError(f"Exa registry returned HTTP {registry_status}")
        current, deprecated = parse_exa_registry(registry_text)
        used = used_exa_tools(ROOT / ".mcp.json")
        findings.extend(compare_exa(used, current, deprecated, snapshot.get("exa_known_tools", [])))
        config = json.loads((ROOT / ".mcp.json").read_text(encoding="utf-8"))["mcpServers"]
        exa_url = next(server["url"] for server in config.values() if "mcp.exa.ai" in server.get("url", "") and "agent_run" not in server["url"])
        live_exa = mcp_tools(fetch, exa_url, {"x-api-key": ""})
        findings.extend(compare_live_exa(parse_qs(urlparse(exa_url).query).get("tools", [""])[0].split(","), live_exa))
        tavily_url = config["tavily"]["url"]
        tavily_live = mcp_tools(fetch, tavily_url, {"X-Tavily-Access-Mode": "keyless"})
        findings.extend(compare_tavily(tavily_live, snapshot.get("tavily_tools", [])))
        versions = {}
        for name, (url, path) in PACKAGES.items():
            status, body, _ = fetch(url)
            if status != 200: raise ProbeError(f"package version endpoint returned HTTP {status}")
            versions[name] = str(_json_path(json.loads(body), path))
        findings.extend(compare_versions(snapshot.get("versions", {}), versions))
        doc_links = {}
        for name, url in DOC_INDEXES.items():
            status, body, _ = fetch(url)
            if status != 200: raise ProbeError(f"{name} docs index returned HTTP {status}")
            doc_links[name] = _get_links(body)
            findings.extend(compare_docs(snapshot.get("doc_links", {}).get(name, []), doc_links[name]))
        current_snapshot = {"versions": versions, "exa_known_tools": sorted(current),
                            "tavily_tools": tavily_live, "doc_links": doc_links}
        report = {"status": "clean", "findings": findings, "snapshot": current_snapshot}
        report["status"] = "breaking" if any(f["severity"] == "breaking" for f in findings) else ("info" if findings else "clean")
        return report
    except Exception as exc:
        return {"status": "error", "findings": [{"severity": "error", "check": "probe", "detail": str(exc)}], "snapshot": snapshot}


def exit_code(report):
    status = report.get("status")
    return {"clean": 0, "breaking": 1, "info": 2, "error": 3}.get(status, 3)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--offline", action="store_true")
    parser.add_argument("--update-snapshot", action="store_true")
    args = parser.parse_args()
    report = run(offline=args.offline)
    if args.update_snapshot and exit_code(report) in (0, 2):
        SNAPSHOT.write_text(json.dumps(report["snapshot"], indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2, sort_keys=True) if args.json else f"{report['status']}: {len(report['findings'])} finding(s)")
    return exit_code(report)


if __name__ == "__main__":
    sys.exit(main())
