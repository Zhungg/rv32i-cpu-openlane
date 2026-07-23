# RV32I Core Signoff Evidence

This directory contains curated evidence from the final OpenLane physical-design
run. Complete OpenLane intermediate run directories are intentionally excluded
from version control.

## Final implementation

| Item | Result |
|---|---|
| Design | `rv32i_core` |
| Architecture | Five-stage pipelined RV32I CPU |
| PDK | SKY130A |
| Target clock period | 20.000 ns |
| Final run | `RUN_2026-07-23_18-56-04` |
| Worst setup WNS | +0.252381 ns |
| Worst setup view | `max_ss_100C_1v60` |
| Worst hold WNS | +0.254094 ns |
| Worst hold view | `min_ff_n40C_1v95` |
| Setup timing | MET |
| Hold timing | MET |
| DRC | PASS |
| LVS | PASS |
| Antenna | PASS |

## Files

- `final_signoff_summary.txt`: final project-level signoff summary.
- `mcmm_timing_summary.txt`: setup and hold results for all analysis views.
- `worst_setup_path_summary.txt`: final worst setup path key points.
- `worst_setup_endpoint_mapping.txt`: gate-level endpoint mapping.
- `manufacturability.rpt`: DRC, LVS and antenna status.
- `openlane_config.json`: configuration used for the final implementation.
- `SIGNOFF_RUN_ID.txt`: original local OpenLane run identifier.

The complete local OpenLane run is not distributed because it contains large
intermediate databases and temporary tool artifacts.
