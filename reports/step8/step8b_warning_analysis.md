# STEP 08B Warning Analysis — sv2v + Yosys Synthesis Readiness

## Status

STEP 08B PASS.

Flow completed:

SystemVerilog RTL
→ sv2v conversion
→ Yosys read_verilog
→ hierarchy -check
→ proc
→ opt
→ check
→ stat
→ generic Verilog netlist generation

Generated files:

- build/sv2v/rv32i_core.sv2v.v
- build/yosys/rv32i_core.generic.v
- logs/yosys/check_synthesis_readiness_sv2v.log
- reports/yosys/check_synthesis_readiness_sv2v.log

## Warnings

Yosys reported memory replacement warnings:

- table_q replaced with registers
- target_q replaced with registers
- tag_q replaced with registers
- valid_q replaced with registers

These arrays belong to the branch prediction unit:

- table_q: PHT / Pattern History Table
- target_q: BTB target array
- tag_q: BTB tag array
- valid_q: BTB valid array

## Assessment

These warnings are acceptable for the current baseline.

They indicate that small memory arrays are being implemented as flip-flop/register banks rather than SRAM macros.

This is not a functional correctness issue and does not block synthesis-readiness.

## QoR Implication

Potential impact:

- Higher area due to flip-flop implementation
- Higher clock power due to additional sequential elements
- Potential timing impact from read muxes and predictor logic

This should be revisited during QoR optimization after the first OpenLane run.

## Conclusion

No RTL fix is required at this stage.

The warning is classified as:

QoR note / expected standard-cell implementation behavior.
