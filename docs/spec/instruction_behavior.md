# Instruction Behavior Specification

**Document ID:** `RV32I-INST-BEHAVIOR`  
**Version:** `0.1`  
**Status:** `BASELINE — chốt cho decoder/verification v1`  
**Depends on:** `rv32i_architecture_spec.md`  
**Target:** `rv32i_core`  
**Last updated:** `2026-07-19`

---

## 1. Mục đích và phạm vi

Tài liệu này khóa **encoding và hành vi ISA-visible của từng instruction** mà core hỗ trợ. Đây là nguồn sự thật trực tiếp cho:

- `rv32i_decoder.sv` và các enum trong `rv32i_pkg.sv`;
- directed instruction tests, constrained-random tests và formal decode checks;
- reference model/RVFI comparison;
- illegal-instruction detection;
- synthesis và gate-level regression.

Phạm vi gồm **49 encoding chức năng**: 40 RV32I base, 6 Zicsr, FENCE.I, MRET và WFI. `Zicntr` không thêm opcode mới; counter được đọc bằng các CSR instructions.

Tài liệu không định nghĩa latency hoặc pipeline stage cụ thể. Các chi tiết đó thuộc `microarchitecture_spec.md` và `pipeline_contract.md`.

---

## 2. Quy ước

| Ký hiệu | Ý nghĩa |
|---|---|
| `pc` | Địa chỉ của instruction hiện tại |
| `rd`, `rs1`, `rs2` | Integer register indices từ instruction |
| `R[x]` | Giá trị architectural của integer register `x`; `R[0]=0` |
| `sext(x)` | Sign-extension lên 32 bit |
| `zext(x)` | Zero-extension lên 32 bit |
| `mod 2^32` | Chỉ giữ 32 bit thấp, không có overflow exception |
| `addr` | Effective byte address |
| `old CSR` | Giá trị CSR trước atomic CSR operation |
| `retire` | Instruction commit theo program order và không có exception |

Mọi phép cộng địa chỉ và integer arithmetic wrap modulo `2^32`. Signed comparison dùng bù hai; unsigned comparison dùng bit pattern 32 bit không dấu.

---

## 3. Instruction formats và immediate reconstruction

```text
R-type: funct7 | rs2 | rs1 | funct3 | rd | opcode
I-type: imm[11:0]    | rs1 | funct3 | rd | opcode
S-type: imm[11:5] | rs2 | rs1 | funct3 | imm[4:0] | opcode
B-type: imm[12|10:5] | rs2 | rs1 | funct3 | imm[4:1|11] | opcode
U-type: imm[31:12] | rd | opcode
J-type: imm[20|10:1|11|19:12] | rd | opcode
```

| Immediate | Reconstruction |
|---|---|
| I | `sext(inst[31:20])` |
| S | `sext({inst[31:25], inst[11:7]})` |
| B | `sext({inst[31], inst[7], inst[30:25], inst[11:8], 1'b0})` |
| U | `{inst[31:12], 12'b0}` |
| J | `sext({inst[31], inst[19:12], inst[20], inst[30:21], 1'b0})` |
| CSR zimm | `zext(inst[19:15])` |

Bit sign của mọi immediate có sign-extension đến từ `inst[31]`. B/J offsets luôn có bit 0 bằng zero trong encoding; project vẫn kiểm tra căn chỉnh 4 byte vì `IALIGN=32`.

---

## 4. Decoder contract

### 4.1 Nguyên tắc decode

1. Decode dựa trên `opcode`, sau đó `funct3`, `funct7/funct12` khi cần.
2. Một encoding chỉ được gán đúng một internal operation.
3. `mask/match` trong bảng và CSV được kiểm tra bằng `(inst & mask) == match`.
4. Exact encodings như ECALL, EBREAK, MRET và WFI dùng mask `0xffff_ffff`.
5. Decoder phải tạo `illegal=1` cho opcode/combination không được liệt kê, ngoại trừ reserved fields của FENCE/FENCE.I được yêu cầu bỏ qua.
6. `rd=x0` không làm encoding trở thành illegal; GPR write chỉ bị discard.
7. Standard HINT encodings phải thực thi như operation hợp lệ với no architectural mutation ngoài PC/counter.

### 4.2 Illegal-instruction conditions

