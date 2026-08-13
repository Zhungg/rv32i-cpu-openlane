# Cấu trúc dự án

```text
rv32i_cpu_project/
├── config/                 # Shared RTL/file-list configuration
├── docs/                   # Architecture and design documentation
├── rtl/                    # Synthesizable SystemVerilog RTL
│   ├── pkg/
│   ├── core/
│   ├── frontend/
│   ├── decode/
│   ├── execute/
│   ├── memory/
│   ├── pipeline/
│   ├── control/
│   ├── commit/
│   ├── trap/
│   ├── infrastructure/
│   └── soc/
├── tb/
│   ├── common/
│   ├── unit/
│   ├── core/
│   ├── memory_models/
│   ├── programs/           # Current scope documented in README.md
│   └── formal/
├── sim/
│   └── waves/              # Generated simulation waveforms
├── synth/yosys/
│   └── work/               # Generated synthesis workspace
├── sta/opensta/
│   └── work/               # Generated standalone STA workspace
├── openlane/
│   ├── rv32i_core/         # Active core RTL-to-GDSII flow
│   │   └── runs/           # Raw generated OpenLane runs
│   └── rv32i_soc/          # Future SoC-level integration scope
├── formal/
├── scripts/
├── ci/
├── reports/
│   ├── signoff/            # Selected final signoff evidence
│   └── github_release_audit/
├── deliverables/           # Release artifact policy and manifests
└── Makefile
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

## Deferred Scope

The following areas are intentionally not represented as active release
subsystems:

- standalone bare-metal C/assembly software environment
- compiled ELF/HEX architectural program regression
- SoC-level physical implementation with SRAM/macro integration
- dedicated formal, coverage, and standalone STA report hierarchies

These areas may be developed later, but empty placeholder directories are not
kept solely to imply future functionality.
