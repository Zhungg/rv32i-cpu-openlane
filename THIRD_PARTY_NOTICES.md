# Third-Party Notices

This repository contains project-specific RTL, verification, configuration, automation, reports, and documentation for an RV32I CPU physical-design flow.

## External Tools and Technology

The project relies on the following external tools, standard-cell libraries, and PDKs. These components are governed by their own respective licenses and are **not** relicensed by this repository.

| Component | Category | License | Upstream / URL |
| :--- | :--- | :--- | :--- |
| **Yosys** | Synthesis | ISC | [YosysHQ/yosys](https://github.com/YosysHQ/yosys) |
| **OpenROAD** | P&R / Timing | BSD-3-Clause | [The-OpenROAD-Project](https://github.com/The-OpenROAD-Project/OpenROAD) |
| **OpenLane** | RTL-to-GDSII Flow | Apache-2.0 | [The-OpenROAD-Project/OpenLane](https://github.com/The-OpenROAD-Project/OpenLane) |
| **OpenSTA** | Static Timing Analysis | GPL-3.0 | [The-OpenROAD-Project/OpenSTA](https://github.com/The-OpenROAD-Project/OpenSTA) |
| **Verilator** | RTL Simulation | LGPL-3.0 / Artistic | [verilator/verilator](https://github.com/verilator/verilator) |
| **Icarus Verilog** | RTL Simulation | GPL-2.0 | [steveicarus/iverilog](https://github.com/steveicarus/iverilog) |
| **Magic** | VLSI Layout / DRC | MIT | [RTimothyEdwards/magic](https://github.com/RTimothyEdwards/magic) |
| **KLayout** | GDSII Viewer / DRC | GPL-3.0 | [KLayout/klayout](https://github.com/KLayout/klayout) |
| **Netgen** | LVS | GPL-2.0 | [RTimothyEdwards/netgen](https://github.com/RTimothyEdwards/netgen) |

## Process Design Kit (PDK) & Libraries

| Component | License | Upstream / URL |
| :--- | :--- | :--- |
| **SkyWater SKY130 PDK** | Apache-2.0 | [google/skywater-pdk](https://github.com/google/skywater-pdk) |
| **sky130_fd_sc_hd** | Apache-2.0 | Found within SKY130 PDK |

*Note: The physical standard cells (GDS/LEF) and technology files used during the flow belong to SkyWater Technology and Google.*

## RISC-V Trademark Notice

RISC-V is a registered trademark of RISC-V International. This project is an independent educational/engineering implementation of the RV32I instruction set architecture (ISA) and is not affiliated with, nor endorsed or certified by, RISC-V International.

## Adapted Source Material

Any third-party RTL source code (e.g., SRAM macros, specific arithmetic IP blocks) adapted in this repository retains its original copyright attribution in the respective file headers.
