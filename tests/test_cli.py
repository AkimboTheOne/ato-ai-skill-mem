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


def create_vault(root: Path, kind: str = "consumer") -> None:
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
    write(root / ".ato-ai-skill-mem-version.yml", f"vault_kind: {kind}\nvault_format: 3\n")
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
        self.project = Path(self.tempdir.name) / "project"
        (self.project / "mem").mkdir(parents=True)
        self.vault = self.project / "mem" / "vault"
        create_vault(self.vault)

    def tearDown(self) -> None:
        self.tempdir.cleanup()

    def test_cli_exposes_only_the_five_low_level_primitives(self) -> None:
        result = self.run_cli("--help")
        self.assertEqual(result.returncode, 0, result.stderr)
        for command in ("check", "find", "relate", "build", "retrieve"):
            self.assertIn(command, result.stdout)
        self.assertNotIn(" ask ", result.stdout)

    def test_check_validates_records_and_indexes(self) -> None:
        result = self.run_cli("check", "--target", str(self.project), "--format", "json")
        self.assertEqual(result.returncode, 0, result.stderr)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["status"], "ok")
        self.assertEqual(payload["summary"], {"findings": 0})
        self.assertEqual(
            payload["scope"],
            {"role": "consumer", "vault": self.vault.resolve().as_posix()},
        )

    def test_cli_rejects_arbitrary_vault_option(self) -> None:
        result = self.run_cli("check", "--vault", str(self.vault))
        self.assertEqual(result.returncode, 2)

    def test_source_scope_resolves_only_the_source_vault(self) -> None:
        source = Path(self.tempdir.name) / "source"
        (source / "scripts").mkdir(parents=True)
        (source / "VERSION").write_text("0.6.0\n", encoding="utf-8")
        (source / "VAULT_FORMAT").write_text("3\n", encoding="utf-8")
        source_vault = source / "vault"
        create_vault(source_vault, kind="source")
        result = self.run_cli("check", "--source", str(source), "--format", "json")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["scope"]["role"], "source")
        self.assertEqual(
            json.loads(result.stdout)["scope"]["vault"],
            source_vault.resolve().as_posix(),
        )

    def test_consumer_scope_rejects_source_marker_and_symlink_project(self) -> None:
        (self.vault / ".ato-ai-skill-mem-version.yml").write_text(
            "vault_kind: source\nvault_format: 3\n", encoding="utf-8"
        )
        rejected = self.run_cli("check", "--target", str(self.project))
        self.assertEqual(rejected.returncode, 2)
        link_project = Path(self.tempdir.name) / "project-link"
        try:
            link_project.symlink_to(self.project, target_is_directory=True)
        except (OSError, NotImplementedError):
            self.skipTest("el sistema no admite enlaces simbólicos")
        linked = self.run_cli("check", "--target", str(link_project))
        self.assertEqual(linked.returncode, 2)

    def test_all_cli_commands_leave_runtime_and_vault_unchanged(self) -> None:
        before = sorted(
            path.relative_to(self.vault).as_posix()
            for path in self.vault.rglob("*")
            if not path.is_symlink()
        )
        commands = (
            ("check",),
            ("find", "--pattern", "Activo"),
            ("relate",),
            ("build", "--format", "json"),
            ("retrieve", "--query", "activo"),
        )
        for command in commands:
            result = self.run_cli(*command, "--target", str(self.project))
            self.assertIn(result.returncode, (0, 1), result.stderr)
        after = sorted(
            path.relative_to(self.vault).as_posix()
            for path in self.vault.rglob("*")
            if not path.is_symlink()
        )
        self.assertEqual(before, after)
        self.assertFalse((self.vault / "99_runtime").exists())

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
        result = self.run_cli("check", "--target", str(self.project))
        self.assertEqual(result.returncode, 1)
        self.assertIn("invalid-type", result.stdout)
        self.assertIn("invalid-date", result.stdout)

    def test_find_is_regex_sorted_and_case_sensitive_by_default(self) -> None:
        result = self.run_cli("find", "--target", str(self.project), "--pattern", "Enlace")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.splitlines()[0].split(":", 1)[0], "20_domains/example/records/2026-01-01--active.md")
        no_match = self.run_cli("find", "--target", str(self.project), "--pattern", "enlace")
        self.assertEqual(no_match.returncode, 1)
        insensitive = self.run_cli("find", "--target", str(self.project), "--pattern", "enlace", "--ignore-case", "--format", "json")
        self.assertEqual(insensitive.returncode, 0)
        self.assertEqual(json.loads(insensitive.stdout)["summary"]["matches"], 2)

    def test_find_invalid_regex_is_an_error(self) -> None:
        result = self.run_cli("find", "--target", str(self.project), "--pattern", "[")
        self.assertEqual(result.returncode, 2)
        self.assertIn("regex inválida", result.stderr)
        json_result = self.run_cli("find", "--target", str(self.project), "--pattern", "[", "--format", "json")
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
        result = self.run_cli("relate", "--target", str(self.project), "--format", "json")
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
        result = self.run_cli("relate", "--target", str(self.project), "--format", "json")
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
        result = self.run_cli("find", "--target", str(self.project), "--pattern", "Act", "--format", "json")
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
            result = self.run_cli(command[0], "--target", str(self.project), *command[1:])
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
