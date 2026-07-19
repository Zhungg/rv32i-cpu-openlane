# Step 01 Exit Checklist

- [x] Unpack and inspect both repositories.
- [x] Identify all principal RTL modules.
- [x] Identify primary top-levels and hierarchy.
- [x] Select the five-stage pipeline repository as baseline.
- [x] Retain the single-cycle repository as a reference model.
- [x] Identify current 37-instruction decoder coverage.
- [x] Record missing FENCE, ECALL and EBREAK support.
- [x] Record BPU metadata/recovery defect.
- [x] Record verification false-PASS defects.
- [x] Record synthesis, LEC and OpenLane portability defects.
- [x] Define new `rv32i_core` and `rv32i_soc` boundaries.
- [x] Confirm final scope remains full RV32I plus Zicsr/Machine mode target.

## Gate result

**PASS — Step 01 is complete.**

The next step is **Step 02: freeze the architectural contract and instruction behavior** before modifying RTL.
