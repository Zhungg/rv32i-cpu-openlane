# RV32I CPU Architectural Specification

**Document ID:** `RV32I-ARCH-SPEC`  
**Version:** `0.1`  
**Status:** `BASELINE — chốt cho RTL v1`  
**Target core:** `rv32i_core`  
**Target system wrapper:** `rv32i_soc`  
**Last updated:** `2026-07-19`

---

## 1. Mục đích

Tài liệu này định nghĩa **architectural behavior** quan sát được bởi phần mềm của CPU. Đây là hợp đồng giữa:

- ISA và phần mềm;
- RTL implementation;
- reference model;
- testbench, formal verification và RVFI-style trace;
- synthesis, gate-level simulation và Physical Design.

Tài liệu này không quy định chi tiết cách chia pipeline, cấu trúc BPU, forwarding mux, placement hay timing closure. Các nội dung đó thuộc `microarchitecture_spec.md` và các tài liệu chuyên biệt.

---

## 2. Tài liệu chuẩn áp dụng

Thiết kế tham chiếu các specification chính thức sau:

1. RISC-V Unprivileged ISA, RV32I Base Integer Instruction Set, Version 2.1.
2. `Zicsr`, Control and Status Register Instructions, Version 2.0.
3. `Zifencei`, Instruction-Fetch Fence, Version 2.0.
4. `Zicntr`, Base Counters and Timers, Version 2.0.
5. RISC-V Privileged Architecture, Machine-Level ISA, Version 1.13.
6. RISC-V Formal Interface conventions từ `riscv-formal` cho trace/verification.

Khi tài liệu dự án xung đột với specification chính thức, specification chính thức được ưu tiên, trừ khi tài liệu này ghi rõ một lựa chọn Execution Environment Interface (EEI) được RISC-V cho phép.

---

## 3. Phạm vi kiến trúc đã chốt

### 3.1 ISA và privilege

| Thuộc tính | Giá trị |
|---|---|
| Base ISA | RV32I |
| XLEN | 32 bit |
| Standard extensions | Zicsr, Zifencei, Zicntr |
| Privilege modes | Machine mode only |
| Hart count | 1 |
| Instruction width | 32 bit |
| IALIGN | 32 bit, tương đương căn chỉnh 4 byte |
| Endianness | Little-endian |
| Address width | 32 bit |
| Integer registers | 32 thanh ghi, `x0`–`x31` |
| Compressed instructions | Không hỗ trợ |
| M/A/F/D/C extensions | Không hỗ trợ |
| Virtual memory | Không hỗ trợ |
| PMP | Không hỗ trợ trong RTL v1 |
| NMI | Không hỗ trợ trong RTL v1 |

Tên cấu hình dùng trong tài liệu và toolchain:

```text
RV32I_Zicntr_Zicsr_Zifencei
```

Ví dụ compiler option:

```bash
-march=rv32i_zicntr_zicsr_zifencei -mabi=ilp32
```

Machine-mode support là privileged architecture của implementation, không được biểu diễn trực tiếp bằng chuỗi `-march`.

### 3.2 Các tính năng microarchitecture không thay đổi ISA

Các khối sau được triển khai nhưng không làm thay đổi architectural result:

- 5-stage in-order pipeline;
- forwarding và hazard detection;
- dynamic branch prediction;
- BTB, PHT, GHR và prediction metadata;
- instruction/data ready-valid interfaces;
- fetch buffer và memory transaction tracking;
- precise retirement;
- performance-event counters nội bộ;
- RVFI-style retirement trace.

Bật hoặc tắt branch predictor phải không làm thay đổi kết quả chương trình.

---

## 4. Architectural state

Architectural state gồm:

1. Program Counter `pc[31:0]`.
2. 32 general-purpose registers `x0`–`x31`.
3. Machine-mode CSR state.
4. 64-bit architectural counters.
5. Trạng thái privilege hiện tại, cố định ở Machine mode.
6. Trạng thái interrupt enable/pending nhìn thấy qua CSR.

Các pipeline register, predictor table, transaction buffer và cache-like metadata không phải architectural state.

---

## 5. Integer register file

### 5.1 Cấu trúc

- 32 thanh ghi, mỗi thanh ghi 32 bit.
- Hai cổng đọc và một cổng ghi logic.
- `x0` luôn đọc ra `0x0000_0000`.
- Mọi lần ghi `x0` bị bỏ qua.
- Các phép tính số nguyên dùng biểu diễn bù hai khi cần signed interpretation.

