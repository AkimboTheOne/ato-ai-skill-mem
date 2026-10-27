from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from zipfile import ZipFile


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "package-microsoft-copilot.py"


class MicrosoftCopilotPackageTests(unittest.TestCase):
    def test_package_contains_only_the_mvp_contract_and_traceability(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "copilot.zip"
            result = subprocess.run(
                [sys.executable, str(SCRIPT), "--output", str(output)],
                cwd=ROOT,
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue(output.is_file())
            with ZipFile(output) as archive:
                self.assertEqual(
                    archive.namelist(),
                    ["SKILL.md", "connection-contract.md", "package-metadata.json"],
                )
                skill = archive.read("SKILL.md").decode("utf-8")
                self.assertIn("name: ato-ai-skill-mem-microsoft-365-copilot", skill)
                self.assertNotIn("AGENTS.md", skill)
                contract = archive.read("connection-contract.md").decode("utf-8")
                self.assertIn("memory_check", contract)
                self.assertIn("memory_retrieve", contract)
                package_metadata = json.loads(archive.read("package-metadata.json"))
                self.assertEqual(package_metadata["skill_version"], (ROOT / "VERSION").read_text().strip())
                self.assertEqual(package_metadata["vault_format"], 3)
                self.assertEqual(package_metadata["adapter_target"], "microsoft-365-copilot-agent-builder")
                self.assertIn(package_metadata["source_worktree"], {"clean", "dirty", "unknown"})

    def test_package_refuses_to_overwrite_existing_output(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "copilot.zip"
            output.write_bytes(b"existing")
            result = subprocess.run(
                [sys.executable, str(SCRIPT), "--output", str(output)],
                cwd=ROOT,
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(result.returncode, 1)
            self.assertIn("ya existe", result.stderr)
