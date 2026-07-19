# RV32I CPU Microarchitecture Specification

**Document ID:** `RV32I-MICROARCH-SPEC`  
**Version:** `0.1`  
**Status:** `BASELINE — chốt cho RTL implementation v1`  
**Depends on:** `rv32i_architecture_spec.md`, `instruction_behavior.md`  
**Target core:** `rv32i_core`  
**Target SoC wrapper:** `rv32i_soc`  
**Last updated:** `2026-07-19`

---

## 1. Mục đích

Tài liệu này khóa **cách CPU được tổ chức ở mức microarchitecture** để mọi module RTL, testbench, formal property, synthesis constraint và Physical Design sử dụng cùng một hợp đồng.

Tài liệu trả lời các câu hỏi:

- CPU có bao nhiêu stage và instruction đi qua từng stage như thế nào?
- Dữ liệu/control nào được giữ trong mỗi pipeline register?
- Stage nào được phép stall, flush hoặc kill?
- Khi nào forwarding được dùng và khi nào bắt buộc stall?
- Branch prediction metadata được tạo, truyền và cập nhật ra sao?
- Memory request/response có thể chờ bao lâu và pipeline backpressure như thế nào?
- Architectural side effect được phép xảy ra tại đâu?
- Exception, interrupt, `MRET`, `FENCE.I` và branch misprediction tranh quyền redirect ra sao?
- Những state nào được reset và state nào cố ý không reset để giảm area/reset fanout?

Tài liệu này **không thay thế** đặc tả ISA-visible. Nếu microarchitecture trong tài liệu này mâu thuẫn với `rv32i_architecture_spec.md` hoặc RISC-V specification chính thức, architectural specification được ưu tiên.

---

## 2. Tài liệu chuẩn và tài liệu dự án liên quan

### 2.1 Tài liệu chuẩn

1. RISC-V Unprivileged ISA, RV32I Version 2.1.
2. RISC-V `Zicsr` Version 2.0.
3. RISC-V `Zifencei` Version 2.0.
4. RISC-V `Zicntr` Version 2.0.
5. RISC-V Privileged Architecture, Machine-Level ISA Version 1.13.
6. RISC-V Formal Interface — RVFI conventions.

### 2.2 Tài liệu nội bộ

| Tài liệu | Vai trò |
|---|---|
| `rv32i_architecture_spec.md` | Architectural state, reset, trap/CSR và ISA scope |
| `instruction_behavior.md` | Encoding và hành vi của từng instruction |
| `pipeline_contract.md` | Chi tiết valid/ready/stall/flush/kill giữa các stage |
| `hazard_and_forwarding_spec.md` | Dependency, bypass priority và stall equations |
| `branch_prediction_spec.md` | BTB/PHT/GHR/RAS, prediction và training |
| `memory_interface_spec.md` | Ready/valid protocol và transaction lifetime |
| `trap_interrupt_csr_spec.md` | CSR masks, trap priority và interrupt timing |
| `verification_plan.md` | Verification matrix và sign-off criteria |

Các tài liệu chuyên biệt có thể bổ sung chi tiết, nhưng không được thay đổi quyết định cấp cao đã khóa trong tài liệu này nếu chưa review và tăng version.

---

## 3. Mục tiêu thiết kế

### 3.1 Mục tiêu chức năng

Core phải triển khai:

```text
RV32I_Zicntr_Zicsr_Zifencei
+ Machine-mode only
+ precise synchronous traps
+ machine software/timer/external interrupts
+ dynamic branch prediction
+ ready/valid instruction and data interfaces
+ RVFI-style commit trace
```

### 3.2 Mục tiêu microarchitecture

- Single-issue, in-order.
- Pipeline 5 stage logic: `IF → ID → EX → MEM → WB/COMMIT`.
- Tối đa một instruction architectural completion mỗi chu kỳ.
- Ideal throughput: 1 instruction/cycle sau khi fill pipeline, khi không hazard/redirect/memory wait.
- Không speculative data-memory side effect.
- Branch prediction chỉ ảnh hưởng performance, không ảnh hưởng architectural result.
- Mọi exception/trap phải precise.
- RTL synthesizable bằng Yosys và phù hợp Sky130/OpenLane 2.
- Tránh inferred latch, internally generated clock và reset fanout không cần thiết.

### 3.3 Non-goals của RTL v1

Các mục dưới đây không thuộc implementation v1, nhưng hierarchy không được cản trở việc bổ sung sau này:

- Superscalar hoặc out-of-order execution.
- Register renaming hoặc reorder buffer.
- Caches, MMU, TLB, virtual memory.
- Store buffer cho phép store retire trước bus response.
- Nhiều outstanding data transactions.
- Coherency đa hart.
- M/A/F/D/C/V extensions.
- Debug Module chuẩn RISC-V.
- Commercial-grade scan insertion/ATPG.

---

## 4. Cấu hình baseline đã khóa

| Parameter | Giá trị mặc định | Ý nghĩa |
|---|---:|---|
| `XLEN` | 32 | Integer/address width |
| `ILEN` | 32 | Instruction width |
| `RESET_VECTOR` | `32'h0000_0000` | PC sau reset |
| `MTVEC_RESET` | `32'h0000_0100` | Trap vector reset, Direct mode |
| `HART_ID` | 0 | `mhartid` |
| `NRET` | 1 | Tối đa một RVFI/commit channel |
| `ENABLE_BPU` | 1 | Bật dynamic predictor ở sản phẩm cuối |
| `BTB_ENTRIES` | 64 | Direct-mapped BTB |
| `PHT_ENTRIES` | 256 | 2-bit saturating counters |
| `GHR_BITS` | 8 | Global history width |
| `RAS_DEPTH` | 8 | Return-address stack depth |
| `IMEM_MAX_OUTSTANDING` | 1 | Một instruction request đang chờ |
| `DMEM_MAX_OUTSTANDING` | 1 | Một data request đang chờ |
| `FETCH_BUFFER_DEPTH` | 1 | Một response packet chờ decode |
| `WFI_SLEEP_ENABLE` | 0 | RTL v1 thực thi WFI như NOP hợp lệ |
| `ENABLE_RVFI` | 1 | Xuất RVFI-style trace |

