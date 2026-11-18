from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class SingleInstallModeTests(unittest.TestCase):
    def test_active_instructions_resolve_the_skill_root_vault(self) -> None:
        for path in (ROOT / "SKILL.md", ROOT / "AGENTS.md", ROOT / "README.md"):
            content = path.read_text(encoding="utf-8")
            self.assertIn("vault/", content, str(path))
        self.assertIn("junto a este `SKILL.md`", (ROOT / "SKILL.md").read_text(encoding="utf-8"))
        self.assertTrue((ROOT / "vault").is_dir())
        self.assertFalse((ROOT / "vault/.ato-ai-skill-mem-version.yml").exists())

    def test_skill_identity_and_clone_target_are_explicit(self) -> None:
        skill = (ROOT / "SKILL.md").read_text(encoding="utf-8")
        interface = (ROOT / "agents/openai.yaml").read_text(encoding="utf-8")
        readme = (ROOT / "README.md").read_text(encoding="utf-8")

        self.assertIn("name: local-mem", skill)
        self.assertIn("Módulo Local de Memoria", skill)
        self.assertIn("no busques ni mezcles memoria de otros proyectos, plugins o agentes", skill)
        self.assertIn('display_name: "Módulo Local de Memoria"', interface)
        self.assertIn("$local-mem", interface)
        self.assertIn("allow_implicit_invocation: true", interface)
        self.assertIn("ato-ai-skill-mem.git local-mem", readme)

    def test_two_instances_check_only_their_adjacent_vault(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            temp_root = Path(temporary_directory)
            first_instance = temp_root / "first-plugin" / "local-mem"
            second_instance = temp_root / "second-plugin" / "local-mem"

            for instance in (first_instance, second_instance):
                scripts = instance / "scripts"
                scripts.mkdir(parents=True)
                shutil.copy2(ROOT / "scripts/vault.sh", scripts / "vault.sh")
                shutil.copy2(ROOT / "VERSION", instance / "VERSION")
                shutil.copy2(ROOT / "VAULT_FORMAT", instance / "VAULT_FORMAT")

            shutil.copytree(ROOT / "vault", first_instance / "vault")
            (second_instance / "vault").mkdir()

            first_check = subprocess.run(
                [str(first_instance / "scripts/vault.sh"), "check"],
                cwd=second_instance,
                capture_output=True,
                text=True,
            )
            second_check = subprocess.run(
                [str(second_instance / "scripts/vault.sh"), "check"],
                cwd=first_instance,
                capture_output=True,
                text=True,
            )

            self.assertEqual(first_check.returncode, 0, first_check.stdout + first_check.stderr)
            self.assertIn("vault.state: valid", first_check.stdout)
            self.assertNotEqual(second_check.returncode, 0, second_check.stdout + second_check.stderr)

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

    def test_local_codex_configuration_is_not_tracked_or_distributed(self) -> None:
        tracked = subprocess.run(
            ["git", "ls-files", "--", ".codex/"],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        )
        self.assertEqual(tracked.stdout.strip(), "")
        self.assertIn(".codex/", (ROOT / ".gitignore").read_text(encoding="utf-8"))
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        self.assertIn("No copies configuración local (`.codex/`)", readme)

    def test_legacy_vault_migration_is_manual_and_linked(self) -> None:
        migration = ROOT / "references/legacy-vault-migration.md"
        self.assertTrue(migration.is_file())
        content = migration.read_text(encoding="utf-8")
        for phrase in ("mem/vault/", "respaldo", "formato `3`", "no sobrescribas"):
            self.assertIn(phrase, content)
        self.assertIn("legacy-vault-migration.md", (ROOT / "README.md").read_text(encoding="utf-8"))
        self.assertIn("legacy-vault-migration.md", (ROOT / "references/instance-contract.md").read_text(encoding="utf-8"))

    def test_release_gate_tracks_main(self) -> None:
        for path in (ROOT / "scripts/release-check.sh", ROOT / "scripts/release-check.ps1"):
            content = path.read_text(encoding="utf-8")
            self.assertIn("origin/main", content, str(path))
            self.assertNotIn("origin/master", content, str(path))
        self.assertIn("main_sync", (ROOT / "scripts/release-check.sh").read_text(encoding="utf-8"))
        self.assertIn("main_sync", (ROOT / "scripts/release-check.ps1").read_text(encoding="utf-8"))
        readiness = (ROOT / "references/release-readiness.md").read_text(encoding="utf-8")
        self.assertIn("rama `main`", readiness)
        self.assertIn("origin/main", readiness)


if __name__ == "__main__":
    unittest.main()
