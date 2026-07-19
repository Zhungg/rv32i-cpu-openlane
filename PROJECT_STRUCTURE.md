# Cấu trúc dự án

```text
rv32i_cpu_project/
├── config/                 # Cấu hình chung và file list
├── docs/                   # Audit, specification, diagram, review
├── rtl/                    # Toàn bộ synthesizable RTL
│   ├── pkg/                # Package, typedef, constant, enum
│   ├── core/               # Top core và datapath/control cấp cao
│   ├── frontend/           # PC, fetch, BPU, BTB, PHT, GHR
│   ├── decode/             # Decoder, immediate, register file
│   ├── execute/            # ALU, branch compare, target generation
│   ├── memory/             # LSU, aligner, transaction/fence control
│   ├── pipeline/           # IF/ID, ID/EX, EX/MEM, MEM/WB
│   ├── control/            # Hazard, forwarding, stall/flush/kill
│   ├── commit/             # Writeback, retirement/commit
│   ├── trap/               # Exception, CSR, interrupt, trap redirect
│   ├── infrastructure/     # Reset, clock enable, DFT preparation
│   └── soc/                # SoC wrapper, address decoder, memories
├── tb/                     # Verification environment
│   ├── common/             # Tasks, macros, scoreboard, interfaces
│   ├── unit/               # Unit-level self-checking testbench
│   ├── core/               # CPU-level testbench
│   ├── memory_models/      # IMEM/DMEM/bus behavioral models
│   ├── programs/           # Assembly/C/HEX regression programs
│   └── formal/             # Assertions, bind files, RVFI checks
├── sim/                    # Simulator-specific build/run files
├── sw/                     # Bare-metal support, linker, startup code
├── synth/yosys/            # Yosys synthesis flow độc lập
├── sta/opensta/            # Standalone OpenSTA flow
├── openlane/               # OpenLane 2 design directories
│   ├── rv32i_core/
│   │   ├── config.json     # Tạo sau khi top-level được chốt
│   │   ├── pin_order.cfg   # Tạo ở giai đoạn floorplan
│   │   └── runs/           # OpenLane tự sinh RUN_<timestamp>
│   └── rv32i_soc/
│       ├── config.json
│       ├── pin_order.cfg
│       └── runs/
├── formal/                 # Formal/equivalence configuration
├── scripts/                # Automation scripts dùng chung
├── ci/                     # Continuous integration
├── reports/                # Báo cáo chọn lọc, nhẹ, có thể commit
│   └── openlane/           # QoR/signoff summary trích từ run được chọn
├── deliverables/           # Final netlist/layout/timing/signoff output
├── audit_sources/          # Hai repo nguồn dùng cho audit/tham khảo
└── archive/                # Nội dung cũ không còn thuộc active flow
```

## Phân biệt `runs/`, `reports/` và `deliverables/`

### `openlane/<design>/runs/`

Đây là output nguyên bản do OpenLane 2 tự sinh. Một run điển hình:

```text
runs/RUN_YYYY-MM-DD_HH-MM-SS/
├── 01-verilator-lint/
├── 02-checker-linttimingconstructs/
├── ...
├── final/
├── tmp/
├── error.log
├── info.log
├── warning.log
└── resolved.json
```

Thư mục này có thể lớn, chứa nhiều file trung gian và không được commit lên Git. Chỉ file `.gitkeep` được giữ để skeleton repo luôn có thư mục `runs/`.

### `reports/`

Chứa các báo cáo đã chọn lọc hoặc summary do script của dự án tạo ra, ví dụ:

- Cell count và area summary.
- WNS/TNS setup/hold.
- DRC/LVS/antenna summary.
- Congestion và utilization summary.
- PPA/QoR comparison giữa các run.

### `deliverables/`

Chỉ chứa artifact cuối từ run đã được review và signoff, ví dụ:

- `.gds`, `.lef`, `.def`.
- Gate-level netlist.
- `.sdf`, `.spef`, `.sdc`.
- Báo cáo signoff cuối.