Các kích thước predictor là **microarchitecture parameters**, không phải ISA state. Thay đổi chúng không được làm thay đổi kết quả chương trình.

---

## 5. Tổng quan datapath và control path

```text
                                  +-----------------------------+
                                  | Trap / Interrupt / CSR Unit |
                                  +-------------+---------------+
                                                |
                                                v
+-----------+   +---------+   +---------+   +---------+   +-----------+
| Frontend  |-->| IF / ID |-->| ID / EX |-->| EX / MEM|-->| MEM / WB  |
| PC + BPU  |   +---------+   +---------+   +---------+   +-----------+
+-----+-----+        |             |             |              |
      |              v             v             v              v
      |          Decoder +       ALU +          LSU +        Commit +
      |          Regfile       Branch/Target   D-Memory      WB + RVFI
      |              ^             ^             |              |
      |              |             |             |              |
      +-------- Redirect / Stall / Flush / Kill Controller -----+
```

### 5.1 Hai luồng state độc lập

**Architectural state:**

- GPR `x0–x31`.
- PC architectural sequence.
- Machine CSR state.
- `mcycle/minstret`.
- Memory side effects đã retire.

**Microarchitectural state:**

- Pipeline valid bits và payload.
- Fetch request tracker và epoch.
- BTB/PHT/GHR/RAS.
- Forwarding selects.
- Outstanding memory transaction state.
- Performance-event counters nội bộ.

Microarchitectural state có thể bị flush/reset mà không thay đổi architectural result.

---

## 6. Module hierarchy baseline

```text
rv32i_core
├── infrastructure
│   ├── rv32i_reset_sync
│   └── rv32i_clock_enable_ctrl
├── frontend
│   ├── rv32i_fetch_unit
│   │   ├── pc_state
│   │   ├── imem_request_tracker
│   │   └── fetch_buffer
│   └── rv32i_bpu
│       ├── rv32i_btb
│       ├── rv32i_pht
│       ├── rv32i_ghr
│       └── rv32i_ras
├── decode
│   ├── rv32i_decoder
│   ├── rv32i_imm_gen
│   ├── rv32i_regfile
│   └── rv32i_csr_access_check
├── execute
│   ├── rv32i_alu
│   ├── rv32i_branch_compare
│   ├── rv32i_target_gen
│   └── rv32i_operand_forward_mux
├── memory
│   ├── rv32i_lsu
│   ├── rv32i_store_align
│   ├── rv32i_load_align
│   └── rv32i_dmem_controller
├── pipeline
│   ├── rv32i_if_id_reg
│   ├── rv32i_id_ex_reg
│   ├── rv32i_ex_mem_reg
│   └── rv32i_mem_wb_reg
├── control
│   ├── rv32i_hazard_unit
│   ├── rv32i_forward_unit
│   ├── rv32i_redirect_arbiter
│   └── rv32i_pipeline_ctrl
├── trap
│   ├── rv32i_csr_file
│   ├── rv32i_exception_arbiter
│   ├── rv32i_interrupt_ctrl
│   └── rv32i_trap_ctrl
└── commit
    ├── rv32i_writeback
    ├── rv32i_commit_unit
    └── rv32i_rvfi_adapter
```

Module inventory machine-readable nằm tại `config/module_hierarchy.csv`.

### 6.1 Quy tắc phân chia module

- Leaf combinational block không tự tạo state.
- State chỉ nằm trong module có ownership rõ ràng.
- Pipeline register không tự quyết định hazard; chỉ nhận `load/hold/clear` từ pipeline controller.
- Decoder không phát memory request hoặc writeback trực tiếp.
- BPU không trực tiếp thay đổi architectural PC; frontend chọn speculative fetch PC, còn actual redirect do redirect arbiter kiểm soát.
- CSR write chỉ được áp dụng tại commit/trap boundary.
- D-memory request chỉ được phát bởi LSU/D-memory controller sau khi nhận commit authorization.

---

## 7. Top-level interface của `rv32i_core`

Tên port cuối cùng sẽ được khóa khi viết `memory_interface_spec.md`, nhưng nhóm tín hiệu bắt buộc như sau:

```systemverilog
module rv32i_core #(
    parameter logic [31:0] RESET_VECTOR = 32'h0000_0000,
    parameter logic [31:0] MTVEC_RESET  = 32'h0000_0100,
    parameter int unsigned HART_ID      = 0,
    parameter bit ENABLE_BPU            = 1'b1,
    parameter bit ENABLE_RVFI           = 1'b1
)(
    input  logic        clk,
    input  logic        rst_n,

    output logic        imem_req_valid,
    input  logic        imem_req_ready,
    output logic [31:0] imem_req_addr,
    input  logic        imem_rsp_valid,
    output logic        imem_rsp_ready,
    input  logic [31:0] imem_rsp_data,
    input  logic        imem_rsp_error,

    output logic        dmem_req_valid,
    input  logic        dmem_req_ready,
    output logic        dmem_req_write,
    output logic [31:0] dmem_req_addr,
    output logic [31:0] dmem_req_wdata,
    output logic [3:0]  dmem_req_wstrb,
    input  logic        dmem_rsp_valid,
    output logic        dmem_rsp_ready,
    input  logic [31:0] dmem_rsp_rdata,
    input  logic        dmem_rsp_error,

    input  logic        irq_software_i,
    input  logic        irq_timer_i,
    input  logic        irq_external_i,
    input  logic [63:0] time_i

    // RVFI-style outputs được khai báo trong rv32i_core.sv.
);
```

