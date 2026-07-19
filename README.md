# RV32I CPU — RTL to GDSII

Dự án xây dựng CPU RISC-V 32-bit theo RV32I, kiến trúc pipeline 5 stage, hướng đến flow hoàn chỉnh:

`Specification → RTL → Verification → Synthesis → STA → OpenLane 2 → Signoff → GDSII`

## Trạng thái dự án

| Bước | Nội dung | Trạng thái |
|---:|---|---|
| 1 | Repository audit và baseline selection | PASS |
| 1A | Repository skeleton/OpenLane runs verification | PASS |
| 2 | Architectural Specification | **PASS — v0.1** |
| 3 | Instruction Behavior Specification | **PASS — v0.1** |
| 4 | Microarchitecture Specification | **PASS — v0.1** |
| 5+ | Pipeline contracts, RTL, verification và RTL-to-GDSII | Chưa bắt đầu |

Architectural target hiện tại:

```text
RV32I_Zicntr_Zicsr_Zifencei
+ Machine-mode-only privileged support
+ precise trap/interrupt
+ 5-stage in-order pipeline
+ dynamic branch prediction
+ ready/valid memory interfaces
+ RVFI-style retirement trace
```

## Top-level dự kiến

- `rv32i_core`: CPU core, sử dụng instruction/data memory interface.
- `rv32i_soc`: wrapper tích hợp core, memory subsystem và các khối hệ thống cần thiết.

## Quy ước chính

- RTL synthesizable đặt trong `rtl/`.
- Testbench và model chỉ dành cho verification đặt trong `tb/`.
- Phần mềm thử nghiệm đặt trong `sw/` và `tb/programs/`.
- Mọi thay đổi kiến trúc phải được cập nhật trong `docs/spec/` trước khi sửa RTL.
- Không commit waveform, build tạm hoặc toàn bộ output OpenLane trong `runs/`.

## Quy ước OpenLane 2

Mỗi design OpenLane có một **design directory** riêng chứa `config.json`:

```text
openlane/
├── rv32i_core/
│   ├── config.json          # Sẽ tạo sau khi chốt top-level/constraint
│   ├── pin_order.cfg        # Sẽ tạo khi làm floorplan
│   └── runs/
│       └── RUN_<timestamp>/ # OpenLane 2 tự động sinh
└── rv32i_soc/
    ├── config.json
    ├── pin_order.cfg
    └── runs/
        └── RUN_<timestamp>/
```

OpenLane 2 đặt output tại `runs/<run_tag>` bên dưới thư mục chứa config. Mỗi run chứa các thư mục theo từng step, `final/`, `tmp/`, log và `resolved.json`.

- `openlane/<design>/runs/`: output gốc, có thể rất lớn, bị Git ignore.
- `reports/openlane/`: chỉ lưu các báo cáo/QoR summary được chọn lọc để commit.
- `deliverables/`: chỉ chứa artifact cuối đã kiểm tra như GDS, DEF, LEF, netlist, SDF, SPEF.

### Chạy bằng Docker image OpenLane 2

Sau khi có `config.json`:

```bash
source scripts/env.sh
./scripts/run_openlane.sh rv32i_core
```

Hoặc:

```bash
./scripts/run_openlane.sh rv32i_soc
```

Script mount project và `$PDK_ROOT`, chạy image `ghcr.io/efabless/openlane2:2.3.10`, đồng thời đặt working directory đúng tại design directory nên run sẽ xuất hiện ở:

```text
openlane/rv32i_core/runs/RUN_<timestamp>/
```

Xem `PROJECT_STRUCTURE.md` để biết vai trò từng thư mục.

## Project progress

| Step | Deliverable | Status |
|---:|---|---|
| 01 | Repository audit | PASS |
| 01A | Repository skeleton | PASS |
| 02 | Architectural Specification | PASS |
| 03 | Instruction Behavior Specification | PASS |
| 04 | Microarchitecture Specification | PASS |
| 05 | Pipeline Contract | NEXT |

