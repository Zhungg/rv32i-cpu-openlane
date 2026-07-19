# Step 02 — Architectural Specification Exit Checklist

**Status:** `PASS`  
**Date:** `2026-07-19`  
**Primary document:** `docs/spec/rv32i_architecture_spec.md`

## A. ISA identity

- [x] Base ISA là RV32I, XLEN=32.
- [x] 32 GPR, `x0` hardwired zero.
- [x] IALIGN=32, không có C extension.
- [x] Little-endian, address width 32 bit.
- [x] Hỗ trợ đủ 40 RV32I instructions.
- [x] Thêm Zicsr, Zifencei và Zicntr.
- [x] Toolchain target được chốt.

## B. Execution environment

- [x] Single hart.
- [x] Machine mode only.
- [x] Unified architectural address space, split instruction/data ports.
- [x] Misaligned load/store tạo contained trap.
- [x] Ready/valid memory interface là contract bắt buộc.
- [x] FENCE và FENCE.I behavior được chốt.

## C. Trap/interrupt/CSR

- [x] Precise trap model.
- [x] Synchronous exception causes được chốt.
- [x] MSIP/MTIP/MEIP inputs và priority được chốt.
- [x] MRET và mtvec Direct/Vectored được chốt.
- [x] CSR tối thiểu và counter aliases được chốt.
- [x] `time_i[63:0]` được yêu cầu cho Zicntr.

## D. Reset và implementation constraints

- [x] Reset vector và mtvec reset parameterized.
- [x] Không reset x1–x31.
- [x] Reset control/valid/side-effect state.
- [x] Asynchronous assertion, synchronous deassertion.
- [x] Wrong-path instruction không tạo side effect.

## E. Verification contract

- [x] In-order precise retirement.
- [x] RVFI-style trace bắt buộc.
- [x] Architectural invariants được liệt kê.
- [x] Unsupported extensions được ghi rõ.

## F. Open items chuyển sang Step 03

Các mục sau không block Step 02:

- [ ] Viết bảng encoding/semantics cho từng instruction.
- [ ] Khóa CSR writable masks chi tiết.
- [ ] Khóa pipeline stage allocation.
- [ ] Khóa memory ready/valid cycle-level behavior.
- [ ] Khóa hazard/forwarding matrix.
- [ ] Khóa BPU indexing/update/recovery.
- [ ] Viết verification coverage matrix.

## Exit decision

```text
STEP 02 — ARCHITECTURAL SPECIFICATION: PASS
NEXT    — STEP 03: INSTRUCTION BEHAVIOR SPECIFICATION
```