### 7.1 Interface invariants

- Request payload phải ổn định trong khi `valid=1 && ready=0`.
- Response chỉ được consume khi `rsp_valid && rsp_ready`.
- Không có transaction ID vì mỗi channel chỉ có tối đa một outstanding transaction.
- Instruction response có thể bị discard bằng epoch nếu thuộc wrong path.
- Data response không được discard tùy ý; nó thuộc instruction đang giữ MEM stage.

---

## 8. Pipeline execution model

### 8.1 Stage IF — Instruction Fetch

Nhiệm vụ:

1. Giữ speculative fetch PC.
2. Query BPU bằng PC hiện tại.
3. Phát instruction-memory request.
4. Theo dõi một outstanding request.
5. Nhận instruction/fault response.
6. Gắn prediction metadata và fetch epoch.
7. Đưa packet vào fetch buffer/IF-ID khi còn hợp lệ.

IF không decode toàn bộ instruction. Predictor sử dụng BTB/PHT/RAS metadata; direct JAL chưa có BTB hit có thể bị phát hiện muộn và redirect tại EX.

### 8.2 Stage ID — Decode/Register Read

Nhiệm vụ:

1. Strict instruction decode.
2. Immediate generation.
3. Đọc hai source GPR.
4. Xác định source-use flags và destination register.
5. Kiểm tra illegal encoding và CSR access legality sơ bộ.
6. Tạo control bundle typed bằng enum/struct trong `rv32i_pkg.sv`.
7. Phát hiện hazard cần stall.
8. Chuyển prediction/fetch exception metadata nguyên vẹn sang ID/EX.

Decode không tạo architectural side effect.

### 8.3 Stage EX — Execute/Resolve

Nhiệm vụ:

1. Chọn operand sau forwarding.
2. Arithmetic/logic/shift/compare.
3. Tính effective address load/store.
4. Tạo branch/jump target và actual direction.
5. So sánh actual next PC với predicted next PC.
6. Phát branch-mispredict redirect.
7. Kiểm tra control target alignment.
8. Kiểm tra data access alignment trước khi phát bus request.
9. Tính CSR read-modify-write candidate, chưa commit.

Mọi branch và jump được resolve ở EX trong RTL v1.

### 8.4 Stage MEM — Memory/Long-latency Hold

Nhiệm vụ:

1. Giữ instruction trong khi chờ D-memory authorization/request/response.
2. Tạo aligned store payload và byte strobes.
3. Nhận/align/sign-extend load data.
4. Ghi nhận access fault response.
5. Chuyển non-memory result thẳng sang MEM/WB.

EX/MEM là stage có thể giữ nhiều chu kỳ. Khi MEM bị hold, EX, ID và frontend bị backpressure theo valid/ready chain.

### 8.5 Stage WB/COMMIT — Architectural Completion

Nhiệm vụ:

1. Chọn final GPR writeback data.
2. Commit GPR write nếu instruction hợp lệ.
3. Commit CSR write hoặc trap-state update.
4. Tăng `minstret` cho instruction retire thành công.
5. Cập nhật BPU bằng control-flow instruction không bị kill/trap.
6. Sinh RVFI-style packet.
7. Thực hiện trap/MRET/FENCE.I/interrupt redirect có priority cao.
8. Duy trì `arch_next_pc`, PC của instruction tiếp theo chưa retire.

Tối đa một packet completion được xử lý mỗi chu kỳ.

---

## 9. Pipeline packet model

Mỗi pipeline stage có:

```systemverilog
logic valid;
payload_t payload;
```

`valid=0` nghĩa payload không có ý nghĩa và không được tạo side effect.

### 9.1 Common metadata

Mọi instruction packet từ IF/ID trở đi phải mang tối thiểu:

```text
pc
instruction
pc_plus_4
exception.valid
exception.cause
exception.tval
prediction metadata
```

### 9.2 IF/ID payload

- `pc`.
- `insn`.
- `pc_plus_4`.
- `fetch_fault` và fault address.
- `pred_taken`.
- `pred_target`.
- `pred_next_pc`.
- `btb_hit`.
- `pred_kind`.
- `pht_index`.
- `ghr_snapshot`.
- `ras_snapshot/action metadata` khi cần.
- `fetch_epoch`.

### 9.3 ID/EX payload

Ngoài common/prediction metadata:

- Internal operation enum.
- `rs1_addr`, `rs2_addr`, `rd_addr`.
- `rs1_value`, `rs2_value`.
- `uses_rs1`, `uses_rs2`, `writes_rd`.
- Immediate.
- ALU operand-select và ALU operation.
- Branch/jump kind.
- Load/store size và sign mode.
- Writeback select.
- CSR address, read/write intent và source operand.
- Serialization flags: CSR, FENCE, FENCE.I, MRET, WFI.
- Exception metadata từ fetch/decode.

### 9.4 EX/MEM payload

- Final forwarded source values phục vụ RVFI.
- ALU result/effective address.
- Forwarded store data.
- `rd_addr`, writeback controls.
- Actual branch taken/target/next PC.
- Mispredict flag.
- Load/store controls.
- CSR old value, candidate new value và write mask.
- Exception metadata sau EX.
- Prediction metadata để commit-time training.
- Memory/RVFI byte masks.

### 9.5 MEM/WB payload

- Final GPR result.
- Load data đã align/extend.
- Memory address, read/write masks và data cho RVFI.
- CSR commit data.
- Actual next PC.
- Exception metadata sau memory response.
- Control-flow outcome và predictor training packet.
- `writes_rd`, `writes_csr`, `is_store`, `is_load`, `is_control_flow`.
- Source register addresses/data để xuất trace.