### 5.2 Trạng thái sau reset

- `x0 = 0`.
- Giá trị `x1`–`x31` là **UNSPECIFIED** sau reset.
- Phần mềm khởi động phải khởi tạo các register mà nó sử dụng.
- RTL không reset toàn bộ `x1`–`x31`, nhằm tránh reset fanout lớn, tăng area và routing congestion.

### 5.3 Ghi đồng thời và đọc cùng địa chỉ

Nếu WB ghi `rd` trong cùng chu kỳ mà Decode đọc cùng register, architectural value phải tương đương với việc instruction cũ đã retire trước instruction trẻ hơn. Microarchitecture có thể giải quyết bằng write-first register file, bypass WB→ID hoặc stall.

---

## 6. Program Counter và control transfer

### 6.1 Quy tắc chung

- `pc` là địa chỉ byte 32 bit.
- Instruction bình thường có next PC là `pc + 4`, modulo `2^32`.
- Mọi instruction fetch phải có `pc[1:0] == 2'b00`.
- Wrong-path instruction không được retire hoặc gây side effect kiến trúc.

### 6.2 JAL

- Target: `pc + sign_extend(J-immediate)`.
- Link value: `pc + 4`.
- Nếu target không căn chỉnh 4 byte:
  - phát sinh instruction-address-misaligned exception;
  - không ghi `rd`;
  - không commit target PC.

### 6.3 JALR

- Giá trị tạm: `rs1 + sign_extend(I-immediate)`.
- Target: `{temporary[31:1], 1'b0}`.
- Sau khi bit 0 bị xóa, target vẫn phải căn chỉnh 4 byte; với IALIGN=32, `target[1]` phải bằng 0.
- Nếu target misaligned:
  - phát sinh instruction-address-misaligned exception;
  - không ghi `rd`.

### 6.4 Conditional branch

- Branch target: `pc + sign_extend(B-immediate)`.
- Instruction-address-misaligned exception chỉ phát sinh khi branch **taken** và target không căn chỉnh 4 byte.
- Branch not-taken không phát sinh exception do target misaligned.
- So sánh signed và unsigned phải được phân biệt đúng theo instruction.

---

## 7. Instruction set bắt buộc

### 7.1 RV32I base — 40 instructions

#### Upper immediate

```text
LUI, AUIPC
```

#### Jump

```text
JAL, JALR
```

#### Conditional branch

```text
BEQ, BNE, BLT, BGE, BLTU, BGEU
```

#### Load

```text
LB, LH, LW, LBU, LHU
```

#### Store

```text
SB, SH, SW
```

#### Immediate arithmetic/logic

```text
ADDI, SLTI, SLTIU, XORI, ORI, ANDI,
SLLI, SRLI, SRAI
```

#### Register-register arithmetic/logic

```text
ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
```

#### Memory ordering và environment

```text
FENCE, ECALL, EBREAK
```

### 7.2 Zicsr — 6 instructions

```text
CSRRW, CSRRS, CSRRC,
CSRRWI, CSRRSI, CSRRCI
```

### 7.3 Zifencei

```text
FENCE.I
```

### 7.4 Machine privileged instructions

```text
MRET, WFI
```

`MRET` được triển khai đầy đủ. `WFI` được chấp nhận như một architectural hint; RTL v1 được phép thực hiện như NOP có thể retire ngay, nhưng không được làm thay đổi architectural state ngoài `pc`.

### 7.5 Unsupported instructions

Các instruction thuộc extension không được khai báo, privileged mode không được hỗ trợ, custom opcode chưa được định nghĩa hoặc reserved encoding phải phát sinh illegal-instruction exception.

---

## 8. Integer operation rules

### 8.1 Arithmetic

- ADD, ADDI, SUB và address generation dùng phép toán modulo `2^32`.
- Không có arithmetic overflow exception.
- Signed values dùng bù hai.
- `SLT/SLTI` dùng signed comparison.
- `SLTU/SLTIU` dùng unsigned comparison.

### 8.2 Shift

- Register shift amount lấy `rs2[4:0]`.
- Immediate shift amount lấy `shamt[4:0]`.
- SLL/SLLI điền zero ở LSB.
- SRL/SRLI điền zero ở MSB.
- SRA/SRAI sao chép sign bit.
- Reserved `funct7` hoặc shift-immediate encoding phải trap illegal instruction, không được âm thầm coi là SRL/SRA.

