# Step 04 — Microarchitecture Specification Exit Checklist

**Document:** `RV32I-STEP04-CHECKLIST`  
**Status:** `PASS`  
**Date:** `2026-07-19`

## A. Scope and hierarchy

- [x] 5-stage single-issue in-order architecture is fixed.
- [x] Core and SoC boundaries are separated.
- [x] Module hierarchy and state ownership are defined.
- [x] Machine-readable module inventory is generated.

## B. Pipeline contract

- [x] IF/ID/EX/MEM/WB responsibilities are defined.
- [x] Pipeline payload contents are defined.
- [x] Valid/ready/hold/bubble/kill semantics are defined.
- [x] Backpressure propagation is defined.
- [x] Redirect source priority and kill scope are defined.

## C. Hazards and forwarding

- [x] EX/MEM then MEM/WB forwarding priority is fixed.
- [x] Load-use behavior with variable memory latency is fixed.
- [x] Store-address and store-data forwarding are separated.
- [x] WB-to-ID bypass is required.
- [x] CSR/system serialization policy is fixed.

## D. Frontend and BPU

- [x] One outstanding instruction transaction is fixed.
- [x] Fetch epoch stale-response mechanism is fixed.
- [x] BTB/PHT/GHR/RAS baseline parameters are fixed.
- [x] Prediction metadata travels with the instruction.
- [x] Branch resolution is in EX.
- [x] Predictor training occurs only at commit.

## E. Memory and precise state

- [x] One outstanding data transaction is fixed.
- [x] Misalignment is detected before request.
- [x] All D-memory/MMIO requests require oldest-instruction authorization.
- [x] Loads to x0 still perform bus access and faults.
- [x] Store retirement waits for successful response.
- [x] FENCE/FENCE.I ordering model is defined.

## F. Trap, interrupt and commit

- [x] Exception metadata and detection stages are defined.
- [x] Trap is taken at WB for precise state.
- [x] Post-commit interrupt timing is defined.
- [x] MRET/CSR interaction with immediate interrupt is defined.
- [x] Architectural `arch_next_pc` is defined.
- [x] RVFI order and trapped-packet behavior are defined.

## G. ASIC implementation discipline

- [x] Reset strategy avoids unnecessary datapath/GPR reset.
- [x] Single clock domain and clock-enable strategy are fixed.
- [x] No internal IMEM/DMEM in core.
- [x] PD-aware RTL constraints are recorded.
- [x] Static consistency checker passes.

## Result

```text
STEP 04 — MICROARCHITECTURE SPECIFICATION: PASS
```

Next step: complete the detailed `pipeline_contract.md`, then `hazard_and_forwarding_spec.md` before writing integrated pipeline RTL.