- Unknown/unsupported major opcode.
- Unsupported `funct3` trong JALR, branch, load, store, OP-IMM, OP hoặc SYSTEM.
- Unsupported `funct7` combination; đặc biệt shift-immediate phải đúng `0000000` hoặc `0100000`.
- Reserved/custom instruction encoding mà project chưa định nghĩa.
- CSR không tồn tại/không accessible hoặc unsuppressed write vào CSR read-only.
- Instruction thuộc extension M/A/F/D/C/B/V hoặc privilege mode không được triển khai.

Khi illegal: không ghi GPR/CSR/memory, không update BPU như một branch hợp lệ, không retire; trap cause=2 và `mtval=inst[31:0]`.

---

## 5. Complete decode matrix

Bản đầy đủ machine-readable nằm tại `config/instruction_decode_matrix.csv`. Các cột mask/match có thể được dùng để sinh decoder checks.

| Instruction | Ext. | Format | opcode | funct3 | funct7/funct12/exact | mask | match |
|---|---|---|---|---|---|---|---|
| `LUI` | RV32I | U | `0110111` | `—` | `—` | `0x0000007f` | `0x00000037` |
| `AUIPC` | RV32I | U | `0010111` | `—` | `—` | `0x0000007f` | `0x00000017` |
| `JAL` | RV32I | J | `1101111` | `—` | `—` | `0x0000007f` | `0x0000006f` |
| `JALR` | RV32I | I | `1100111` | `000` | `—` | `0x0000707f` | `0x00000067` |
| `BEQ` | RV32I | B | `1100011` | `000` | `—` | `0x0000707f` | `0x00000063` |
| `BNE` | RV32I | B | `1100011` | `001` | `—` | `0x0000707f` | `0x00001063` |
| `BLT` | RV32I | B | `1100011` | `100` | `—` | `0x0000707f` | `0x00004063` |
| `BGE` | RV32I | B | `1100011` | `101` | `—` | `0x0000707f` | `0x00005063` |
| `BLTU` | RV32I | B | `1100011` | `110` | `—` | `0x0000707f` | `0x00006063` |
| `BGEU` | RV32I | B | `1100011` | `111` | `—` | `0x0000707f` | `0x00007063` |
| `LB` | RV32I | I | `0000011` | `000` | `—` | `0x0000707f` | `0x00000003` |
| `LH` | RV32I | I | `0000011` | `001` | `—` | `0x0000707f` | `0x00001003` |
| `LW` | RV32I | I | `0000011` | `010` | `—` | `0x0000707f` | `0x00002003` |
| `LBU` | RV32I | I | `0000011` | `100` | `—` | `0x0000707f` | `0x00004003` |
| `LHU` | RV32I | I | `0000011` | `101` | `—` | `0x0000707f` | `0x00005003` |
| `SB` | RV32I | S | `0100011` | `000` | `—` | `0x0000707f` | `0x00000023` |
| `SH` | RV32I | S | `0100011` | `001` | `—` | `0x0000707f` | `0x00001023` |
| `SW` | RV32I | S | `0100011` | `010` | `—` | `0x0000707f` | `0x00002023` |
| `ADDI` | RV32I | I | `0010011` | `000` | `—` | `0x0000707f` | `0x00000013` |
| `SLTI` | RV32I | I | `0010011` | `010` | `—` | `0x0000707f` | `0x00002013` |
| `SLTIU` | RV32I | I | `0010011` | `011` | `—` | `0x0000707f` | `0x00003013` |
| `XORI` | RV32I | I | `0010011` | `100` | `—` | `0x0000707f` | `0x00004013` |
| `ORI` | RV32I | I | `0010011` | `110` | `—` | `0x0000707f` | `0x00006013` |
| `ANDI` | RV32I | I | `0010011` | `111` | `—` | `0x0000707f` | `0x00007013` |
| `SLLI` | RV32I | I-shift | `0010011` | `001` | `0000000` | `0xfe00707f` | `0x00001013` |
| `SRLI` | RV32I | I-shift | `0010011` | `101` | `0000000` | `0xfe00707f` | `0x00005013` |
| `SRAI` | RV32I | I-shift | `0010011` | `101` | `0100000` | `0xfe00707f` | `0x40005013` |
| `ADD` | RV32I | R | `0110011` | `000` | `0000000` | `0xfe00707f` | `0x00000033` |
| `SUB` | RV32I | R | `0110011` | `000` | `0100000` | `0xfe00707f` | `0x40000033` |
| `SLL` | RV32I | R | `0110011` | `001` | `0000000` | `0xfe00707f` | `0x00001033` |
| `SLT` | RV32I | R | `0110011` | `010` | `0000000` | `0xfe00707f` | `0x00002033` |
| `SLTU` | RV32I | R | `0110011` | `011` | `0000000` | `0xfe00707f` | `0x00003033` |
| `XOR` | RV32I | R | `0110011` | `100` | `0000000` | `0xfe00707f` | `0x00004033` |
| `SRL` | RV32I | R | `0110011` | `101` | `0000000` | `0xfe00707f` | `0x00005033` |
| `SRA` | RV32I | R | `0110011` | `101` | `0100000` | `0xfe00707f` | `0x40005033` |
| `OR` | RV32I | R | `0110011` | `110` | `0000000` | `0xfe00707f` | `0x00006033` |
| `AND` | RV32I | R | `0110011` | `111` | `0000000` | `0xfe00707f` | `0x00007033` |
| `FENCE` | RV32I | I/fence | `0001111` | `000` | `—` | `0x0000707f` | `0x0000000f` |
| `ECALL` | RV32I | SYSTEM | `1110011` | `—` | `0x00000073` | `0xffffffff` | `0x00000073` |
| `EBREAK` | RV32I | SYSTEM | `1110011` | `—` | `0x00100073` | `0xffffffff` | `0x00100073` |
| `CSRRW` | Zicsr | CSR | `1110011` | `001` | `—` | `0x0000707f` | `0x00001073` |
| `CSRRS` | Zicsr | CSR | `1110011` | `010` | `—` | `0x0000707f` | `0x00002073` |
| `CSRRC` | Zicsr | CSR | `1110011` | `011` | `—` | `0x0000707f` | `0x00003073` |
| `CSRRWI` | Zicsr | CSR | `1110011` | `101` | `—` | `0x0000707f` | `0x00005073` |
| `CSRRSI` | Zicsr | CSR | `1110011` | `110` | `—` | `0x0000707f` | `0x00006073` |
| `CSRRCI` | Zicsr | CSR | `1110011` | `111` | `—` | `0x0000707f` | `0x00007073` |
| `FENCE.I` | Zifencei | I/fence | `0001111` | `001` | `—` | `0x0000707f` | `0x0000100f` |
| `MRET` | Machine | SYSTEM | `1110011` | `—` | `0x30200073` | `0xffffffff` | `0x30200073` |
| `WFI` | Machine | SYSTEM | `1110011` | `—` | `0x10500073` | `0xffffffff` | `0x10500073` |