### 8.3 LUI và AUIPC

- `LUI`: ghi `{imm[31:12], 12'b0}` vào `rd`.
- `AUIPC`: ghi `pc + {imm[31:12], 12'b0}` vào `rd`.
- `pc` dùng trong AUIPC là PC của chính instruction đó.

---

## 9. Memory architecture

### 9.1 Không gian địa chỉ

- Không gian địa chỉ byte 32 bit.
- Kiến trúc nhìn thấy một không gian địa chỉ thống nhất.
- Microarchitecture dùng instruction port và data port tách biệt.
- `rv32i_soc` chịu trách nhiệm memory map, SRAM, ROM và peripheral decoding.

### 9.2 Endianness

Thiết kế là little-endian:

- byte có trọng số thấp nhất nằm ở địa chỉ thấp nhất;
- `SB` ghi `rs2[7:0]`;
- `SH` ghi `rs2[15:0]`;
- `SW` ghi toàn bộ `rs2[31:0]`.

### 9.3 Load behavior

| Instruction | Kích thước | Kết quả |
|---|---:|---|
| LB | 8 bit | Sign-extend lên 32 bit |
| LBU | 8 bit | Zero-extend lên 32 bit |
| LH | 16 bit | Sign-extend lên 32 bit |
| LHU | 16 bit | Zero-extend lên 32 bit |
| LW | 32 bit | Giá trị 32 bit |

Load có `rd = x0` vẫn phải:

- phát request memory;
- nhận response;
- tạo access fault hoặc misalignment trap nếu có;
- thực hiện mọi side effect của vùng memory-mapped I/O.

Chỉ kết quả ghi register bị bỏ qua.

### 9.4 Store behavior

| Instruction | Kích thước | Byte strobes theo `addr[1:0]` |
|---|---:|---|
| SB | 8 bit | Một bit trong `0001`, `0010`, `0100`, `1000` |
| SH | 16 bit | `0011` tại offset 0 hoặc `1100` tại offset 2 |
| SW | 32 bit | `1111` tại offset 0 |

Store chỉ được phát ra khi instruction còn valid và chắc chắn không thuộc wrong path.

### 9.5 Alignment policy của project

Execution Environment Interface của project chọn:

- `LB/LBU/SB`: luôn naturally aligned.
- `LH/LHU/SH`: địa chỉ phải chia hết cho 2.
- `LW/SW`: địa chỉ phải chia hết cho 4.
- Misaligned load/store luôn tạo contained trap.
- RTL v1 không chia một misaligned access thành nhiều bus transactions.
- Store misaligned không được tạo partial write.
- Load misaligned không được ghi `rd`.

### 9.6 Access faults

Memory interface có error response:

- instruction response error → instruction access fault;
- load response error → load access fault;
- store response error → store/AMO access fault.

Không có AMO trong ISA, nhưng mã cause chuẩn vẫn mang tên `store/AMO access fault`.

---

## 10. Memory ordering

### 10.1 FENCE

`FENCE` được triển khai như một serialization point:

1. không nhận memory operation trẻ hơn;
2. chờ instruction/data transactions cũ hoàn thành;
3. chờ store side effect trước đó được xác nhận;
4. sau đó cho phép instruction tiếp theo tiếp tục.

Với single-hart, in-order core không có cache hoặc store buffer, hành vi này có thể tương đương NOP về kết quả, nhưng implementation vẫn phải bảo đảm không còn outstanding transaction vượt qua FENCE.

Các trường `fm`, `pred`, `succ`, `rs1` và `rd` được decode hợp lệ theo RV32I. Reserved FENCE encoding phải xử lý theo specification.

### 10.2 FENCE.I

`FENCE.I` thực hiện tối thiểu:

1. chờ mọi data-store trước đó hoàn thành;
2. hủy instruction-fetch request cũ nếu thuộc epoch trước;
3. flush fetch buffer và pipeline instruction trẻ hơn;
4. invalidate BPU/BTB entry nếu implementation cần để tránh stale target metadata;
5. restart fetch tại `pc + 4`.

Core không quảng cáo coherency đa hart.

---

## 11. HINT, reserved và illegal encodings

