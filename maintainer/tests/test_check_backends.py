import importlib.util
import json
import os
import pathlib
import shutil
import subprocess
import tempfile
import unittest

MAINT = pathlib.Path(__file__).resolve().parents[1]
ROOT = MAINT.parent / "plugins" / "learn-toolkit"
spec = importlib.util.spec_from_file_location("cb", MAINT / "check-backends.py")
cb = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cb)
REG = (MAINT / "tests" / "fixtures" / "toolRegistry.ts").read_text(encoding="utf-8")


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
        src = (MAINT / "check-backends.py").read_text(encoding="utf-8")
        self.assertNotIn("API_KEY", src)


class LintShell(unittest.TestCase):
    def test_lint_detects_prefix_when_rg_is_absent_from_path(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            temp = pathlib.Path(temp_dir)
            plugin = temp / "plugin"
            shutil.copytree(ROOT, plugin)
            skill = plugin / "skills" / "learn" / "SKILL.md"
            with skill.open("a", encoding="utf-8") as stream:
                stream.write("\nInjected test prefix: mcp__exa__web_search_exa\n")

            bin_dir = temp / "bin"
            bin_dir.mkdir()
            for command in ("python3", "grep", "dirname", "basename"):
                executable = shutil.which(command)
                self.assertIsNotNone(executable, f"test host needs {command}")
                (bin_dir / command).symlink_to(executable)

            env = os.environ.copy()
            env["PATH"] = str(bin_dir)
            result = subprocess.run(
                ["/bin/bash", str(plugin / "scripts" / "lint-skill.sh")],
                capture_output=True,
                text=True,
                env=env,
                check=False,
            )
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("FAIL: no-hardcoded-mcp-prefix", result.stdout)
            self.assertIsNone(shutil.which("rg", path=env["PATH"]))


class ReviewFixes(unittest.TestCase):
    def test_registry_parser_tolerates_reformatting(self):
        ts = 'export const R = {\n    web_search_v2_exa: {\n      group: "search",\n      name: "Web Search",\n    },\n    old_exa: {\n      name: "Old (Deprecated)",\n    },\n};\n'
        current, deprecated = cb.parse_exa_registry(ts)
        self.assertEqual(current, {"web_search_v2_exa"})
        self.assertEqual(deprecated, {"old_exa"})

    def test_unrecognised_registry_is_probe_error(self):
        def fetch(url, headers=None, body=None):
            return 200, "nothing parseable here", {}
        self.assertEqual(cb.exit_code(cb.run(fetch=fetch, offline=False)), 3)

    def test_malformed_snapshot_is_probe_error(self):
        original = cb.SNAPSHOT
        with tempfile.TemporaryDirectory() as temp_dir:
            bad = pathlib.Path(temp_dir) / "snap.json"
            bad.write_text("{ not json", encoding="utf-8")
            cb.SNAPSHOT = bad
            try:
                self.assertEqual(cb.exit_code(cb.run(fetch=None, offline=True)), 3)
            finally:
                cb.SNAPSHOT = original

    def test_lint_flags_deprecated_category_without_tool_name(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            plugin = pathlib.Path(temp_dir) / "plugin"
            shutil.copytree(ROOT, plugin)
            tech = plugin / "skills" / "learn" / "references" / "domains" / "tech.md"
            with tech.open("a", encoding="utf-8") as stream:
                stream.write('\nSearch with "category": "github" for repos.\n')
            result = subprocess.run(["/bin/bash", str(plugin / "scripts" / "lint-skill.sh")],
                                    capture_output=True, text=True, check=False)
            self.assertNotEqual(result.returncode, 0, result.stdout)
            self.assertIn("deprecated Exa category `github`", result.stdout)


if __name__ == "__main__":
    unittest.main()