---

## 6. Upper-immediate instructions

| Instruction | Result | Writeback | Exceptions |
|---|---|---|---|
| `LUI` | U | rd ← U | Illegal encoding/access only |
| `AUIPC` | pc + U (mod 2^32) | rd ← pc + U | Illegal encoding/access only |

- `LUI` không cộng PC; chỉ nạp U-immediate.
- `AUIPC` dùng PC của chính instruction, không dùng predicted/next PC.
- `rd=x0` là legal; kết quả bị discard.

---

## 7. Integer arithmetic, logic và shift

| Instruction | Source | Operation | Writeback |
|---|---|---|---|
| `ADDI` | rd, rs1, imm12 | `rs1 + I (mod 2^32)` | rd ← result |
| `SLTI` | rd, rs1, imm12 | `signed(rs1) < signed(I) ? 1 : 0` | rd ← result |
| `SLTIU` | rd, rs1, imm12 | `unsigned(rs1) < unsigned(sext(I)) ? 1 : 0` | rd ← result |
| `XORI` | rd, rs1, imm12 | `rs1 XOR I` | rd ← result |
| `ORI` | rd, rs1, imm12 | `rs1 OR I` | rd ← result |
| `ANDI` | rd, rs1, imm12 | `rs1 AND I` | rd ← result |
| `SLLI` | rd, rs1, shamt | `rs1 << shamt` | rd ← result |
| `SRLI` | rd, rs1, shamt | `unsigned(rs1) >> shamt` | rd ← result |
| `SRAI` | rd, rs1, shamt | `signed(rs1) >>> shamt` | rd ← result |
| `ADD` | rd, rs1, rs2 | `rs1 + rs2 (mod 2^32)` | rd ← result |
| `SUB` | rd, rs1, rs2 | `rs1 - rs2 (mod 2^32)` | rd ← result |
| `SLL` | rd, rs1, rs2 | `rs1 << rs2[4:0]` | rd ← result |
| `SLT` | rd, rs1, rs2 | `signed(rs1) < signed(rs2) ? 1 : 0` | rd ← result |
| `SLTU` | rd, rs1, rs2 | `unsigned(rs1) < unsigned(rs2) ? 1 : 0` | rd ← result |
| `XOR` | rd, rs1, rs2 | `rs1 XOR rs2` | rd ← result |
| `SRL` | rd, rs1, rs2 | `unsigned(rs1) >> rs2[4:0]` | rd ← result |
| `SRA` | rd, rs1, rs2 | `signed(rs1) >>> rs2[4:0]` | rd ← result |
| `OR` | rd, rs1, rs2 | `rs1 OR rs2` | rd ← result |
| `AND` | rd, rs1, rs2 | `rs1 AND rs2` | rd ← result |