- Standard HINT không thay đổi architectural state ngoài việc retire và tăng `pc`.
- HINT không được trap chỉ vì destination là `x0`.
- Không được tổng quát hóa rằng mọi instruction có `rd=x0` là NOP.
- Load tới `x0`, JAL/JALR với `rd=x0`, branch, FENCE, ECALL và EBREAK vẫn phải thực hiện semantics tương ứng.
- Reserved encoding, unsupported extension và CSR access không hợp lệ tạo illegal-instruction exception.
- `mtval` của illegal instruction chứa instruction bits khi implementation có đủ thông tin; project yêu cầu lưu toàn bộ instruction 32 bit.

---

## 12. Precise retirement

### 12.1 Nguyên tắc

CPU là in-order và precise:

- instruction retire theo program order;
- tối đa một instruction retire mỗi chu kỳ trong RTL v1;
- instruction bị flush/kill không retire;
- instruction gây synchronous exception không retire;
- register, CSR và memory side effect chỉ xảy ra nếu instruction được commit hợp lệ;
- interrupt được nhận tại instruction boundary.

### 12.2 Store retirement

Store được xem là retire khi:

- instruction không bị exception;
- address và alignment hợp lệ;
- bus đã chấp nhận transaction;
- response không báo error theo memory protocol đã chốt.

Không được phát store speculative trước khi branch/trap cũ hơn được giải quyết.

### 12.3 Counter behavior

- `mcycle` tăng mỗi core clock khi không reset và không bị inhibit.
- `minstret` tăng với mỗi instruction retire thành công.
- Instruction gây exception không tăng `minstret`.
- Interrupt tự nó không tăng `minstret`.
- `WFI` nếu được xử lý như NOP và retire thì tăng `minstret`.
- Counters wrap modulo `2^64`.

---

## 13. Trap và exception model

### 13.1 Precise trap

Khi trap xảy ra:

1. instruction cũ hơn được phép retire;
2. instruction gây synchronous exception không retire;
3. instruction trẻ hơn bị kill;
4. không có wrong-path architectural side effect;
5. trap state được ghi atomically;
6. fetch redirect tới `mtvec`.

### 13.2 Synchronous exception causes

| Cause | `mcause` code | `mepc` | `mtval` |
|---|---:|---|---|
| Instruction address misaligned | 0 | PC của branch/jump gây lỗi | Target misaligned |
| Instruction access fault | 1 | PC instruction fetch lỗi | Faulting address |
| Illegal instruction | 2 | PC instruction lỗi | Instruction bits |
| Breakpoint | 3 | PC của EBREAK | 0 |
| Load address misaligned | 4 | PC của load | Effective address |
| Load access fault | 5 | PC của load | Effective address |
| Store/AMO address misaligned | 6 | PC của store | Effective address |
| Store/AMO access fault | 7 | PC của store | Effective address |
| Environment call from M-mode | 11 | PC của ECALL | 0 |

### 13.3 ECALL và EBREAK

- `ECALL` trong project luôn xuất phát từ M-mode và tạo cause 11.
- `EBREAK` tạo breakpoint exception cause 3.
- Không instruction nào ghi register hoặc memory khi ECALL/EBREAK trap.

### 13.4 Exception priority

Nếu một instruction có nhiều điều kiện lỗi, RTL phải chọn một cause duy nhất theo priority được khóa trong `trap_interrupt_csr_spec.md`.

Nguyên tắc cấp cao:

1. instruction fetch/address faults trước khi instruction được thực thi;
2. illegal decode trước execute side effect;
3. control-target misalignment tại control transfer;
4. load/store address misalignment trước memory request;
5. bus access fault sau response;
6. synchronous exception ưu tiên hơn interrupt tại cùng retirement boundary.

---

## 14. Machine-mode privileged architecture

### 14.1 Privilege

- Reset vào Machine mode.
- Không có User mode hoặc Supervisor mode.
- Không có delegation CSR.
- `MPP` chỉ hỗ trợ giá trị Machine.
- `MRET` luôn trở về Machine mode.

### 14.2 Trap entry

Khi trap vào M-mode:

- `mepc` nhận PC precise của instruction bị trap hoặc PC tiếp theo chưa retire đối với interrupt;
- `mcause` nhận interrupt flag và cause code;
- `mtval` nhận trap value;
- `mstatus.MPIE ← mstatus.MIE`;
- `mstatus.MIE ← 0`;
- `mstatus.MPP ← M`;
- `pc` nhận trap-vector target.