Chi tiết cột dữ liệu nằm tại `config/pipeline_payload_matrix.csv`.

---

## 10. Valid, ready, stall, flush và kill

### 10.1 Thuật ngữ

- **valid:** stage đang chứa instruction packet hợp lệ.
- **ready:** stage có thể nhận packet mới tại cạnh clock tiếp theo.
- **stall/hold:** giữ nguyên valid và payload hiện tại.
- **bubble:** valid=0 được chèn vào pipeline.
- **flush/kill:** xóa valid của instruction trẻ hơn do redirect/trap.
- **transfer/fire:** `upstream_valid && upstream_ready`.

### 10.2 Elastic-stage rule

Khái niệm chuẩn cho mỗi stage:

```text
stage_ready = !stage_valid || (downstream_ready && !local_hold)
```

Implementation có thể tối ưu equation nhưng phải giữ behavior tương đương.

### 10.3 Hold rule

Khi stage bị hold:

- `valid` giữ nguyên.
- toàn bộ payload giữ nguyên bit-for-bit;
- không lặp side effect;
- request `valid` và payload giữ ổn định nếu đang chờ `ready`.

### 10.4 Kill rule

Khi instruction bị kill:

- stage valid bị clear tại cạnh clock;
- không GPR/CSR write;
- không D-memory request mới;
- không BPU training;
- không `minstret` increment;
- không RVFI non-trap retirement packet.

### 10.5 Backpressure propagation

- MEM wait chặn EX/MEM transfer.
- EX không ready làm ID/EX giữ.
- ID không ready làm IF/ID giữ.
- IF/ID đầy làm fetch buffer giữ hoặc ngừng phát request.

Không được overwrite instruction packet khi downstream không ready.

---

## 11. Redirect và pipeline recovery

### 11.1 Redirect sources

- Reset entry.
- Synchronous trap tại commit.
- Interrupt tại architectural boundary.
- `MRET` tại commit.
- `FENCE.I` frontend restart.
- Branch/jump misprediction tại EX.

### 11.2 Priority đã khóa

Priority tổng thể, từ cao xuống thấp:

```text
1. Reset
2. Synchronous exception/trap của instruction ở WB
3. Post-commit interrupt trap
4. MRET/FENCE.I commit redirect nếu không bị interrupt override
5. EX branch/jump misprediction redirect
6. BPU predicted next PC
7. Sequential PC + 4
```

Chi tiết quan trọng:

- Synchronous exception của instruction đang WB luôn thắng interrupt cùng boundary.
- Instruction hợp lệ ở WB được commit trước khi interrupt được nhận.
- CSR/MRET state update được áp dụng, sau đó điều kiện interrupt được đánh giá bằng post-commit state.
- Nếu `MRET` bật lại `mstatus.MIE` và interrupt ngay lập tức đủ điều kiện, interrupt có thể override target MRET; `mepc` khi đó nhận target mà MRET sẽ đi tới.
- Commit-level redirect luôn thắng EX redirect vì instruction ở WB già hơn.

### 11.3 Kill scope

| Redirect source | Instruction bị kill |
|---|---|
| EX mispredict | IF/ID và ID/EX trẻ hơn branch; fetch buffer/request epoch cũ |
| WB trap | Tất cả instruction trẻ hơn ở MEM/EX/ID/IF |
| WB interrupt | Tất cả instruction chưa retire |
| MRET | Tất cả instruction trẻ hơn MRET |
| FENCE.I | Frontend buffer/request và instruction trẻ hơn FENCE.I |
| Reset | Toàn bộ pipeline và outstanding state |

### 11.4 Fetch epoch

Frontend duy trì `fetch_epoch` ít nhất 2 bit:

- Mỗi redirect/flush frontend tăng epoch modulo chiều rộng.
- Outstanding request lưu epoch tại lúc handshake.
- Response chỉ được enqueue nếu request epoch bằng current epoch.
- Response stale vẫn phải handshake rồi discard.
- Với một outstanding request, wraparound không được xảy ra trước khi request cũ được thu hồi; pipeline controller phải ngăn redirect count vượt khả năng phân biệt hoặc dùng epoch đủ rộng.

Baseline chọn epoch 2 bit và chỉ một outstanding request, nên stale request được drain trước khi tái sử dụng cùng epoch value.

---

## 12. Register file và operand timing

### 12.1 Register file

- 32 × 32-bit.
- Hai cổng đọc combinational.
- Một cổng ghi synchronous tại commit.
- `x0` hardwired zero.
- Ghi `x0` bị mask.
- `x1–x31` không reset.

### 12.2 Same-cycle WB-to-ID behavior

Nếu WB commit ghi register mà ID đang đọc cùng địa chỉ, ID phải nhận giá trị mới bằng một trong hai cách:

1. explicit WB→ID bypass; hoặc
2. register-file write-first behavior đã được verify trên synthesis model.

Baseline yêu cầu **explicit WB→ID bypass**, không phụ thuộc implementation-specific memory inference.

### 12.3 Source-use flags

Hazard logic không được chỉ nhìn `rs1/rs2` bits; decoder phải phát:

```text
uses_rs1
uses_rs2
uses_store_data
uses_csr_source
```

Ví dụ:

- LUI không dùng `rs1/rs2` dù các bit field trùng vị trí.
- Immediate ALU dùng `rs1`, không dùng `rs2`.
- Store dùng `rs1` cho address và `rs2` cho data.
- CSR immediate không đọc GPR source.

---

## 13. Forwarding và data hazards

### 13.1 EX operand forwarding priority

Cho mỗi operand EX:

```text
1. EX/MEM result nếu destination khớp và result đã sẵn sàng
2. MEM/WB final result nếu destination khớp
3. ID/EX captured register value
```

