# STEP 08D — OpenLane Lint Waiver Note

## Context

OpenLane Verilator lint reports one BLKLOOPINIT error in the sv2v-generated Verilog:

- openlane/rv32i_core/src/rv32i_core.v
- Error: delayed/nonblocking assignment to array inside a for loop

## Root Cause

The original SystemVerilog RTL is converted through sv2v before OpenLane.

The generated Verilog contains array initialization/reset loops that Verilator lint does not support in this form.

This is a Verilator lint/frontend limitation on the generated RTL, not a functional RTL failure.

## Prior Checks

Before OpenLane smoke run:

- Step 7 functional/frontend/BPU regression: PASS
- Step 8B sv2v + Yosys synthesis-readiness: PASS
- Flattened generic Yosys check: PASS
- Memory-mapped generic Yosys check: PASS

## Temporary Handling

For the first OpenLane smoke run, ERROR_ON_LINTER_ERRORS is set to false.

The linter still runs and reports the issue, but the flow is allowed to continue to synthesis/place/route exploration.

## Long-term Cleanup

A later RTL cleanup can remove this waiver by rewriting predictor/register-array reset logic into a Verilator-friendly style, for example by flattening arrays into packed vectors or avoiding nonblocking array initialization loops.