### 14.3 MRET

`MRET`:

- `pc ← mepc`;
- `mstatus.MIE ← mstatus.MPIE`;
- `mstatus.MPIE ← 1`;
- privilege mode vẫn là M;
- instruction trẻ hơn MRET trong pipeline bị flush khi redirect.

`mepc` là WARL và luôn đọc với `mepc[1:0] = 2'b00`; software write vào hai bit thấp bị mask. Vì vậy MRET luôn redirect tới địa chỉ căn chỉnh 4 byte.

### 14.4 mtvec

Hỗ trợ hai mode:

| MODE | Hành vi |
|---:|---|
| 0 | Direct: mọi trap tới BASE |
| 1 | Vectored: exception tới BASE, interrupt tới `BASE + 4 × cause` |

Các MODE khác đọc lại thành 0 hoặc bị coercion về Direct theo WARL behavior.

`BASE[1:0] = 0`. Phần căn chỉnh bổ sung cho vectored mode sẽ được khóa trong CSR spec.

---

## 15. Interrupt architecture

### 15.1 Interrupt sources

Core có ba input pending source:

```text
irq_software_i  → MSIP, cause 3
irq_timer_i     → MTIP, cause 7
irq_external_i  → MEIP, cause 11
```

### 15.2 Enable conditions

Interrupt được nhận khi:

- `mstatus.MIE = 1`;
- bit pending tương ứng trong `mip` bằng 1;
- bit enable tương ứng trong `mie` bằng 1;
- không có synchronous exception ưu tiên cao hơn;
- core đang ở retirement boundary an toàn.

### 15.3 Priority

Priority mặc định của project:

```text
Machine External > Machine Software > Machine Timer
```

tương ứng cause:

```text
11 > 3 > 7
```

Priority này chỉ chọn giữa các interrupt đồng thời pending; nó không thay đổi giá trị cause.

### 15.4 Interrupt precision

- Instruction đang retire hoàn thành trước khi interrupt trap được ghi nhận.
- `mepc` trỏ tới instruction tiếp theo chưa retire.
- Instruction trẻ hơn bị kill.
- Interrupt pending có thể vẫn giữ mức sau khi trap; software/platform phải clear nguồn tương ứng.

---

## 16. CSR architecture

### 16.1 CSR instruction semantics

CSR instruction là atomic read-modify-write.

- `CSRRW/CSRRWI` với `rd=x0`: không đọc CSR, nhưng vẫn ghi CSR.
- `CSRRS/CSRRC` với `rs1=x0`: đọc CSR nhưng không ghi.
- `CSRRSI/CSRRCI` với `uimm=0`: đọc CSR nhưng không ghi.
- Ghi CSR read-only hoặc truy cập CSR không tồn tại tạo illegal-instruction exception.
- Read-only access hợp lệ không được trap.
- CSR side effect chỉ xảy ra khi instruction commit và không bị kill.

### 16.2 CSR bắt buộc của project

#### Machine information

| CSR | Address | Access | Giá trị/hành vi |
|---|---:|---|---|
| `mvendorid` | `0xF11` | RO | 0 |
| `marchid` | `0xF12` | RO | Project-defined constant |
| `mimpid` | `0xF13` | RO | Version constant |
| `mhartid` | `0xF14` | RO | 0 |
| `mconfigptr` | `0xF15` | RO | 0 |

#### Machine trap setup/handling

| CSR | Address | Access |
|---|---:|---|
| `mstatus` | `0x300` | MRW/WARL |
| `misa` | `0x301` | RO constant |
| `mie` | `0x304` | MRW |
| `mtvec` | `0x305` | MRW/WARL |
| `mcountinhibit` | `0x320` | MRW |
| `mscratch` | `0x340` | MRW |
| `mepc` | `0x341` | MRW/WARL |
| `mcause` | `0x342` | MRW/WLRL |
| `mtval` | `0x343` | MRW |
| `mip` | `0x344` | RO cho external pending inputs |

#### Machine counters

| CSR | Address | Access |
|---|---:|---|
| `mcycle` | `0xB00` | MRW |
| `minstret` | `0xB02` | MRW |
| `mcycleh` | `0xB80` | MRW |
| `minstreth` | `0xB82` | MRW |

#### Zicntr read-only aliases

