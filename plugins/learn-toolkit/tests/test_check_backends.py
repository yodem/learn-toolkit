import importlib.util
import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("cb", ROOT / "scripts" / "check-backends.py")
cb = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cb)
REG = (ROOT / "tests" / "fixtures" / "toolRegistry.ts").read_text(encoding="utf-8")


class Registry(unittest.TestCase):
    def test_parses_deprecated_and_current(self):
        current, deprecated = cb.parse_exa_registry(REG)
        self.assertIn("web_search_exa", current)
        self.assertIn("agent_run", current)
        self.assertIn("get_code_context_exa", deprecated)
        self.assertNotIn("web_fetch_exa", deprecated)


class Plugin(unittest.TestCase):
    def test_used_exa_tools_from_mcp_json(self):
        used = cb.used_exa_tools(ROOT / ".mcp.json")
        self.assertEqual(used, {"web_search_exa", "web_fetch_exa", "web_search_advanced_exa", "agent_run"})


class Compare(unittest.TestCase):
    def test_deprecated_use_is_breaking(self):
        findings = cb.compare_exa({"get_code_context_exa"}, {"web_search_exa"}, {"get_code_context_exa"})
        self.assertEqual(findings[0]["severity"], "breaking")

    def test_changed_live_tool_list_is_breaking(self):
        findings = cb.compare_live_exa({"web_search_exa"}, {"web_search_exa", "new_tool"})
        self.assertEqual(findings[0]["severity"], "breaking")

    def test_new_upstream_tool_is_info(self):
        findings = cb.compare_exa({"web_search_exa"}, {"web_search_exa", "brand_new_exa"}, set())
        self.assertEqual([item["severity"] for item in findings], ["info"])

    def test_version_change_is_info(self):
        findings = cb.compare_versions({"tavily-cli": "0.1.8"}, {"tavily-cli": "0.1.9"})
        self.assertEqual(findings[0]["severity"], "info")


class ExitCodes(unittest.TestCase):
    def test_probe_error_exit3(self):
        def down(url, headers=None, body=None):
            raise OSError("network down")
        report = cb.run(fetch=down, offline=False)
        self.assertEqual(cb.exit_code(report), 3)

    def test_clean_offline_exit0(self):
        report = cb.run(fetch=None, offline=True)
        self.assertEqual(cb.exit_code(report), 0, json.dumps(report, indent=1))


class NoSecrets(unittest.TestCase):
    def test_script_never_reads_api_keys(self):
        src = (ROOT / "scripts" / "check-backends.py").read_text(encoding="utf-8")
        self.assertNotIn("API_KEY", src)


if __name__ == "__main__":
    unittest.main()
