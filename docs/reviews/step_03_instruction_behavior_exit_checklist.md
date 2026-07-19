# Step 03 — Instruction Behavior Specification Exit Checklist

**Status:** `PASS`  
**Date:** `2026-07-19`

## Scope and completeness

- [x] 40 RV32I base instructions enumerated.
- [x] 6 Zicsr instructions enumerated.
- [x] FENCE.I, MRET and WFI enumerated.
- [x] 49 total supported instruction rows.
- [x] Zicntr behavior linked to CSR access rather than invented opcodes.

## Encoding

- [x] opcode/funct3/funct7 or exact encoding specified.
- [x] decoder mask/match values generated.
- [x] CSV decode matrix generated.
- [x] shift-immediate reserved encodings classified illegal.
- [x] FENCE/FENCE.I reserved fields handled per forward-compatibility rules.

## Architectural behavior

- [x] Immediate reconstruction defined.
- [x] Integer arithmetic, compare and shift corner cases defined.
- [x] Branch/JAL/JALR PC and misalignment behavior defined.
- [x] All load/store lane mappings defined.
- [x] Precise trap/no-side-effect rules defined.
- [x] CSR atomic and write-suppression semantics defined.
- [x] ECALL/EBREAK/MRET/WFI behavior defined.
- [x] HINT and pseudoinstruction policy defined.

## Verification readiness

- [x] Decoder output contract proposed.
- [x] Per-instruction test obligations listed.
- [x] Global assertions listed.
- [x] Automated consistency checker passes.

## Exit decision

`STEP 03 — PASS`

Next: `microarchitecture_spec.md`.