| CSR | Address | Nguồn |
|---|---:|---|
| `cycle` | `0xC00` | `mcycle[31:0]` |
| `time` | `0xC01` | `time_i[31:0]` |
| `instret` | `0xC02` | `minstret[31:0]` |
| `cycleh` | `0xC80` | `mcycle[63:32]` |
| `timeh` | `0xC81` | `time_i[63:32]` |
| `instreth` | `0xC82` | `minstret[63:32]` |

Core có input 64-bit `time_i` từ SoC timer. `time/timeh` là read-only.

### 16.3 misa

`misa` là read-only constant:

- `MXL = 1` cho RV32;
- bit `I = 1`;
- các bit extension single-letter khác bằng 0.

Các extension bắt đầu bằng `Z` không được biểu diễn bằng bit riêng trong `misa`.

### 16.4 mstatus subset

RTL v1 triển khai tối thiểu:

- `MIE`;
- `MPIE`;
- `MPP`, WARL chỉ nhận M;
- các bit không hỗ trợ đọc zero và bỏ qua write, trừ khi specification yêu cầu trap.

`MPRV`, `MXR`, `SUM`, FS/VS/XS và privilege-lower-mode fields đọc zero vì không có U/S mode, MMU hoặc FPU.

### 16.5 mcountinhibit

- `CY` điều khiển `mcycle`.
- `IR` điều khiển `minstret`.
- Các HPM bit không triển khai đọc zero.
- Reset: counters được phép chạy, nên `CY=0`, `IR=0`.

---

## 17. Reset architecture

### 17.1 Reset entry

Khi `rst_n` asserted:

- core không phát memory write;
- core không retire instruction;
- pipeline valid bits bị clear;
- BPU/fetch outstanding state bị invalidate;
- privilege mode = M;
- `pc = RESET_VECTOR`.

Parameters mặc định:

```text
RESET_VECTOR = 0x0000_0000
MTVEC_RESET  = 0x0000_0100
HART_ID      = 0
```

### 17.2 CSR reset values

| State | Reset value |
|---|---|
| `mstatus.MIE` | 0 |
| `mstatus.MPIE` | 0 |
| `mstatus.MPP` | M |
| `mie` | 0 |
| `mtvec` | `MTVEC_RESET`, Direct |
| `mscratch` | 0 |
| `mepc` | 0 |
| `mcause` | 0 |
| `mtval` | 0 |
| `mcycle/minstret` | 0 |
| `mcountinhibit` | 0 |

`mip` phản ánh interrupt inputs và không cần storage writable trong RTL v1.

### 17.3 Reset implementation rule

- External reset được phép assert asynchronous.
- Deassertion phải được synchronize theo `clk`.
- Datapath/register-file data không cần reset nếu không thuộc architectural reset requirement.
- Mọi control bit có thể tạo side effect phải có deterministic reset value.

---

## 18. External architectural interfaces

Chi tiết timing thuộc `memory_interface_spec.md`, nhưng core phải có các nhóm interface:

### 18.1 Clock/reset

```systemverilog
input logic clk;
input logic rst_n;
```

### 18.2 Instruction request/response

```systemverilog
imem_req_valid
imem_req_ready
imem_req_addr[31:0]

imem_rsp_valid
imem_rsp_ready
imem_rsp_data[31:0]
imem_rsp_error
```

### 18.3 Data request/response

```systemverilog
dmem_req_valid
dmem_req_ready
dmem_req_write
dmem_req_addr[31:0]
dmem_req_wdata[31:0]
dmem_req_wstrb[3:0]

dmem_rsp_valid
dmem_rsp_ready
dmem_rsp_rdata[31:0]
dmem_rsp_error
```

### 18.4 Interrupt/time

```systemverilog
irq_software_i
irq_timer_i
irq_external_i
time_i[63:0]
```

### 18.5 Retirement trace

Core xuất RVFI-style trace tối thiểu:

```systemverilog
rvfi_valid
rvfi_order
rvfi_insn
rvfi_trap
rvfi_intr
rvfi_pc_rdata
rvfi_pc_wdata
rvfi_rs1_addr
rvfi_rs1_rdata
rvfi_rs2_addr
rvfi_rs2_rdata
rvfi_rd_addr
rvfi_rd_wdata
rvfi_mem_addr
rvfi_mem_rmask
rvfi_mem_wmask
rvfi_mem_rdata
rvfi_mem_wdata
```

Trace chỉ valid khi instruction retire hoặc khi interface formal quy định report trap event.

