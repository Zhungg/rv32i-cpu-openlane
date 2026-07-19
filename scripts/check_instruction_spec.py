#!/usr/bin/env python3
from pathlib import Path
import csv, sys

root = Path(__file__).resolve().parents[1]
csv_path = root / "config/instruction_decode_matrix.csv"
md_path = root / "docs/spec/instruction_behavior.md"
rows = list(csv.DictReader(csv_path.open(encoding="utf-8")))
errors=[]
if len(rows) != 49:
    errors.append(f"expected 49 instruction rows, found {len(rows)}")
rv32i=[r for r in rows if r["extension"]=="RV32I"]
if len(rv32i) != 40:
    errors.append(f"expected 40 RV32I rows, found {len(rv32i)}")
expected={"LUI","AUIPC","JAL","JALR","BEQ","BNE","BLT","BGE","BLTU","BGEU",
"LB","LH","LW","LBU","LHU","SB","SH","SW","ADDI","SLTI","SLTIU","XORI","ORI","ANDI",
"SLLI","SRLI","SRAI","ADD","SUB","SLL","SLT","SLTU","XOR","SRL","SRA","OR","AND",
"FENCE","ECALL","EBREAK","CSRRW","CSRRS","CSRRC","CSRRWI","CSRRSI","CSRRCI","FENCE.I","MRET","WFI"}
actual={r["mnemonic"] for r in rows}
if actual != expected:
    errors.append(f"mnemonic mismatch missing={sorted(expected-actual)} extra={sorted(actual-expected)}")
for r in rows:
    for k in ("mask","match"):
        try: int(r[k],16)
        except Exception: errors.append(f"{r['mnemonic']}: invalid {k}={r[k]}")

# Two decoder patterns overlap if their constrained common bits do not disagree.
for i, a in enumerate(rows):
    ma, va = int(a["mask"], 16), int(a["match"], 16)
    for b in rows[i+1:]:
        mb, vb = int(b["mask"], 16), int(b["match"], 16)
        if ((va ^ vb) & (ma & mb)) == 0:
            errors.append(f"overlapping decoder patterns: {a['mnemonic']} and {b['mnemonic']}")
text=md_path.read_text(encoding="utf-8")
for token in ("Complete decode matrix","Store behavior and byte lanes","CSR instruction behavior","Status:** `PASS"):
    if token not in text: errors.append(f"missing document token: {token}")
if errors:
    print("Instruction specification check: FAIL")
    for e in errors: print(" -",e)
    sys.exit(1)
print("Instruction specification check: PASS")
print(f"Total supported instructions: {len(rows)}")
print(f"RV32I base instructions: {len(rv32i)}")
