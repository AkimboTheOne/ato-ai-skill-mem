from __future__ import annotations

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class IntegrationAlignmentTests(unittest.TestCase):
    def test_source_instructions_link_alignment_contract(self) -> None:
        alignment = ROOT / "references" / "integration-alignment.md"
        capability = ROOT / "references" / "capability-contract.md"
        change_control = ROOT / "references" / "change-control-contract.md"
        self.assertTrue(alignment.is_file())
        self.assertTrue(capability.is_file())
        self.assertTrue(change_control.is_file())
        for path in (ROOT / "AGENTS.md", ROOT / "SKILL.md"):
            content = path.read_text(encoding="utf-8")
            self.assertIn("references/integration-alignment.md", content)
            self.assertIn("references/capability-contract.md", content)
        self.assertIn("references/change-control-contract.md", (ROOT / "AGENTS.md").read_text(encoding="utf-8"))

    def test_consumer_guidance_preserves_subordination_and_provenance(self) -> None:
        content = (ROOT / "references" / "agents-integration.md").read_text(encoding="utf-8")
        self.assertIn("capability-contract.md", content)
        for field in ("source", "locator", "revision", "citation", "scope"):
            self.assertIn(f"`{field}`", content)