EX/MEM không được forward load data trước khi memory response hoàn thành.

### 13.2 Forwardable EX/MEM results

Có thể forward từ EX/MEM:

- ALU result.
- AUIPC/LUI result.
- `pc+4` cho JAL/JALR.
- CSR result chỉ khi design chứng minh value sẵn sàng và không phá serialization; baseline không dùng đường này.

Không forward từ EX/MEM:

- Load chưa có response.
- Instruction có exception.
- Instruction bị kill.

### 13.3 Load-use hazard

Nếu instruction ở EX là load và instruction ở ID cần `rd` của load:

- Hold PC/frontend và IF/ID.
- Chèn bubble vào ID/EX sau khi load tiến sang EX/MEM.
- Tiếp tục cho tới khi load result có thể forward từ MEM/WB.

Vì D-memory có variable latency, stall có thể kéo dài nhiều chu kỳ.

### 13.4 Store forwarding

Store có hai dependency độc lập:

- Base address operand (`rs1`) dùng forwarding như ALU operand A.
- Store data (`rs2`) có forwarding riêng và phải giữ giá trị final trong EX/MEM.

Load→store-data dependency vẫn phải stall tới khi load data sẵn sàng.

### 13.5 Branch forwarding

Branch comparator tại EX dùng cùng forwarded operands với ALU. Không tạo comparator riêng đọc stale register-file value.

### 13.6 CSR serialization

Baseline chọn policy đơn giản và precise:

- CSR instruction, MRET, FENCE, FENCE.I và WFI là **serializing operations**.
- Khi một serializing instruction đã vào ID/EX, ID không phát instruction trẻ hơn cho tới khi operation commit hoặc trap.
- CSR write chỉ xảy ra tại WB.
- Cách này loại bỏ CSR RAW/WAW hazard và bảo đảm interrupt reevaluation sau CSR write đúng boundary.

Sau này có thể thay bằng CSR bypass, nhưng phải cập nhật spec và formal properties.

---

## 14. Branch prediction microarchitecture

### 14.1 Predictor components

Baseline BPU gồm:

- 64-entry direct-mapped BTB.
- 256-entry PHT, mỗi entry là 2-bit saturating counter.
- 8-bit GHR.
- 8-entry RAS.
- Prediction metadata pipeline từ IF tới WB.

### 14.2 BTB

Mỗi entry giữ:

```text
valid
tag
target
control_flow_kind
```

Default mapping:

- Index: `pc[7:2]` cho 64 entries.
- Tag: các bit PC còn lại phía trên index.
- BTB chỉ dự đoán target khi valid và tag match.

### 14.3 PHT/GShare

Conditional-branch index:

```text
pht_index = pc_index XOR ghr_snapshot
```

Với baseline:

```text
pc_index = pc[9:2]
ghr_snapshot = GHR[7:0]
```

Counter encoding:

```text
00 strongly not taken
01 weakly not taken
10 weakly taken
11 strongly taken
```

Prediction taken khi MSB=1 và BTB hit có target hợp lệ.

### 14.4 GHR

- GHR chỉ track conditional branch outcome.
- Baseline **không speculative update GHR** ở IF.
- GHR update tại commit của branch hợp lệ.
- Prediction packet mang `ghr_snapshot` và `pht_index` đã dùng lúc predict.

Không dùng current GHR để update một branch cũ.

### 14.5 RAS

RAS dùng implicit RISC-V call/return hints:

- JAL push khi `rd` là `x1` hoặc `x5`.
- JALR push/pop theo quan hệ `rd`, `rs1` và link registers `x1/x5`.
- RAS state update tại commit.
- Prediction-time pop chỉ là speculative read; baseline không destructively pop trước commit.
- Underflow làm RAS prediction invalid, không ảnh hưởng correctness.

### 14.6 Prediction packet

Mỗi fetched instruction mang:

```text
pred_valid
pred_taken
pred_target
pred_next_pc
btb_hit
pred_kind
pht_index
ghr_snapshot
ras_used
```

### 14.7 Misprediction detection

Tại EX:

```text
actual_next_pc = branch_taken ? branch_target : pc_plus_4
```

Mispredict nếu:

- predicted taken khác actual taken; hoặc
- cả hai taken nhưng predicted target khác actual target; hoặc
- instruction không phải control-flow nhưng BPU predicted taken.

Không được so sánh actual next PC với `pc_D` hoặc PC của instruction trẻ hơn.

### 14.8 Training

BPU training chỉ xảy ra khi control-flow instruction:

- đến commit;
- không trap;
- không bị kill;
- có prediction metadata hợp lệ.

Training packet dùng **prediction-time PHT index/GHR snapshot**. BTB target được cập nhật bằng actual target. Wrong-path instruction không train predictor.

### 14.9 `ENABLE_BPU=0`

- Next PC luôn sequential trừ actual EX redirect.
- Prediction metadata vẫn có deterministic zero/default.
- Architectural result và RVFI trace phải giống cấu hình BPU bật.

---

## 15. Instruction-fetch subsystem

### 15.1 Outstanding policy

- Tối đa một request chưa có response.
- Một fetch buffer entry giữ response đã nhận nhưng chưa chuyển IF/ID.
- Frontend ngừng phát request khi cả request slot và response buffer không còn capacity.

### 15.2 Request address

Request PC phải:

- căn chỉnh 4 byte;
- đến từ redirect target ưu tiên cao nhất, BPU target hoặc sequential PC;
- được capture cùng epoch khi handshake.

### 15.3 Instruction access fault

Khi `imem_rsp_error=1`:

- Tạo packet với instruction access fault metadata.
- `tval` là faulting request address.
- Instruction bits có thể đặt zero cho RVFI fault representation.
- Decoder không được chuyển fault packet thành illegal instruction.

