# OpenLane 2 workspace

Mỗi thư mục con là một OpenLane **design directory** độc lập. File `config.json` nằm ở đâu thì OpenLane 2 sẽ tạo `runs/` bên dưới chính thư mục đó.

```text
openlane/<design>/
├── config.json
├── pin_order.cfg
├── constraints.sdc       # Nếu dùng SDC riêng
└── runs/
    └── RUN_<timestamp>/
```

Không dùng một thư mục `runs/` chung ở project root. Output core và SoC phải được tách riêng để tránh trộn config, metrics và final views.