---

## 19. Architectural invariants

Các invariant bắt buộc:

1. `x0 == 0` tại mọi thời điểm quan sát.
2. Instruction retire theo program order.
3. Instruction killed không retire.
4. Instruction killed không ghi GPR, CSR hoặc memory.
5. Store misaligned/faulting không tạo partial write.
6. Load faulting không ghi `rd`.
7. CSR faulting không thay đổi CSR hoặc `rd`.
8. Branch predictor không thay đổi architectural result.
9. Interrupt không làm mất instruction đã retire.
10. Synchronous exception không retire instruction gây lỗi.
11. Không có instruction fetch tại địa chỉ có `pc[1:0] != 0`.
12. Mọi committed PC transition phải là `pc+4`, branch/jump target, trap vector hoặc `mepc` qua MRET.
13. `minstret` chỉ tăng khi một instruction retire.
14. Một memory side effect chỉ tương ứng với một committed instruction.
15. Response thuộc fetch epoch bị hủy không được đi vào Decode.

---

## 20. Không nằm trong phạm vi RTL v1

Các tính năng sau không được quảng cáo:

- RV32M multiply/divide;
- RV32A atomics;
- floating point;
- compressed instructions;
- User/Supervisor mode;
- MMU/TLB;
- cache coherence;
- multi-hart;
- PMP/ePMP;
- NMI;
- standard RISC-V Debug Module;
- vector interrupts/AIA;
- custom instructions;
- speculative or out-of-order execution.

Việc không hỗ trợ các tính năng này không làm thiết kế thiếu RV32I base.

---

## 21. Acceptance criteria cho Architectural Specification

Tài liệu đạt `PASS` khi:

- [x] Chốt XLEN, endianness, IALIGN và register state.
- [x] Chốt toàn bộ 40 RV32I instructions.
- [x] Chốt Zicsr, Zifencei và Zicntr.
- [x] Chốt Machine-mode-only execution.
- [x] Chốt alignment và memory-fault behavior.
- [x] Chốt precise exception/interrupt model.
- [x] Chốt CSR tối thiểu và reset state.
- [x] Chốt architectural counters.
- [x] Chốt retirement invariants.
- [x] Chốt unsupported extensions.
- [x] Không phụ thuộc vào chi tiết pipeline để định nghĩa kết quả phần mềm.

---

## 22. Các quyết định được chuyển sang tài liệu kế tiếp

Các nội dung sau chưa được định nghĩa ở mức bit/chu kỳ trong tài liệu này:

1. Encoding chi tiết và expected result từng instruction  
   → `instruction_behavior.md`

2. Pipeline partition và datapath/control implementation  
   → `microarchitecture_spec.md`

3. Stall, flush, kill và valid contract  
   → `pipeline_contract.md`

4. Forwarding priority và hazard matrix  
   → `hazard_and_forwarding_spec.md`

5. Ready/valid timing, outstanding transaction và fetch epoch  
   → `memory_interface_spec.md`

6. CSR bit masks, trap priority chi tiết và interrupt timing  
   → `trap_interrupt_csr_spec.md`

7. BTB/PHT/GHR indexing, update và recovery  
   → `branch_prediction_spec.md`

8. Test coverage, assertions, formal và regression  
   → `verification_plan.md`

---


## 23. Official references

- RISC-V RV32I Base Integer ISA, Version 2.1:  
  `https://docs.riscv.org/reference/isa/v20260120/unpriv/rv32.html`
- Zicsr, Version 2.0:  
  `https://docs.riscv.org/reference/isa/v20260120/unpriv/zicsr.html`
- Zifencei, Version 2.0:  
  `https://docs.riscv.org/reference/isa/v20260120/unpriv/zifencei.html`
- Zicntr and Zihpm, Version 2.0:  
  `https://docs.riscv.org/reference/isa/v20260120/unpriv/counters.html`
- Machine-Level ISA, Version 1.13:  
  `https://docs.riscv.org/reference/isa/v20260120/priv/machine.html`
- riscv-formal RVFI documentation:  
  `https://yosyshq.readthedocs.io/projects/riscv-formal/en/latest/rvfi.html`

---

## 24. Revision history

| Version | Date | Thay đổi |
|---|---|---|
| 0.1 | 2026-07-19 | Khóa architectural baseline cho RV32I + Zicsr + Zifencei + Zicntr, Machine mode |
