# Step 01 — Repository Audit

## 1. Objective

Audit the two supplied repositories before modifying RTL. The audit identifies reusable modules, architectural gaps, verification weaknesses, synthesis/physical-design risks, and the baseline source for the new CPU project.

## 2. Supplied repositories

### Repository A — `rv32i-rtl2gds-main`

Primary characteristics:

- Contains a small modular single-cycle datapath under `rtl/datpath.v`.
- Contains a second, unrelated monolithic implementation under `rtl/soc.v`.
- Includes commercial Synopsys Design Compiler/ICC2/PrimeTime-oriented scripts.
- Physical scripts target an SAED14nm-style environment, not Sky130/OpenLane 2.
- Documentation is largely a project outline rather than an implementation specification.

Useful content:

- Single-cycle architectural reference.
- Basic immediate generation, ALU, register-file, load/store behavior.
- Reference for expected instruction semantics.

Do not use directly as the new project baseline because:

- It has two conflicting RTL organizations and duplicate module names.
- `rtl/soc.v` mixes CPU, memory, address decoding, I2C and top-level integration.
- The commercial physical scripts are technology-specific and not portable to Sky130/OpenLane 2.
- ECALL/EBREAK are treated as NOP rather than architecturally visible traps.

### Repository B — `RTL_Do_An_1-main`

Primary characteristics:

- Five-stage pipeline: IF, ID, EX, MEM, WB.
- Contains forwarding, load-use hazard detection and pipeline registers.
- Contains a Gshare-like BPU composed of PHT, GHR and BTB.
- Includes Icarus testbenches, Yosys synthesis, OpenSTA and an OpenLane configuration.

Useful content:

- Main pipeline datapath baseline.
- ALU, decoder, immediate generator and register file.
- IF/ID, ID/EX, EX/MEM and MEM/WB pipeline registers.
- Forwarding and load-use hazard logic.
- Initial BPU/BTB/PHT implementation.
- Directed integration testbench.

This repository is selected as the **primary RTL baseline**, but it must be refactored before being accepted as the final CPU.

## 3. Baseline decision

The new project will use:

- Repository B as the primary microarchitecture baseline.
- Repository A's modular single-cycle datapath as a simple architectural reference.
- Neither repository's current top-level as the final production top-level.
- A new top-level named `rv32i_core` and a separate integration top-level named `rv32i_soc`.

## 4. Current hierarchy of Repository B

```text
Top_module_pipeline_RISC_V_32I
├── Program_Counter
├── instruction_memory
├── IF_ID
├── control_unit
├── imm_extend
├── Register_File
├── ID_EX
├── Forwarding_Unit
├── Branch_Prediction_Unit
│   ├── PHT
│   └── BTB
├── ALU
├── EX_MEM
├── data_memory
├── MEM_WB
└── Hazard_Unit
```

## 5. ISA coverage found in Repository B

The control unit decodes the following 37 RV32I computational and memory instructions:

- U-type: LUI, AUIPC
- Jump: JAL, JALR
- Branch: BEQ, BNE, BLT, BGE, BLTU, BGEU
- Load: LB, LH, LW, LBU, LHU
- Store: SB, SH, SW
- Immediate ALU: ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI
- Register ALU: ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND

Missing from the current decoder:

- FENCE
- ECALL
- EBREAK

Encoding legality is also incomplete. For example, unsupported `funct3`/`funct7` combinations can fall through to a default ALU operation instead of raising an illegal-instruction event.

## 6. Major blocking findings

### 6.1 Testbenches can report false PASS

Most unit testbenches print `ERROR` or `FAIL` but do not call `$fatal`, and the integration testbench finishes normally even when `error_count` is nonzero. The shell script marks a test PASS whenever `vvp` returns exit code zero.

Required correction:

```systemverilog
if (error_count != 0)
    $fatal(1, "TEST FAILED: %0d errors", error_count);
```