### 15.4 Redirect khi request đang outstanding

- Không giả định bus hỗ trợ cancel.
- Tăng epoch và đánh dấu request cũ stale.
- Chờ response cũ, handshake và discard.
- Có thể phát request target mới cùng chu kỳ stale response được consume nếu tracker trở thành free.

---

## 16. Load/Store Unit và D-memory policy

### 16.1 Effective address

Tính tại EX:

```text
addr = rs1_forwarded + sign_extended_immediate
```

### 16.2 Alignment check

- Byte: luôn aligned.
- Halfword: `addr[0] == 0`.
- Word: `addr[1:0] == 0`.

Misaligned access:

- tạo exception tại EX;
- không phát D-memory request;
- không partial write;
- không writeback load result.

### 16.3 Precise side-effect authorization

Để hỗ trợ memory-mapped I/O có side effect, **mọi D-memory request**, không chỉ store, chỉ được phát khi memory instruction là instruction già nhất chưa hoàn thành.

Baseline authorization:

```text
mem_issue_safe = ex_mem_valid
              && is_memory_op
              && !exception_valid
              && !mem_request_sent
              && !mem_wb_valid
              && !commit_redirect_pending
              && !interrupt_take_pending
```

Ý nghĩa:

- MEM/WB phải trống tại đầu chu kỳ, nên không còn instruction già hơn.
- Interrupt đủ điều kiện được lấy trước khi instruction memory-side-effect trẻ hơn phát request.
- Chính sách này bảo đảm load MMIO wrong-path/younger-than-trap không tạo side effect.

Đây là lựa chọn correctness-first; performance optimization về sau cần proof riêng.

### 16.4 Request lifetime

Sau request handshake:

- EX/MEM giữ transaction metadata.
- Không phát request lần hai.
- `dmem_rsp_ready=1` khi transaction active và core có thể capture response.
- Upstream pipeline stall tới response.

### 16.5 Store

Store payload:

- address được word-align trên bus nếu interface chọn aligned-word convention;
- `wstrb` chọn byte lanes;
- `wdata` được shift vào lane tương ứng;
- store được xem là retire chỉ sau successful response.

Bus/SoC contract phải bảo đảm write response error không để lại architectural partial side effect.

### 16.6 Load

- Request vẫn xảy ra khi `rd=x0`.
- Response data được chọn byte/halfword bằng address low bits.
- Sign/zero extension được thực hiện trước MEM/WB.
- Error response tạo load access fault và suppress GPR write.

### 16.7 Memory ordering

Do một outstanding transaction, in-order issue và không store buffer:

- Data transactions tự nhiên theo program order.
- FENCE chờ mọi outstanding instruction/data transaction liên quan hoàn thành rồi retire.
- FENCE.I chờ prior stores complete, flush frontend và restart tại `pc+4`.

Không cần invalidate PHT/BTB để đạt correctness vì predictor không chứa instruction bytes; implementation được phép invalidate predictor state như một policy đơn giản, nhưng không bắt buộc.

---

## 17. Exception datapath

### 17.1 Exception metadata type

```systemverilog
typedef struct packed {
    logic        valid;
    logic [4:0]  cause;
    logic [31:0] tval;
    logic [31:0] pc;
} exception_t;
```

### 17.2 Detection stage

| Exception | Detection stage |
|---|---|
| Instruction address misaligned from internal redirect | EX hoặc commit redirect validation |
| Instruction access fault | IF response |
| Illegal instruction/illegal CSR access | ID |
| EBREAK/ECALL | ID decode, carried to commit |
| Branch/JAL/JALR target misaligned | EX |
| Load/store address misaligned | EX |
| Load/store access fault | MEM response |

### 17.3 Exception propagation

- Khi exception metadata đã valid, instruction tiếp tục đi tới WB như một trap packet.
- Side-effect controls bị mask.
- Exception cũ hơn không bị exception trẻ hơn ghi đè.
- Trap redirect chỉ xảy ra tại WB để bảo đảm precise state.

### 17.4 Avoiding double classification

- Fetch-fault packet không được decode thành illegal instruction.
- Misaligned load/store không phát request, nên không đồng thời nhận access fault.
- Bus error chỉ được xét nếu request hợp lệ đã handshake.
- ECALL/EBREAK không thực hiện CSR/GPR/memory operation khác.

---

## 18. CSR, counters và privileged operations

### 18.1 CSR read/modify/write path

- CSR address legality và access intent decode tại ID.
- CSR old value được đọc tại EX.
- Candidate new value được tính tại EX.
- Old value dùng làm GPR writeback result.
- CSR new value chỉ write tại commit nếu instruction không trap.

### 18.2 CSR serialization

Từ khi CSR/system instruction vào ID/EX tới khi commit:

- Không instruction trẻ hơn được dispatch từ ID.
- Frontend có thể prefetch nhưng IF/ID không được vượt serialization barrier.
- Interrupt reevaluation xảy ra ngay sau commit CSR state update.

### 18.3 CSR write priority trong một cycle

Priority:

```text
1. Reset
2. Trap entry state update
3. MRET state update
4. Explicit CSR instruction write
5. Automatic counter increment/update
```

Khi explicit write target chính counter:

- CSR written value thắng automatic increment trong cycle đó.
- Instruction CSR vẫn được tính là retire; `minstret` behavior cho write chính `minstret` phải theo rule project được verify: explicit written value là post-state, không cộng thêm một lần trong cùng edge.

Đây là deterministic project choice cần phản ánh trong reference model.

### 18.4 Counters

- `mcycle` tăng mỗi active core clock nếu `mcountinhibit.CY=0`, trừ cycle explicit write/reset.
- `minstret` tăng cho instruction retire non-trapping nếu `IR=0`, trừ cycle explicit write `minstret/minstreth`.
- ECALL/EBREAK và mọi synchronous exception không tăng `minstret`.
- `MRET`, WFI-as-NOP, FENCE và FENCE.I tăng `minstret` khi retire hợp lệ.

