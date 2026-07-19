# STEP 08B — Synthesis Readiness Summary

## Status

PASS.

## Flow

The RV32I SystemVerilog RTL was converted and checked through:

SystemVerilog RTL
→ sv2v conversion
→ Yosys read_verilog
→ hierarchy -check
→ proc
→ opt
→ check
→ stat
→ generic Verilog netlist generation

## Generated Outputs

- build/sv2v/rv32i_core.sv2v.v
- build/yosys/rv32i_core.generic.v
- build/yosys/rv32i_core.flattened.generic.v
- build/yosys/rv32i_core.memory_mapped.generic.v
- reports/yosys/check_synthesis_readiness_sv2v.log
- reports/yosys/report_flattened_generic_stat.log
- reports/yosys/report_memory_mapped_generic_stat.log

## Key Result

The design is synthesis-elaboratable through the sv2v + Yosys flow.

The native Yosys read_verilog -sv frontend was not sufficient for the original SystemVerilog package/struct/import style, so sv2v is used as a SystemVerilog-to-Verilog conversion stage.

## Warning Assessment

Yosys reported memory replacement warnings for BPU arrays:

- PHT table_q
- BTB target_q
- BTB tag_q
- BTB valid_q

These are expected for a standard-cell-only baseline flow and are classified as QoR notes, not functional or synthesis-blocking errors.

## Memory Mapping

The remaining register-file memory was checked through memory_map to ensure it can be implemented as standard-cell logic.

## Conclusion

STEP 08B is complete.

The design is ready for the next phase:

STEP 08C — Prepare OpenLane-ready source input using sv2v-generated Verilog.
