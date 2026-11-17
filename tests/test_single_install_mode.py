from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class SingleInstallModeTests(unittest.TestCase):
    def test_active_instructions_resolve_the_skill_root_vault(self) -> None:
        for path in (ROOT / "SKILL.md", ROOT / "AGENTS.md", ROOT / "README.md"):
            content = path.read_text(encoding="utf-8")
            self.assertIn("vault/", content, str(path))
        self.assertIn("junto a esta skill", (ROOT / "SKILL.md").read_text(encoding="utf-8"))
        self.assertTrue((ROOT / "vault").is_dir())
        self.assertFalse((ROOT / "vault/.ato-ai-skill-mem-version.yml").exists())

    def test_retired_interfaces_are_historical_and_not_distributed(self) -> None:
        history = ROOT / "references/history"
        self.assertTrue((history / "README.md").is_file())
        for name in (
            "runtime-boundary.md",
            "capability-contract.md",
            "change-control-contract.md",
            "python-cli.md",
            "integrations/codex/SKILL.md",
            "integrations/microsoft-copilot/SKILL.md",
        ):
            self.assertTrue((history / name).is_file(), name)

        for name in (
            "scripts/bootstrap.sh",
            "scripts/bootstrap.ps1",
            "scripts/package-microsoft-copilot.py",
            "pyproject.toml",
            "src/ato_ai_mem",
            "templates/integrations",
        ):
            self.assertFalse((ROOT / name).exists(), name)

    def test_vault_tools_do_not_accept_scope_selectors(self) -> None:
        for path in (ROOT / "scripts/vault.sh", ROOT / "scripts/vault.ps1"):
            content = path.read_text(encoding="utf-8")
            self.assertNotIn("--source", content, str(path))
            self.assertNotIn("--target", content, str(path))
            self.assertNotIn("mem/vault", content, str(path))


if __name__ == "__main__":
    unittest.main()