### 18.5 WFI

Với `WFI_SLEEP_ENABLE=0`:

- WFI là serializing NOP hợp lệ.
- Retire và tăng `minstret`.
- Interrupt có thể được nhận tại boundary ngay sau WFI.

---

## 19. Commit, retirement và RVFI

### 19.1 Thuật ngữ

Để tránh nhầm:

- **completion packet:** instruction tới WB và được commit unit xử lý.
- **retire:** instruction hoàn thành không synchronous trap.
- **trap completion:** faulting instruction phát trace trap nhưng không tăng `minstret`.

### 19.2 Commit invariants

- Program order được giữ.
- Tối đa một completion packet/cycle.
- Killed instruction không tới commit với valid=1.
- GPR/CSR write chỉ ở commit.
- D-memory side effect được authorization khi instruction là oldest; retirement chờ response success.
- Predictor training chỉ ở commit.

### 19.3 `arch_next_pc`

Commit unit giữ register `arch_next_pc`:

- Reset bằng `RESET_VECTOR`.
- Sau retire bình thường, cập nhật bằng actual next PC của instruction.
- Dùng làm `mepc` khi interrupt được nhận giữa instructions.
- Sau trap/MRET redirect, cập nhật theo target architectural control flow phù hợp.

### 19.4 RVFI order

- `rvfi_order` là 64-bit counter riêng.
- Tăng mỗi RVFI valid completion packet, gồm cả trapped instruction theo RVFI convention.
- Không có gap và không reuse value.
- Không dùng fetch sequence number làm `rvfi_order`, vì flushed instruction sẽ tạo gap.

### 19.5 RVFI trap packet

Faulting instruction:

- `rvfi_valid=1`.
- `rvfi_trap=1`.
- không GPR/CSR/memory architectural write.
- `rvfi_pc_rdata` là faulting instruction PC.
- `rvfi_pc_wdata` theo wrapper/reference convention đã khóa trong formal adapter.

`minstret` không tăng cho packet này.

### 19.6 Interrupt trace

RVFI convention đánh dấu `rvfi_intr` trên instruction đầu tiên của trap handler. Commit unit/trap controller phải giữ một `intr_pending_for_next_retire` flag để adapter đánh dấu đúng packet, thay vì gán interrupt cho instruction vừa retire trước trap.

---

## 20. Interrupt timing

### 20.1 Sampling

Pending inputs được synchronize nếu đến từ clock domain khác ở SoC boundary. Core nhận tín hiệu đã phù hợp clock domain hoặc dùng synchronizer wrapper.

### 20.2 Eligibility

Interrupt trap được lấy khi:

- không có synchronous trap ở WB;
- instruction WB hiện tại đã commit hợp lệ hoặc pipeline đang ở boundary trống;
- không D-memory request chưa hoàn thành;
- `mstatus.MIE=1` sau mọi CSR/MRET update cùng boundary;
- pending & enable tương ứng bằng 1.

### 20.3 Priority

```text
MEIP > MSIP > MTIP
```

### 20.4 Interaction với memory instruction

- Nếu interrupt đã eligible trước khi một memory instruction được authorize, interrupt thắng và memory instruction bị kill.
- Nếu memory transaction đã được authorize/handshake khi instruction là oldest, core hoàn thành transaction rồi mới nhận interrupt.
- Memory interface/environment phải có progress guarantee phù hợp để interrupt latency hữu hạn trong hệ thống thực tế.

---

## 21. Reset and clocking strategy

### 21.1 Reset

- External reset active-low.
- Asynchronous assertion được phép.
- Synchronous deassertion qua ít nhất hai flip-flop.
- Pipeline valid, outstanding flags, CSR control state và predictor valid bits reset deterministic.
- GPR `x1–x31`, PHT counters và data payload không bắt buộc reset nếu valid bits che toàn bộ ảnh hưởng.

### 21.2 Predictor reset

- BTB valid bits reset 0.
- RAS valid/count reset 0.
- GHR reset 0.
- PHT data có thể reset weakly-not-taken hoặc không reset nếu prediction chỉ dùng khi corresponding validity policy bảo đảm deterministic. Baseline chọn reset PHT counters về `01` để simulation/formal deterministic; Physical Design review có thể thay bằng validity generation nếu reset cost quá lớn.

### 21.3 Clocking

- Một clock domain `clk` cho core v1.
- Không tạo clock bằng combinational logic.
- Stall dùng clock enable trên register, không dùng `clk & en` RTL.
- Clock gating thực tế chỉ qua recognized ICG flow/cell và phải có test bypass.

---

## 22. Physical-design-aware RTL rules

- Không reset wide datapath/register arrays nếu valid state đủ che.
- Không infer internal IMEM/DMEM arrays trong `rv32i_core`.
- Không use `#delay`, force/release hoặc unsynthesizable initial trong core RTL.
- Không combinational path trực tiếp từ memory response tới memory request tạo ready loop.
- Hạn chế high-fanout global control; pipeline kill/stall có thể register hoặc phân tầng nếu timing yêu cầu.
- Dùng enum/packed struct trong package để giảm control mismatch.
- Tách branch compare khỏi large decode mux nếu giúp timing.
- Đặt ALU, forwarding mux và branch target path là timing-critical candidates cho synthesis/STA.
- Reset synchronizer phải được constrain/false-path đúng theo methodology sau này.
- Không hardcode Sky130 cell instance trong functional RTL.

---

## 23. Expected performance behavior

### 23.1 Ideal CPI

