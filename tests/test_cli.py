from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import textwrap
import unittest


ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"


def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(textwrap.dedent(content).lstrip(), encoding="utf-8")


def create_vault(root: Path) -> None:
    for directory in (
        "00_inbox/decisions-pending",
        "10_areas",
        "20_domains/example/records",
        "20_domains/example/resources",
        "30_resources",
        "40_archive",
        "50_daily",
        "60_exports",
        "_indexes",
        "_maps",
        "_templates",
    ):
        (root / directory).mkdir(parents=True, exist_ok=True)
    write(root / "AGENTS.md", "# Vault\n")
    write(root / "_indexes/INDEX.md", "# Índices\n")
    write(root / "_indexes/action-log.md", "# Acciones\n")
    write(root / "_maps/INDEX.md", "# Mapas\n")
    write(root / "20_domains/example/domain.yml", """
        format: 1
        id: example
        title: "Example"
        status: active
        scope: contextual
        areas: []
        routing:
          rules: []
    """)
    write(root / "20_domains/example/AGENTS.md", "# Example\n")
    write(root / "20_domains/example/INDEX.md", """
        # Índice

        ## Activos

        - [Activo](records/2026-01-01--active.md)

        ## Retirados

        - [Retirado](records/2026-01-02--retired.md)
    """)
    write(root / "20_domains/example/records/2026-01-01--active.md", """
        ---
        id: 2026-01-01--active
        type: decision
        status: active
        created: 2026-01-01
        updated: 2026-01-01
        scope: project
        author: human
        sources:
          - README.md
        related: []
        supersedes: null
        superseded_by: null
        ---

        # Activo

        Enlace [retirado](2026-01-02--retired.md).
        Enlace [externo](https://example.com).
    """)
    write(root / "20_domains/example/records/2026-01-02--retired.md", """
        ---
        id: 2026-01-02--retired
        type: decision
        status: retired
        created: 2026-01-02
        updated: 2026-01-02
        scope: project
        author: human
        sources: []
        related: []
        supersedes: null
        superseded_by: null
        ---

        # Retirado
    """)


