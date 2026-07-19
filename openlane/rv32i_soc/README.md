# OpenLane 2 — rv32i_soc

Design directory cho top-level SoC sau khi `rv32i_core` đã pass verification và core-level physical design.

Cấu trúc mục tiêu:

```text
rv32i_soc/
├── config.json
├── pin_order.cfg
├── constraints.sdc
├── macro.cfg             # Khi tích hợp SRAM/macro
└── runs/
    └── RUN_<timestamp>/
```

Memory macro integration sẽ được xử lý riêng; tránh suy diễn RAM lớn thành standard-cell DFF nếu có SRAM macro phù hợp.