- ALU/logic stream độc lập: tiến tới CPI≈1 sau fill.
- Back-to-back dependent ALU: CPI≈1 nhờ forwarding.
- Load-use: ít nhất một bubble cộng memory latency.
- Branch correctly predicted: không architectural bubble bắt buộc ngoài frontend latency.
- Branch mispredicted: kill IF/ID + ID/EX và restart fetch; penalty phụ thuộc imem latency.
- CSR/system serialization: pipeline trẻ hơn dừng tới commit.
- Memory op: core stall trong thời gian authorization/request/response vì một outstanding transaction.

### 23.2 Performance counters nội bộ đề xuất

Không nhất thiết ISA-visible ở v1:

- cycles.
- retired instructions.
- branch instructions.
- branch mispredictions.
- load-use stall cycles.
- frontend wait cycles.
- D-memory wait cycles.
- CSR serialization cycles.

Các counter này hỗ trợ QoR/CPI analysis nhưng không được làm critical path.

---

## 24. Safety and correctness invariants

RTL/formal phải kiểm tra tối thiểu:

1. `x0` luôn đọc zero.
2. Không ghi GPR khi `rd=0`.
3. Killed/invalid instruction không ghi GPR, CSR hoặc memory.
4. Không phát D-memory request cho misaligned/faulting pre-memory instruction.
5. Tối đa một outstanding request mỗi channel.
6. Request payload ổn định khi backpressured.
7. Mỗi accepted D-memory request nhận đúng một response trước request kế tiếp.
8. Load data không forward trước response.
9. EX/MEM forwarding thắng MEM/WB khi cả hai match cùng source.
10. Branch redirect dùng metadata của chính branch.
11. PHT update dùng prediction-time index/snapshot.
12. Wrong-path control-flow không train BPU.
13. Store/load MMIO request chỉ issue khi instruction oldest và authorized.
14. Synchronous trap thắng interrupt cùng boundary.
15. Instruction gây synchronous exception không tăng `minstret`.
16. RVFI order không gap/duplicate.
17. Fetch response stale epoch không vào IF/ID.
18. Pipeline payload không đổi trong cycle hold.
19. Không double-issue memory request khi MEM stage stall.
20. Reset làm mọi side-effect enable inactive.

---

## 25. Mapping từ known issues tới quyết định sửa

| Known issue | Quyết định microarchitecture |
|---|---|
| RTL-001 | Carry `pred_taken/pred_target/pred_next_pc` cùng branch; compare tại EX |
| RTL-002 | Carry `pht_index` và `ghr_snapshot`; train tại commit |
| RTL-003/004 | Strict typed decoder và exception metadata |
| RTL-005 | Valid bit ở mọi pipeline stage |
| RTL-006 | Ready/valid + one outstanding + backpressure |
| RTL-007 | Core tách hoàn toàn IMEM/DMEM |
| RTL-008 | CSR/trap/interrupt subsystem và commit redirect |
| RTL-018 | Reset control/valid state, không reset toàn GPR datapath |
| RTL-020 | Explicit WB/commit unit và RVFI adapter |

---

## 26. Verification obligations của Step 4

Trước khi bắt đầu full RTL integration, verification environment phải chuẩn bị kiểm tra:

- Stage valid/ready model.
- Redirect priority directed tests.
- Random memory wait states.
- Stale instruction response sau redirect.
- Load/store authorization trước interrupt.
- Back-to-back forwarding cases.
- Variable-latency load-use.
- CSR serialization và immediate interrupt after CSR/MRET.
- Branch predictor on/off architectural equivalence.
- RVFI order/trace generation.
- Reset during outstanding instruction/data transaction.

---

## 27. Open design points chuyển sang tài liệu chuyên biệt

Các quyết định cấp cao đã khóa; các chi tiết sau được hoàn thiện ở bước tiếp theo nhưng không được phá contract này:

1. Exact SystemVerilog struct definitions → `rv32i_pkg.sv` design step.
2. Boolean equations của `ready/stall/kill` → `pipeline_contract.md`.
3. Forward select encoding và all dependency tables → `hazard_and_forwarding_spec.md`.
4. Exact BTB replacement/alias behavior và RAS update table → `branch_prediction_spec.md`.
5. Exact aligned/unaligned bus-address convention → `memory_interface_spec.md`.
6. CSR bit masks/WARL coercion và full exception priority → `trap_interrupt_csr_spec.md`.
7. Formal depth/check configuration → `verification_plan.md`.

---

## 28. Exit criteria

Step 4 chỉ PASS khi:

- [x] Chốt stage ownership và instruction flow.
- [x] Chốt module hierarchy.
- [x] Chốt pipeline packet contents cấp cao.
- [x] Chốt valid/ready/hold/kill semantics.
- [x] Chốt redirect priority và kill scope.
- [x] Chốt forwarding/stall policy cấp cao.
- [x] Chốt BPU components, metadata và commit-time training.
- [x] Chốt one-outstanding instruction/data policy.
- [x] Chốt precise memory side-effect authorization.
- [x] Chốt exception propagation và commit trap model.
- [x] Chốt CSR serialization.
- [x] Chốt interrupt boundary behavior.
- [x] Chốt reset/clocking/PD-aware rules.
- [x] Tạo machine-readable module/pipeline matrices.
- [x] Static consistency checker PASS.

---

## 29. References

- RISC-V RV32I: `https://docs.riscv.org/reference/isa/v20260120/unpriv/rv32.html`
- RISC-V Zicsr: `https://docs.riscv.org/reference/isa/v20260120/unpriv/zicsr.html`
- RISC-V Zicntr: `https://docs.riscv.org/reference/isa/v20260120/unpriv/counters.html`
- RISC-V Machine-Level ISA: `https://docs.riscv.org/reference/isa/priv/machine.html`
- RVFI: `https://yosyshq.readthedocs.io/projects/riscv-formal/en/latest/rvfi.html`
