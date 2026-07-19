# Known Issues Register

| ID | Severity | Area | Finding | Required action |
|---|---|---|---|---|
| RTL-001 | Critical | BPU | Misprediction compares `pc_D` with actual next PC instead of branch prediction metadata | Pipeline predicted direction/target/index/history with each instruction |
| RTL-002 | Critical | BPU | PHT updates using current GHR rather than prediction-time GHR snapshot | Carry and use `ghr_snapshot`/update index |
| RTL-003 | Critical | ISA | FENCE, ECALL and EBREAK are absent from pipeline decoder | Add decode and architectural behavior |
| RTL-004 | High | ISA | Illegal `funct3`/`funct7` encodings can execute default operations | Add strict legality decoder and trap generation |
| RTL-005 | High | Pipeline | No explicit stage-valid/kill bits | Add valid bits to every pipeline stage |
| RTL-006 | High | Memory | Core assumes combinational zero-wait-state memories | Add request/response handshake and backpressure |
| RTL-007 | High | Memory | IMEM/DMEM embedded in CPU top infer large flip-flop arrays | Separate core from memory; later support SRAM macros |
| RTL-008 | High | Trap | No exception, trap, CSR or interrupt architecture | Add trap subsystem and Zicsr/Machine mode |
| RTL-009 | High | Verification | Unit tests print errors without nonzero exit | Use error counters and `$fatal` |
| RTL-010 | Critical | Verification | ALU TB drives 11-bit one-hot control into 4-bit ALU | Rewrite ALU testbench with shared encoded constants/package |
| RTL-011 | High | Verification | Main testbench finishes normally when errors exist | End with `$fatal` when `error_count != 0` |
| RTL-012 | Medium | Verification | Tests inspect internal arrays through hierarchical paths/debug ports | Add retirement/RVFI-style checking and memory signatures |
| RTL-013 | High | Formal | LEC uses `equiv_status` without `-assert` | Make unproven points fail the run |
| RTL-014 | High | Formal | Register file and memories are blackboxed in LEC | Verify the core boundary and separately verify memory wrappers |
| RTL-015 | High | PD | OpenLane input is a pre-generated netlist with synthesis skipped | Move to a reproducible RTL-driven OpenLane 2 flow |
| RTL-016 | High | PD | Physical script hardcodes another user's OpenLane path | Replace with project-relative Docker/OpenLane 2 command |
| RTL-017 | Medium | PD | Linter is disabled | Enable lint and treat key warnings as errors |
| RTL-018 | High | Reset | Large arrays/register file are asynchronously reset | Redesign reset strategy; reset architectural validity/control rather than all data bits where possible |
| RTL-019 | Medium | DFT | No scan/test-mode strategy | Keep RTL DFT-friendly and reserve test controls |
| RTL-020 | Medium | Commit | No explicit retirement/commit point | Add retirement unit and architectural trace |
