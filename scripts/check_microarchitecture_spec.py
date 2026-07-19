#!/usr/bin/env python3
"""Static consistency checks for Step 04 microarchitecture artifacts."""
from pathlib import Path
import csv
import sys

ROOT = Path(__file__).resolve().parents[1]
SPEC = ROOT / "docs/spec/microarchitecture_spec.md"
MODULES = ROOT / "config/module_hierarchy.csv"
PAYLOAD = ROOT / "config/pipeline_payload_matrix.csv"
DIAGRAM = ROOT / "docs/diagrams/rv32i_microarchitecture.mmd"

errors = []
for path in [SPEC, MODULES, PAYLOAD, DIAGRAM]:
    if not path.exists():
        errors.append(f"Missing required file: {path.relative_to(ROOT)}")

if errors:
    print("Microarchitecture specification check: FAIL")
    for e in errors: print(f"- {e}")
    sys.exit(1)

text = SPEC.read_text(encoding="utf-8")
required_terms = [
    "IF → ID → EX → MEM → WB/COMMIT",
    "fetch_epoch",
    "ghr_snapshot",
    "pht_index",
    "mem_issue_safe",
    "arch_next_pc",
    "RVFI order",
    "CSR serialization",
    "Synchronous exception/trap của instruction ở WB",
    "MEIP > MSIP > MTIP",
]
for term in required_terms:
    if term not in text:
        errors.append(f"Missing required contract term: {term}")

with MODULES.open(encoding="utf-8", newline="") as f:
    rows = list(csv.DictReader(f))
module_names = {r["module"] for r in rows}
required_modules = {
    "rv32i_core", "rv32i_fetch_unit", "rv32i_decoder", "rv32i_regfile",
    "rv32i_alu", "rv32i_lsu", "rv32i_hazard_unit", "rv32i_forward_unit",
    "rv32i_csr_file", "rv32i_commit_unit", "rv32i_rvfi_adapter",
}
missing = required_modules - module_names
if missing:
    errors.append("Missing modules: " + ", ".join(sorted(missing)))

with PAYLOAD.open(encoding="utf-8", newline="") as f:
    prows = list(csv.DictReader(f))
fields = {r["field"] for r in prows}
for field in ["pc", "insn", "exception", "pred_next_pc", "pht_index", "ghr_snapshot", "actual_next_pc"]:
    if field not in fields:
        errors.append(f"Missing pipeline payload field: {field}")

if len(rows) < 30:
    errors.append(f"Module inventory unexpectedly small: {len(rows)}")
if len(prows) < 20:
    errors.append(f"Pipeline payload matrix unexpectedly small: {len(prows)}")

if errors:
    print("Microarchitecture specification check: FAIL")
    for e in errors: print(f"- {e}")
    sys.exit(1)

print("Microarchitecture specification check: PASS")
print(f"Modules inventoried: {len(rows)}")
print(f"Pipeline payload fields: {len(prows)}")
print(f"Specification lines: {len(text.splitlines())}")