### 6.2 ALU testbench and RTL use incompatible control encodings

`src/ALU.v` uses a 4-bit encoded `alu_ctrl`, while `testbench/ALU_tb.v` drives an 11-bit one-hot value. Port truncation means the testbench is not testing the intended operations reliably.

### 6.3 Branch-prediction recovery is architecturally incorrect

The current BPU decides misprediction using:

```text
pc_D != actual_next_pc
```

`pc_D` is the PC of a younger instruction in Decode, not the prediction metadata belonging to the branch in Execute. The design does not pipeline:

- predicted direction
- predicted target
- BTB hit
- PHT index
- GHR snapshot

The PHT update index also uses the current GHR, not the history snapshot used when the branch was predicted.

### 6.4 No stage-valid/kill tracking

Pipeline registers clear selected control fields to form a bubble, but there is no explicit `valid` bit. This makes precise retirement, exception handling, wrong-path suppression and formal verification unnecessarily fragile.

### 6.5 Memory is embedded in the CPU top-level

Instruction memory, data memory and the register file are inferred as arrays with asynchronous reads. In the supplied synthesized netlist this creates a very large standard-cell design instead of SRAM macros.

Required architecture:

```text
rv32i_core
├── instruction request/response interface
└── data request/response interface

rv32i_soc
├── rv32i_core
├── instruction memory model or SRAM wrapper
├── data memory model or SRAM wrapper
└── address decoder/peripherals
```

### 6.6 No wait-state or backpressure support

The current core assumes instruction and load data are available combinationally. It cannot correctly interact with a synchronous SRAM, bus fabric or variable-latency memory.

### 6.7 No trap, exception or illegal-instruction path

The current pipeline has no architectural handling for:

- illegal instruction
- ECALL
- EBREAK
- instruction-address misalignment
- load/store misalignment
- instruction/data access errors

### 6.8 Incomplete retirement model

There is no commit/retirement interface. Verification relies on debug reads of internal register and memory arrays instead of comparing architectural state instruction by instruction.

### 6.9 Equivalence checking is not sign-off quality

The current LEC script:

- blackboxes instruction memory, data memory and register file;
- ends with `equiv_status` instead of `equiv_status -assert`;
- can therefore complete without forcing all equivalence points to be proven.

### 6.10 OpenLane flow is not reproducible

The current physical flow:

- feeds a pre-generated gate netlist to OpenLane;
- sets `SKIP_SYNTHESIS`;
- uses OpenLane 1-style `flow.tcl` invocation;
- hardcodes `/home/thinkbook/OpenLane`;
- uses configuration names that need migration to the installed OpenLane 2 version;
- disables the linter;
- does not represent a clean RTL-to-GDSII run from a single configuration.

## 7. What will be reused

### Reuse after correction

- 32-bit ALU operations.
- Immediate-format extraction.
- Core opcode grouping.
- Register-file read/write behavior.
- Pipeline-stage partitioning.
- Forwarding priority concept.
- Load-use hazard concept.
- Load/store byte and halfword alignment logic.
- BTB/PHT concepts, but not the current recovery implementation.
- Directed instruction encoder functions from the integration testbench.

### Reference only

- Repository A single-cycle datapath.
- Repository A load/store semantics.
- Existing Synopsys scripts.
- Existing generated gate netlist and STA reports.

### Replace

- Existing top-level ports.
- Embedded instruction/data memories inside the CPU core.
- Current BPU metadata and misprediction logic.
- Current regression pass/fail mechanism.
- Existing LEC script.
- Existing OpenLane wrapper scripts/configuration.
- Debug-only architectural checking as the main verification strategy.

## 8. Step 01 exit criteria

Step 01 is complete when:

- both repositories have been inventoried;
- a primary baseline has been selected;
- supported and missing instructions are identified;
- all known blockers are recorded;
- the intended new top-level boundaries are defined;
- no RTL has yet been modified without a written reason.

**Status: COMPLETE**
