"""Evalúa el benchmark humano de retrieval léxico."""

from __future__ import annotations

import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "src"
sys.path.insert(0, str(SRC))

from ato_ai_mem.retrieval import retrieve


THRESHOLD = 0.80


def main() -> int:
    dataset = json.loads((ROOT / "tests/retrieval/eval_cases.json").read_text(encoding="utf-8"))
    cases = dataset["cases"]
    hits = 0
    for case in cases:
        _, results = retrieve(ROOT / "vault", case["query"], limit=5)
        result_paths = {result.path for result in results}
        if result_paths.intersection(case["expected_paths"]):
            hits += 1
    recall = hits / len(cases) if cases else 0.0
    report = {
        "cases": len(cases),
        "hits": hits,
        "recall_at_5": round(recall, 4),
        "threshold": THRESHOLD,
    }
    print(json.dumps(report, ensure_ascii=False, sort_keys=True))
    return 0 if recall >= THRESHOLD else 1


if __name__ == "__main__":
    raise SystemExit(main())
