from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import unittest

from test_cli import create_vault, write

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"
if str(SRC) not in sys.path:
    sys.path.insert(0, str(SRC))

from ato_ai_mem.retrieval import retrieve


class RetrievalTests(unittest.TestCase):
    def setUp(self) -> None:
        import os
        import tempfile

        self.tempdir = tempfile.TemporaryDirectory()
        self.vault = Path(self.tempdir.name) / "vault"
        create_vault(self.vault)
        self.environment = os.environ.copy()
        self.environment["PYTHONPATH"] = str(SRC)

    def tearDown(self) -> None:
        self.tempdir.cleanup()

    def run_cli(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, "-m", "ato_ai_mem", *args],
            cwd=ROOT,
            env=self.environment,
            text=True,
            capture_output=True,
            check=False,
        )

    def test_build_uses_structural_chunks_and_explicit_filters(self) -> None:
        result = self.run_cli(
            "build",
            "--vault",
            str(self.vault),
            "--include",
            "20_domains/example/records/*.md",
            "--exclude",
            "*retired.md",
            "--format",
            "json",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["summary"]["documents"], 1)
        self.assertTrue(payload["items"])
        chunk = payload["items"][0]
        self.assertEqual(chunk["path"], "20_domains/example/records/2026-01-01--active.md")
        self.assertEqual(chunk["heading_path"], ["Activo"])
        self.assertRegex(chunk["id"], r"#L\d+-L\d+$")

    def test_build_and_retrieve_default_to_text(self) -> None:
        build = self.run_cli("build", "--vault", str(self.vault))
        retrieve = self.run_cli("retrieve", "--vault", str(self.vault), "--query", "Activo")
        self.assertEqual(build.returncode, 0)
        self.assertEqual(retrieve.returncode, 0)
        self.assertFalse(build.stdout.lstrip().startswith("{"))
        self.assertFalse(retrieve.stdout.lstrip().startswith("{"))

    def test_retrieve_uses_or_ranking_limit_and_relations(self) -> None:
        result = self.run_cli(
            "retrieve",
            "--vault",
            str(self.vault),
            "--query",
            "retirado decision enlace",
            "--limit",
            "1",
            "--format",
            "json",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["summary"]["results"], 1)
        item = payload["items"][0]
        self.assertEqual(item["path"], "20_domains/example/records/2026-01-01--active.md")
        self.assertEqual(item["matched_terms"], ["decision", "enlace", "retirado"])
        self.assertTrue(any(relation["relation"] == "link" for relation in item["relations"]))

    def test_retrieve_is_deterministic_and_reports_bounds(self) -> None:
        args = ("retrieve", "--vault", str(self.vault), "--query", "retirado decision", "--format", "json")
        first = self.run_cli(*args)
        second = self.run_cli(*args)
        self.assertEqual(first.returncode, 0)
        self.assertEqual(first.stdout, second.stdout)
        invalid = self.run_cli(*args, "--limit", "51")
        self.assertEqual(invalid.returncode, 2)
        self.assertEqual(json.loads(invalid.stdout)["status"], "error")

    def test_build_reports_front_matter_diagnostics_without_dropping_text(self) -> None:
        record = self.vault / "20_domains/example/records/2026-01-03--invalid.md"
        write(record, """
            ---
            id: 2026-01-03--invalid
            type: unknown
            invalid front matter
            # Contenido recuperable
        """)
        result = self.run_cli("build", "--vault", str(self.vault), "--format", "json")
        self.assertEqual(result.returncode, 1)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["summary"]["diagnostics"], 1)
        self.assertTrue(any("invalid-frontmatter" == item["code"] for item in payload["diagnostics"]))
        self.assertTrue(any("Contenido recuperable" in item["text"] for item in payload["items"]))

    def test_retrieve_no_match_returns_one_and_does_not_write(self) -> None:
        before = {
            path.relative_to(self.vault).as_posix(): path.read_bytes()
            for path in self.vault.rglob("*")
            if path.is_file() and not path.is_symlink()
        }
        result = self.run_cli(
            "retrieve",
            "--vault",
            str(self.vault),
            "--query",
            "term-that-does-not-exist",
            "--format",
            "json",
        )
        self.assertEqual(result.returncode, 1)
        self.assertEqual(json.loads(result.stdout)["items"], [])
        after = {
            path.relative_to(self.vault).as_posix(): path.read_bytes()
            for path in self.vault.rglob("*")
            if path.is_file() and not path.is_symlink()
        }
        self.assertEqual(before, after)

    def test_retrieve_filters_relation_sources_with_the_corpus(self) -> None:
        result = self.run_cli(
            "retrieve",
            "--vault",
            str(self.vault),
            "--query",
            "retirado",
            "--include",
            "20_domains/example/records/2026-01-01--active.md",
            "--format",
            "json",
        )
        self.assertEqual(result.returncode, 0)
        payload = json.loads(result.stdout)
        self.assertEqual({item["path"] for item in payload["items"]}, {"20_domains/example/records/2026-01-01--active.md"})


class RetrievalEvaluationTests(unittest.TestCase):
    def test_human_dataset_recall_at_five(self) -> None:
        dataset = json.loads((ROOT / "tests/retrieval/eval_cases.json").read_text(encoding="utf-8"))
        cases = dataset["cases"]
        self.assertGreaterEqual(len(cases), 12)
        case_ids = [case["id"] for case in cases]
        self.assertEqual(len(case_ids), len(set(case_ids)))
        root = ROOT / "vault"
        hits = 0
        for case in cases:
            self.assertTrue(case["query"].strip())
            for expected_path in case["expected_paths"]:
                self.assertTrue((root / expected_path).exists(), expected_path)
            _, results = retrieve(root, case["query"], limit=5)
            result_paths = {result.path for result in results}
            if result_paths.intersection(case["expected_paths"]):
                hits += 1
        recall = hits / len(dataset["cases"])
        self.assertGreaterEqual(recall, 0.80)


if __name__ == "__main__":
    unittest.main()
