# QoR Baseline — baseline_v1.0.0

- Design: `rv32i_core`
- Run: `RUN_2026-07-23_18-56-04`
- Metrics source: `/home/zhung/projects/rv32i_cpu_project/openlane/rv32i_core/runs/RUN_2026-07-23_18-56-04/final/metrics.json`
- Metrics SHA-256: `0a9b186a2bc8402b37662b1af3eb18c043908c02fbe144c4867985341ac9756a`

## Clock and Physical QoR

| Metric | Value |
|---|---:|
| Clock period | 20.000 ns |
| Target frequency | 50.000 MHz |
| Standard-cell instances | 39789 |
| Total cell area | 363761.000 µm² |
| Core area | 0.924423 mm² |
| Utilization | 39.3501% |

## MCMM Timing

| Corner | Setup WNS (ns) | Hold WNS (ns) |
|---|---:|---:|
| `max_ff_n40C_1v95` | 0.000000 | 0.000000 |
| `max_ss_100C_1v60` | 0.000000 | 0.000000 |
| `max_tt_025C_1v80` | 0.000000 | 0.000000 |
| `min_ff_n40C_1v95` | 0.000000 | 0.000000 |
| `min_ss_100C_1v60` | 0.000000 | 0.000000 |
| `min_tt_025C_1v80` | 0.000000 | 0.000000 |
| `nom_ff_n40C_1v95` | 0.000000 | 0.000000 |
| `nom_ss_100C_1v60` | 0.000000 | 0.000000 |
| `nom_tt_025C_1v80` | 0.000000 | 0.000000 |

- Worst setup WNS: **0.000000 ns** @ `max_ff_n40C_1v95`
- Worst hold WNS: **0.000000 ns** @ `max_ff_n40C_1v95`

## Electrical Metrics

Electrical violations are reported only when present in the OpenLane metrics. Missing metrics are **not interpreted as zero**.

### Max slew

| Metric | Value |
|---|---:|
| `design__max_slew_violation__count` | 7345.0 |
| `design__max_slew_violation__count__corner:max_ff_n40C_1v95` | 66.0 |
| `design__max_slew_violation__count__corner:max_ss_100C_1v60` | 7345.0 |
| `design__max_slew_violation__count__corner:max_tt_025C_1v80` | 851.0 |
| `design__max_slew_violation__count__corner:min_ff_n40C_1v95` | 0.0 |
| `design__max_slew_violation__count__corner:min_ss_100C_1v60` | 2338.0 |
| `design__max_slew_violation__count__corner:min_tt_025C_1v80` | 0.0 |
| `design__max_slew_violation__count__corner:nom_ff_n40C_1v95` | 0.0 |
| `design__max_slew_violation__count__corner:nom_ss_100C_1v60` | 4532.0 |
| `design__max_slew_violation__count__corner:nom_tt_025C_1v80` | 21.0 |

### Max capacitance

| Metric | Value |
|---|---:|
| `design__max_cap_violation__count` | 135.0 |
| `design__max_cap_violation__count__corner:max_ff_n40C_1v95` | 0.0 |
| `design__max_cap_violation__count__corner:max_ss_100C_1v60` | 135.0 |
| `design__max_cap_violation__count__corner:max_tt_025C_1v80` | 13.0 |
| `design__max_cap_violation__count__corner:min_ff_n40C_1v95` | 0.0 |
| `design__max_cap_violation__count__corner:min_ss_100C_1v60` | 68.0 |
| `design__max_cap_violation__count__corner:min_tt_025C_1v80` | 0.0 |
| `design__max_cap_violation__count__corner:nom_ff_n40C_1v95` | 0.0 |
| `design__max_cap_violation__count__corner:nom_ss_100C_1v60` | 104.0 |
| `design__max_cap_violation__count__corner:nom_tt_025C_1v80` | 0.0 |

### Max fanout

| Metric | Value |
|---|---:|
| `design__max_fanout_violation__count` | 0.0 |
| `design__max_fanout_violation__count__corner:max_ff_n40C_1v95` | 0.0 |
| `design__max_fanout_violation__count__corner:max_ss_100C_1v60` | 0.0 |
| `design__max_fanout_violation__count__corner:max_tt_025C_1v80` | 0.0 |
| `design__max_fanout_violation__count__corner:min_ff_n40C_1v95` | 0.0 |
| `design__max_fanout_violation__count__corner:min_ss_100C_1v60` | 0.0 |
| `design__max_fanout_violation__count__corner:min_tt_025C_1v80` | 0.0 |
| `design__max_fanout_violation__count__corner:nom_ff_n40C_1v95` | 0.0 |
| `design__max_fanout_violation__count__corner:nom_ss_100C_1v60` | 0.0 |
| `design__max_fanout_violation__count__corner:nom_tt_025C_1v80` | 0.0 |

## Signoff Reference

```text
antenna_status: PASS
drc_status: PASS
lvs_status: PASS
signoff_hold_view: min_ff_n40C_1v95
signoff_hold_wns_ns: 0.254094
signoff_setup_view: max_ss_100C_1v60
signoff_setup_wns_ns: 0.252381
```

> Power values, when present in raw OpenLane metrics, are tool-reported estimates and are not treated as silicon measurements.
