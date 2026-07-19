# OpenLane 2 — rv32i_core

Design directory cho hardening CPU core.

Cấu trúc mục tiêu:

```text
rv32i_core/
├── config.json
├── pin_order.cfg
├── constraints.sdc
└── runs/
    └── RUN_<timestamp>/
```

- `config.json` sẽ đọc RTL trực tiếp; không dùng `SKIP_SYNTHESIS`.
- `runs/` do OpenLane 2 tự động tạo nội dung theo từng run tag.
- `runs/.gitkeep` chỉ giữ cấu trúc thư mục trên Git.
- Run đầu tiên ưu tiên flow clean ở clock period an toàn trước khi tối ưu PPA.
