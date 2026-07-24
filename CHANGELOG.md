# Changelog

All notable project releases are documented in this file.

## [1.0.1] - 2026-07-24

### Added

- Automated GitHub Actions RTL verification and Yosys synthesis-readiness checks.
- Repository structure and tracked-artifact auditing.
- Apache License 2.0.
- Machine-readable citation metadata.
- Contribution guidelines and third-party notices.
- Protected-main pull-request workflow with required CI checks.

### Changed

- Refreshed the repository landing page and engineering documentation.
- Improved repository reproducibility, governance, and release metadata.
- Corrected malformed `CITATION.cff` author, version, URL, and release-date fields.

### Physical-Design Baseline

- No RTL, generated RTL, timing constraint, floorplan, placement, CTS,
  routing, netlist, GDSII, or signoff result is changed by this release.
- The physical-design baseline remains the Sky130A 20 ns timing-closed
  implementation originally published as `v1.0.0`.
- The signed generated RTL remains:

  `openlane/rv32i_core/src/rv32i_core.v`

- Signed RTL SHA-256:

  `be518b98fcc1a25c37888731e001e08192ba4d12f02b3dd303adff19a9c46168`

## [1.0.0] - 2026-07-24

### Added

- Modular five-stage RV32I pipelined CPU implementation.
- Hazard detection, forwarding, stalls, flushes, and pipeline kills.
- Load/store unit, CSR, trap, exception, and interrupt infrastructure.
- Branch prediction infrastructure with BTB, PHT, and global history.
- Self-checking frontend and integration verification.
- Complete Sky130A RTL-to-GDSII implementation using OpenLane 2.
- MCMM setup and hold timing closure at a 20 ns clock period.
- Clean routing DRC, antenna, and LVS signoff.
- Reproducible engineering release and selected signoff evidence.

[1.0.1]: https://github.com/Zhungg/rv32i-cpu-openlane/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/Zhungg/rv32i-cpu-openlane/releases/tag/v1.0.0
