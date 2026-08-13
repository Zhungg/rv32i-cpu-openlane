# Changelog

All notable project releases are documented in this file.

## [1.1.0] - 2026-08-14

### Added

- **RV32M Hardware Multiplier/Divider Unit**:
  - Unified 33x33 multiplier with operand isolation (-35% dynamic execution power).
  - Synthesizable non-restoring divider handling RISC-V edge cases (divide-by-zero, signed overflow).
- **L1 Cache Subsystem**:
  - 2-Way Set-Associative 2KB Instruction Cache (Wishbone B4 burst line-fill).
  - 2-Way Set-Associative 2KB Data Cache (Write-Through + MMIO uncached bypass).
- **Physical Memory Protection (PMP v1.12)**:
  - 4-entry PMP checking unit supporting TOR, NA4, and NAPOT power-of-two address masking with Lock (`L=1`) support.
- **Low-Power Integrated Clock Gating (ICG)**:
  - Glitch-free ASIC ICG cell matching SkyWater 130nm cell (`sky130_fd_sc_hd__dlclkp`) for `WFI` sleep mode (< 0.8 mW).
- **Multi-Privilege Architecture & PLIC**:
  - Machine Mode (M-Mode) and User Mode (U-Mode) privilege controller.
  - 31-source Platform-Level Interrupt Controller (PLIC) with 3-bit priority arbitration and 16-byte UART FIFO.
- **SkyWater 130nm OpenRAM 2KB Hard Macro Adapter**:
  - Wishbone adapter for standard foundry 1RW1R 2KB SRAM macro, reducing memory silicon footprint by 80%.
- **Software Stack & Verification**:
  - C Hardware Abstraction Layer (HAL) drivers for DMA, Timer, UART, and PLIC.
  - Bare-metal runtime (`crt0.s`, `link.ld`) and example C applications.
  - Unified 12-suite regression testing (`make test-all`).

### Physical-Design Signoff (SkyWater 130nm)

- Placement target density optimized to 55%, reducing core area to $0.6995\text{ mm}^2$ (-24.3%).
- Total wirelength reduced by 24.1% ($1.450\text{ m}$), eliminating routing congestion and parasitic capacitances.
- 0 DRC, 0 LVS, 0 Antenna violations verified across multi-corner MCMM STA signoff.

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

## [1.0.0] - 2026-07-24

### Added

- Modular five-stage RV32I pipelined CPU implementation.
- Hazard detection, forwarding, stalls, flushes, and pipeline kills.
- Load/store unit, CSR, trap, exception, and interrupt infrastructure.
- Branch prediction infrastructure with BTB, PHT, and global history.
- Complete Sky130A RTL-to-GDSII implementation using OpenLane 2.
- MCMM setup and hold timing closure at a 20 ns clock period.
- Clean routing DRC, antenna, and LVS signoff.

[1.1.0]: https://github.com/Zhungg/rv32i-cpu-openlane/compare/v1.0.1...feat/rv32im-soc-ppa-signoff
[1.0.1]: https://github.com/Zhungg/rv32i-cpu-openlane/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/Zhungg/rv32i-cpu-openlane/releases/tag/v1.0.0
