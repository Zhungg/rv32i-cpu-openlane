# Cấu trúc Dự án RV32IM SoC

```text
rv32i_cpu_project/
├── config/                 # Filelist RTL, cấu hình tổng hợp và thông số SoC
├── deliverables/           # Sản phẩm đóng gói ký duyệt vật lý (Signoff Deliverables)
│   ├── layout/             # Bản vẽ LEF abstract và layout deliverables
│   ├── netlist/            # Netlist cổng logic (pnl.v, nl.v) và SPICE netlists
│   ├── reports/            # Số liệu QoR định lượng (CSV, JSON, Markdown)
│   └── timing/             # SDC ràng buộc, SDF 9 góc đo và SPEF ký sinh
├── docs/                   # Tài liệu kiến trúc và vi kiến trúc
├── openlane/
│   ├── rv32i_core/         # Luồng OpenLane 2 cho Lõi CPU
│   │   └── runs/           # Kết quả chạy OpenLane nguyên bản (ignored by Git)
│   └── rv32i_soc/          # Luồng OpenLane 2 cho Toàn bộ SoC
├── reports/
│   ├── qor/                # Báo cáo trích xuất chất lượng kết quả (QoR)
│   └── signoff/            # Báo cáo ký duyệt thời gian MCMM và chứng thực
├── rtl/                    # Mã nguồn RTL SystemVerilog
│   ├── cache/              # Bộ nhớ đệm L1 Instruction & Data Cache
│   ├── commit/             # Tầng Writeback và ghi nhận kết quả
│   ├── control/            # Khối Hazard, Forwarding và Integrated Clock Gating (ICG)
│   ├── core/               # Vi kiến trúc đường ống 5 tầng và Top-level Core
│   ├── decode/             # Bộ giải mã lệnh, Register File và giải mã RV32M
│   ├── execute/            # Khối ALU, so sánh nhánh và tính địa chỉ đích
│   ├── frontend/           # Fetch lệnh và BPU dự đoán nhánh động (Gshare PHT/BTB)
│   ├── mdu/                # Bộ nhân hợp nhất 33x33 và bộ chia phần cứng RV32M
│   ├── memory/             # Khối LSU và mô hình OpenRAM 2KB SRAM Macro
│   ├── pipeline/           # Các thanh ghi phân tầng pipeline
│   ├── pkg/                # SystemVerilog Packages (Types, CSR, Cache, Wishbone)
│   ├── soc/                # Wishbone Crossbar, DMA, PLIC, UART FIFO, Timer, SRAM
│   └── trap/               # Khối CSR, PMP checker và bộ điều khiển đặc quyền
├── scripts/                # Tập lệnh kiểm thử hồi quy và tự động hóa luồng ASIC
├── sw/                     # Ngăn xếp phần mềm C Bare-Metal & HAL
│   ├── examples/           # Chương trình mẫu C (hello_world, dma_transfer)
│   ├── include/            # Các file tiêu đề thanh ghi ngoại vi
│   ├── lib/                # Thư viện driver C (UART, Timer, DMA, PLIC)
│   ├── linker/             # Linker script chuẩn (link.ld)
│   └── startup/            # Mã khởi động CPU assembly (crt0.s)
├── tb/                     # Môi trường kiểm thử tự động (Testbenches)
│   ├── common/             # Tiện ích kiểm thử dùng chung
│   ├── compliance/         # Bộ kiểm thử tuân thủ kiến trúc RISC-V quốc tế
│   ├── core/               # Kiểm thử tích hợp mức Core
│   ├── integration/        # Kiểm thử tích hợp toàn bộ SoC và Wishbone Bus
│   ├── memory_models/      # Mô hình bộ nhớ mô phỏng
│   └── unit/               # Testbench mức đơn vị (Cache, PMP, Power, PLIC, MDU, SRAM)
└── Makefile                # 12 mục tiêu kiểm thử hồi quy tự động (make test-all)
```

## Phân loại Thư mục Artifacts

1. **`openlane/<design>/runs/`**: Chứa toàn bộ dữ liệu thô trung gian của OpenLane 2 (được Git bỏ qua để giữ sạch repository).
2. **`reports/`**: Báo cáo tổng hợp số liệu PPA (Power, Performance, Area, Slack, IR-Drop, DRC/LVS).
3. **`deliverables/`**: Chứa các tệp sản phẩm ký duyệt cuối cùng phục vụ đóng gói và kiểm thử silicon (GDS/LEF, Netlists, SDF, SPEF, SDC).
4. **`sw/`**: Môi trường phát triển phần mềm C Bare-Metal hoàn chỉnh với startup runtime `crt0.s` và trình biên dịch chéo GCC RISC-V.
