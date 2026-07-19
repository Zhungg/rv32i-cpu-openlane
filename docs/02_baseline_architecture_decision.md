# Baseline Architecture Decision

## Decision

Use the five-stage pipeline implementation from `RTL_Do_An_1-main` as the starting microarchitecture, but rebuild the integration boundaries and control discipline.

## Final target

```text
rv32i_soc
├── reset_controller
├── rv32i_core
│   ├── frontend
│   │   ├── program_counter
│   │   ├── fetch_controller
│   │   ├── fetch_buffer
│   │   ├── branch_predictor
│   │   ├── btb
│   │   ├── pht
│   │   └── ghr
│   ├── decode
│   │   ├── decoder
│   │   ├── immediate_generator
│   │   ├── register_file
│   │   └── illegal_instruction_detector
│   ├── execute
│   │   ├── alu
│   │   ├── branch_comparator
│   │   └── target_generator
│   ├── memory
│   │   ├── load_store_unit
│   │   ├── load_aligner
│   │   ├── store_aligner
│   │   └── memory_transaction_controller
│   ├── pipeline
│   │   ├── if_id
│   │   ├── id_ex
│   │   ├── ex_mem
│   │   ├── mem_wb
│   │   └── valid_stall_kill_controller
│   ├── commit
│   │   ├── writeback
│   │   ├── retirement_unit
│   │   └── rvfi_trace_adapter
│   └── trap
│       ├── exception_detector
│       ├── trap_arbiter
│       ├── csr_file
│       └── interrupt_controller
├── instruction_memory_wrapper
├── data_memory_wrapper
├── address_decoder
└── optional peripherals
```

## Configuration target

The completed core will be described as:

```text
Five-stage pipelined RV32I_Zicsr Machine-mode CPU core
```

Planned capabilities:

- all RV32I base instructions;
- dynamic branch prediction;
- forwarding and load-use stalls;
- ready/valid instruction and data interfaces;
- precise retirement;
- illegal instruction and alignment detection;
- machine-mode traps and interrupts;
- CSR support;
- RVFI-like trace output;
- synthesizable Sky130/OpenLane 2 implementation.

## Development rule

Features may be integrated incrementally for debug, but the final scope is not reduced. A temporary static-not-taken or zero-wait-state mode is a verification configuration, not the final product definition.
