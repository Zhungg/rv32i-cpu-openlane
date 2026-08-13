# Physical-Design Deliverables

This directory documents the release-level physical-design artifacts for the
RV32I core.

## Canonical Signoff Baseline

- Design: `rv32i_core`
- PDK: Sky130A
- Flow: OpenLane 2
- Baseline release: `v1.0.0`
- Final run: `RUN_2026-07-23_18-56-04`
- Clock period: `20.000 ns`
- Setup timing: MET
- Hold timing: MET
- Routing DRC: PASS
- Antenna: PASS
- LVS: PASS

## Artifact Policy

Raw OpenLane run directories are intentionally not committed because they
contain large generated databases, intermediate files, logs, extracted
parasitics, and duplicated reports.

The local canonical run contains final implementation artifacts such as GDSII,
DEF, LEF, gate-level netlists, timing data, and extracted physical-design
outputs.

Selected human-readable signoff evidence is tracked under:

- `reports/signoff/`
- `reports/github_release_audit/`

Artifact inventories and cryptographic manifests may be generated from the
canonical local signoff run without committing the complete raw run directory.

## Release Integrity

The immutable RTL-to-GDSII physical-design baseline is identified by tag
`v1.0.0`.

Release `v1.0.1` adds CI, documentation, licensing, citation metadata, and
repository governance without changing the signed RTL or physical
implementation.