### 7.1 Critical corner cases

- ADD/ADDI/SUB overflow bị bỏ qua; không tạo exception.
- `SLTIU` sign-extend I-immediate trước, sau đó so sánh bit pattern đó như unsigned 32 bit.
- Register shifts chỉ dùng `R[rs2][4:0]`; immediate shifts dùng `inst[24:20]`.
- Arithmetic right shift phải dùng signed operand; logical right shift phải zero-fill.
- `ADDI x0,x0,0` là canonical NOP.

---

## 8. Control-transfer instructions

| Instruction | Condition/target | Next PC | GPR write | Trap |
|---|---|---|---|---|
| `JAL` | target = pc + J | target | rd ← pc + 4 | Instruction-address-misaligned if target[1:0] ≠ 00 |
| `JALR` | tmp = rs1 + I; target = {tmp[31:1],1'b0} | target | rd ← pc + 4 | Instruction-address-misaligned if target[1:0] ≠ 00 |
| `BEQ` | taken = (rs1 == rs2); target = pc + B | taken ? target : pc + 4 | — | Instruction-address-misaligned only when taken and target[1:0] ≠ 00 |
| `BNE` | taken = (rs1 != rs2); target = pc + B | taken ? target : pc + 4 | — | Instruction-address-misaligned only when taken and target[1:0] ≠ 00 |
| `BLT` | taken = (signed(rs1) < signed(rs2)); target = pc + B | taken ? target : pc + 4 | — | Instruction-address-misaligned only when taken and target[1:0] ≠ 00 |
| `BGE` | taken = (signed(rs1) >= signed(rs2)); target = pc + B | taken ? target : pc + 4 | — | Instruction-address-misaligned only when taken and target[1:0] ≠ 00 |
| `BLTU` | taken = (unsigned(rs1) < unsigned(rs2)); target = pc + B | taken ? target : pc + 4 | — | Instruction-address-misaligned only when taken and target[1:0] ≠ 00 |
| `BGEU` | taken = (unsigned(rs1) >= unsigned(rs2)); target = pc + B | taken ? target : pc + 4 | — | Instruction-address-misaligned only when taken and target[1:0] ≠ 00 |

### 8.1 Precise control-flow behavior

- JAL/JALR link value là `pc+4` và chỉ ghi nếu instruction không trap.
- JALR luôn clear temporary bit 0 trước khi kiểm tra IALIGN.
- Taken branch/jump target không căn chỉnh 4 byte tạo exception trên chính control-transfer instruction.
- Branch not taken không tạo target-misalignment exception.
- Prediction chỉ là speculative metadata; actual condition/target trong bảng là architectural source of truth.
- Mispredicted/wrong-path instructions bị kill và không được gây store, CSR write, exception hoặc retirement.

---

## 9. Load behavior

| Instruction | Size | Lane selection | Extension | Writeback | Alignment |
|---|---:|---|---|---|---|
| `LB` | 8 | `(rdata >> (8*addr[1:0]))[7:0]` | Sign | `rd ← sext(byte)` | Always |
| `LBU` | 8 | `(rdata >> (8*addr[1:0]))[7:0]` | Zero | `rd ← zext(byte)` | Always |
| `LH` | 16 | `(rdata >> (16*addr[1]))[15:0]` | Sign | `rd ← sext(half)` | `addr[0]=0` |
| `LHU` | 16 | `(rdata >> (16*addr[1]))[15:0]` | Zero | `rd ← zext(half)` | `addr[0]=0` |
| `LW` | 32 | Entire returned word | None | `rd ← rdata` | `addr[1:0]=00` |

Rules:

- Effective address: `addr = R[rs1] + sext(I)`, modulo `2^32`.
- Alignment is checked before issuing a memory request.
- Misaligned load: cause 4, `mtval=addr`, no request and no rd write.
- Error response: cause 5, `mtval=addr`, no rd write.
- Load to `x0` still performs the transaction and all MMIO side effects, then discards writeback.
- Load retires only after a successful response.

---

## 10. Store behavior and byte lanes

Effective address is `addr = R[rs1] + sext(S)`. The project drives deterministic zero-filled aligned write data:

| Instruction | addr[1:0] | `wstrb` | `wdata` |
|---|---|---|---|
| `SB` | `00` | `0001` | `{24'b0, R[rs2][7:0]}` |
| `SB` | `01` | `0010` | `{16'b0, R[rs2][7:0], 8'b0}` |
| `SB` | `10` | `0100` | `{8'b0, R[rs2][7:0], 16'b0}` |
| `SB` | `11` | `1000` | `{R[rs2][7:0], 24'b0}` |
| `SH` | `00` | `0011` | `{16'b0, R[rs2][15:0]}` |
| `SH` | `10` | `1100` | `{R[rs2][15:0], 16'b0}` |
| `SW` | `00` | `1111` | `R[rs2]` |

- `SH` with `addr[0]=1` traps; `SW` with any nonzero `addr[1:0]` traps.
- Misaligned store: cause 6, `mtval=addr`, no request, no partial write.
- Error response: cause 7, `mtval=addr`.
- A store request must not be exposed speculatively before all older branch/trap conditions are resolved according to the commit contract.
- Store retires only when the transaction satisfies the project memory completion rule.

---

## 11. FENCE and FENCE.I

### 11.1 FENCE

- `funct3=000`, opcode `0001111`.
- `fm`, predecessor and successor sets are decoded, but RTL v1 may implement every legal/reserved configuration as a conservative full serialization point.
- `rs1` and `rd` are ignored; nonzero values are not illegal.
- Reserved `fm/pred/succ` configurations are treated as FENCE, not illegal.
- Before retirement, older ordered transactions must be drained; younger ordered memory operations cannot pass it.
- `FENCE.TSO` encoding is accepted and conservatively behaves as a full FENCE.

### 11.2 FENCE.I

- `funct3=001`, opcode `0001111`.
- Reserved funct12/rs1/rd fields are ignored for forward compatibility.
- Wait for prior stores required by the memory interface; invalidate/epoch-kill stale instruction responses; flush fetch buffer and younger frontend state; resume at `pc+4`.
- On an uncached coherent memory model, no physical I-cache invalidation is required, but pipeline/fetch restart remains required.

---

## 12. ECALL, EBREAK, MRET and WFI

| Instruction | Exact encoding | Architectural behavior | Retirement |
|---|---|---|---|
| `ECALL` | `0x00000073` | Raise environment-call-from-M-mode exception | No; trap entry occurs |
| `EBREAK` | `0x00100073` | Raise breakpoint exception | No; trap entry occurs |
| `MRET` | `0x30200073` | pc←mepc; MIE←MPIE; MPIE←1; MPP remains/coerces to M | Yes when completed |
| `WFI` | `0x10500073` | Architectural hint; project RTL v1 may retire as NOP | Yes when completed |

- ECALL cause is 11 because this implementation executes only M-mode.
- EBREAK cause is 3.
- MRET restores MIE from MPIE, sets MPIE=1, redirects to aligned `mepc`, and kills younger instructions.
- WFI is a legal architectural hint. RTL v1 may implement it as a retiring NOP; a later low-power implementation may wait without changing software-visible correctness.

---

## 13. CSR instruction behavior

All CSR operations are atomic with respect to instruction retirement.

| Instruction | CSR read? | CSR write? | New CSR value | `rd` |
|---|---|---|---|---|
| `CSRRW` | Unless `rd=x0` | Always | `R[rs1]` | old CSR unless x0 |
| `CSRRS` | Yes | Only if `rs1≠x0` | `old OR R[rs1]` | old CSR unless x0 |
| `CSRRC` | Yes | Only if `rs1≠x0` | `old AND NOT R[rs1]` | old CSR unless x0 |
| `CSRRWI` | Unless `rd=x0` | Always | `zext(zimm)` | old CSR unless x0 |
| `CSRRSI` | Yes | Only if `zimm≠0` | `old OR zimm` | old CSR unless x0 |
| `CSRRCI` | Yes | Only if `zimm≠0` | `old AND NOT zimm` | old CSR unless x0 |

### 13.1 Read-only CSR rules

- Pure read forms are legal: CSRRS/CSRRC with `rs1=x0`, CSRRSI/CSRRCI with `zimm=0`.
- CSRRW/CSRRWI always attempt a write and therefore trap on read-only CSRs, even when `rd=x0`.
- CSRRS/CSRRC with a nonzero source and CSRRSI/CSRRCI with nonzero zimm trap on read-only CSRs.
- If access is illegal, neither `rd` nor the CSR changes; cause=2 and `mtval=instruction bits`.

### 13.2 Counter reads

- `cycle/cycleh`, `time/timeh`, `instret/instreth` are read-only CSR aliases accessed through CSR instructions.
- RV32 software must use a high-low-high sequence when it requires an atomic 64-bit snapshot and the counter can change between reads.
- Machine counter CSRs `mcycle/mcycleh/minstret/minstreth` are writable per project CSR specification.

---

## 14. HINT and pseudo-instruction policy

- Pseudoinstructions are assembler aliases and do not add decoder entries. Examples: `NOP=ADDI x0,x0,0`, `MV=ADDI rd,rs,0`, `J=JAL x0,offset`, `RET=JALR x0,0(x1)`.
- Legal RV32I HINT code points do not trap and need not affect microarchitecture.
- The semihosting marker shifts `SLLI x0,x0,31` and `SRAI x0,x0,7` remain legal HINTs; the core does not implement semihosting interception in hardware.
- `rd=x0` never suppresses non-GPR side effects of loads, stores, fences, traps or control transfer.

---

## 15. Decoder output contract for RTL

The decoder should produce explicit fields rather than a single ad-hoc control vector:

```systemverilog
typedef struct packed {
    logic        legal;
    logic        uses_rs1;
    logic        uses_rs2;
    logic        writes_rd;
    logic        is_branch;
    logic        is_jump;
    logic        is_load;
    logic        is_store;
    logic        is_fence;
    logic        is_fence_i;
    logic        is_csr;
    logic        is_system;
    logic        serializing;
    alu_op_e     alu_op;
    imm_type_e   imm_type;
    branch_op_e  branch_op;
    mem_size_e   mem_size;
    wb_sel_e     wb_sel;
    csr_op_e     csr_op;
} decode_ctrl_t;
```

`writes_rd` may be asserted for an instruction class even when encoded `rd=x0`; the register-file write enable at commit must additionally require `rd!=0`. `uses_rs1/uses_rs2` must reflect real dependencies to prevent false hazards.

---

## 16. Verification obligations

### 16.1 Per-instruction minimum tests

- Nominal positive and negative operands.
- `rd=x0`, `rs1=x0`, `rs2=x0` as applicable.
- Immediate extrema and sign-extension boundaries.
- Arithmetic wraparound.
- Shift amounts 0 and 31; register shift source with high bits set.
- Signed/unsigned compare discriminator vectors.
- Taken/not-taken branch, forward/backward offset and misaligned taken target.
- All load/store byte lanes, sign extension, alignment and error response.
- CSR write-suppression and read-only-access matrix.
- Illegal opcode/funct combinations and unsupported extension encodings.

### 16.2 Global assertions

```text
x0 always reads zero
illegal instruction has no architectural side effect
killed instruction never retires
trapping instruction never writes rd/CSR/memory
misaligned store never asserts a write request
load to x0 still generates required memory transaction
branch predictor enable does not change retirement trace
retirement order is strictly increasing
```

---

## 17. Exit criteria

This document is PASS when:

- exactly 40 RV32I rows and 49 total supported instruction rows exist;
- every row has a unique or intentionally overlapping mask/match interpretation;
- all load/store lane and trap behavior are defined;
- CSR write-suppression and read-only behavior are unambiguous;
- reserved FENCE/FENCE.I fields are not incorrectly trapped;
- the architecture spec, CSV matrix and this document agree;
- the automated spec checker passes.

**Status:** `PASS — ready for Microarchitecture Specification`