class CliTests(unittest.TestCase):
    def run_cli(self, *args: str) -> subprocess.CompletedProcess[str]:
        environment = os.environ.copy()
        environment["PYTHONPATH"] = str(SRC)
        return subprocess.run(
            [sys.executable, "-m", "ato_ai_mem", *args],
            cwd=ROOT,
            env=environment,
            text=True,
            capture_output=True,
            check=False,
        )

    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.vault = Path(self.tempdir.name) / "vault"
        create_vault(self.vault)

    def tearDown(self) -> None:
        self.tempdir.cleanup()

    def test_check_validates_records_and_indexes(self) -> None:
        result = self.run_cli("check", "--vault", str(self.vault), "--format", "json")
        self.assertEqual(result.returncode, 0, result.stderr)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["status"], "ok")
        self.assertEqual(payload["summary"], {"findings": 0})

    def test_check_reports_invalid_front_matter(self) -> None:
        record = self.vault / "20_domains/example/records/2026-01-03--invalid.md"
        write(record, """
            ---
            id: 2026-01-03--invalid
            type: unknown
            status: active
            created: invalid
            updated: 2026-01-03
            scope: project
            author: human
            sources: []
            related: []
            supersedes: null
            superseded_by: null
            ---
        """)
        result = self.run_cli("check", "--vault", str(self.vault))
        self.assertEqual(result.returncode, 1)
        self.assertIn("invalid-type", result.stdout)
        self.assertIn("invalid-date", result.stdout)

    def test_find_is_regex_sorted_and_case_sensitive_by_default(self) -> None:
        result = self.run_cli("find", "--vault", str(self.vault), "--pattern", "Enlace")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.splitlines()[0].split(":", 1)[0], "20_domains/example/records/2026-01-01--active.md")
        no_match = self.run_cli("find", "--vault", str(self.vault), "--pattern", "enlace")
        self.assertEqual(no_match.returncode, 1)
        insensitive = self.run_cli("find", "--vault", str(self.vault), "--pattern", "enlace", "--ignore-case", "--format", "json")
        self.assertEqual(insensitive.returncode, 0)
        self.assertEqual(json.loads(insensitive.stdout)["summary"]["matches"], 2)

    def test_find_invalid_regex_is_an_error(self) -> None:
        result = self.run_cli("find", "--vault", str(self.vault), "--pattern", "[")
        self.assertEqual(result.returncode, 2)
        self.assertIn("regex inválida", result.stderr)
        json_result = self.run_cli("find", "--vault", str(self.vault), "--pattern", "[", "--format", "json")
        self.assertEqual(json_result.returncode, 2)
        self.assertEqual(json.loads(json_result.stdout)["status"], "error")

    def test_relate_reports_local_edges_and_unresolved_targets(self) -> None:
        record = self.vault / "20_domains/example/records/2026-01-01--active.md"
        write(record, """
            ---
            id: 2026-01-01--active
            type: decision
            status: active
            created: 2026-01-01
            updated: 2026-01-01
            scope: project
            author: human
            sources: []
            related:
              - "[missing](missing.md)"
            supersedes: null
            superseded_by: null
            ---

            Enlace [retirado](2026-01-02--retired.md).
            Enlace [externo](https://example.com).
        """)
        result = self.run_cli("relate", "--vault", str(self.vault), "--format", "json")
        self.assertEqual(result.returncode, 1)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["summary"]["unresolved"], 1)
        self.assertTrue(any(item["relation"] == "link" and item["resolved"] for item in payload["items"]))
        self.assertTrue(all("example.com" not in item["target"] for item in payload["items"]))

    def test_relate_validates_anchors_and_intermediate_symlinks(self) -> None:
        write(self.vault / "anchor-source.md", """
            # Source

            [válido](anchor-target.md#sección-uno)
            [anchor ausente](anchor-target.md#no-existe)
            [fuera](linked-dir/anchor-target.md)
        """)
        write(self.vault / "anchor-target.md", """
            # Sección Uno
        """)
        outside = Path(self.tempdir.name) / "outside"
        outside.mkdir()
        (outside / "anchor-target.md").write_text("# Fuera\n", encoding="utf-8")
        try:
            (self.vault / "linked-dir").symlink_to(outside, target_is_directory=True)
        except (OSError, NotImplementedError):
            self.skipTest("el sistema no admite enlaces simbólicos")
        result = self.run_cli("relate", "--vault", str(self.vault), "--format", "json")
        self.assertEqual(result.returncode, 1)
        relations = json.loads(result.stdout)["items"]
        by_target = {item["target"]: item for item in relations if item["source"] == "anchor-source.md"}
        self.assertTrue(by_target["anchor-target.md#sección-uno"]["resolved"])
        self.assertFalse(by_target["anchor-target.md#no-existe"]["resolved"])
        self.assertFalse(by_target["linked-dir/anchor-target.md"]["resolved"])

    def test_cli_does_not_follow_symlinked_markdown(self) -> None:
        link = self.vault / "linked.md"
        try:
            link.symlink_to(self.vault / "20_domains/example/records/2026-01-01--active.md")
        except (OSError, NotImplementedError):
            self.skipTest("el sistema no admite enlaces simbólicos")
        result = self.run_cli("find", "--vault", str(self.vault), "--pattern", "Act", "--format", "json")
        self.assertEqual(result.returncode, 0)
        paths = {item["path"] for item in json.loads(result.stdout)["items"]}
        self.assertNotIn("linked.md", paths)

    def test_cli_commands_do_not_create_or_modify_runtime_state(self) -> None:
        before = {
            path.relative_to(self.vault).as_posix(): path.read_bytes()
            for path in self.vault.rglob("*")
            if path.is_file() and not path.is_symlink()
        }
        commands = (
            ("check", "--format", "json"),
            ("find", "--pattern", "Activo", "--format", "json"),
            ("relate", "--format", "json"),
            ("build", "--format", "json"),
            ("retrieve", "--query", "Activo", "--format", "json"),
        )
        for command in commands:
            result = self.run_cli(command[0], "--vault", str(self.vault), *command[1:])
            self.assertIn(result.returncode, (0, 1), result.stderr)
        after = {
            path.relative_to(self.vault).as_posix(): path.read_bytes()
            for path in self.vault.rglob("*")
            if path.is_file() and not path.is_symlink()
        }
        self.assertEqual(before, after)
        self.assertFalse((self.vault / "99_runtime").exists())


if __name__ == "__main__":
    unittest.main()
