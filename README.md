# AHB AMBA — Advanced High-performance Bus Controller

**AHB (Advanced High-performance Bus)** là thành phần cốt lõi trong kiến trúc **AMBA (Advanced Microcontroller Bus Architecture)** của ARM, được thiết kế cho các hệ thống nhúng hiệu năng cao. Dự án này triển khai một **SRAM Controller** kết nối với bus AHB, bao gồm AHB Slave Interface và SRAM Core với chức năng BIST/DFT.

---

## Cấu trúc dự án

```
AHB_AMBA/
├── ahb_defines.v       # Tham số hóa: bus widths, mã trạng thái, macro tiện ích
├── sram_top.v          # Top-level: kết nối AHB slave interface và SRAM core
├── ahb_slave_if.v      # AHB Slave Interface (xử lý giao thức AHB)
├── sram_core.v         # SRAM Core (8 bank x 8Kx8)
└── README.md
```

---

## Kiến trúc hệ thống

```
          AHB Master
              │
    ┌─────────▼──────────┐
    │    sramc_top        │
    │  ┌───────────────┐  │
    │  │ ahb_slave_if  │  │  ← Xử lý giao thức AHB (HTRANS, HBURST, HSIZE...)
    │  └───────┬───────┘  │
    │          │           │
    │  ┌───────▼───────┐  │
    │  │   sram_core   │  │  ← 2 bank x 4 SRAM (8Kx8 mỗi bank)
    │  └───────────────┘  │
    └─────────────────────┘
```

---

## Tín hiệu giao tiếp

### AHB Slave Inputs

| Tín hiệu | Độ rộng | Mô tả |
|----------|---------|-------|
| `HCLK` | 1 | Bus clock |
| `HRESETn` | 1 | Active-low reset |
| `HSEL` | 1 | Slave select |
| `HWRITE` | 1 | `1` = Write, `0` = Read |
| `HREADY` | 1 | Bus ready từ master |
| `HTRANS` | [1:0] | Loại transfer (IDLE/BUSY/NONSEQ/SEQ) |
| `HBURST` | [2:0] | Kiểu burst |
| `HSIZE` | [2:0] | Kích thước transfer |
| `HADDR` | [31:0] | Địa chỉ |
| `HWDATA` | [31:0] | Dữ liệu ghi |

### AHB Slave Outputs

| Tín hiệu | Độ rộng | Mô tả |
|----------|---------|-------|
| `HREADY_RESP` | 1 | Slave sẵn sàng |
| `HRESP` | [1:0] | Mã phản hồi |
| `HRDATA` | [31:0] | Dữ liệu đọc |

### BIST / DFT

| Tín hiệu | Hướng | Mô tả |
|----------|-------|-------|
| `BIST_EN` | Input | Kích hoạt chế độ BIST |
| `DFT_EN` | Input | Kích hoạt chế độ DFT |
| `BIST_DONE` | Output | BIST hoàn tất |
| `BIST_FAIL` | [7:0] Output | Kết quả BIST từng SRAM |

---

## Mã định nghĩa (`ahb_defines.v`)

### HTRANS — Transfer Type `[1:0]`

| Macro | Giá trị | Ý nghĩa |
|-------|---------|---------|
| `HTRANS_IDLE` | `2'b00` | Không có transfer |
| `HTRANS_BUSY` | `2'b01` | Tạm dừng giữa burst |
| `HTRANS_NONSEQ` | `2'b10` | Transfer đầu tiên hoặc đơn lẻ |
| `HTRANS_SEQ` | `2'b11` | Transfer tiếp theo trong burst |

### HBURST — Burst Type `[2:0]`

| Macro | Giá trị | Ý nghĩa |
|-------|---------|---------|
| `HBURST_SINGLE` | `3'b000` | Transfer đơn |
| `HBURST_INCR` | `3'b001` | Incrementing, độ dài tùy ý |
| `HBURST_WRAP4` | `3'b010` | 4-beat wrapping |
| `HBURST_INCR4` | `3'b011` | 4-beat incrementing |
| `HBURST_WRAP8` | `3'b100` | 8-beat wrapping |
| `HBURST_INCR8` | `3'b101` | 8-beat incrementing |
| `HBURST_WRAP16` | `3'b110` | 16-beat wrapping |
| `HBURST_INCR16` | `3'b111` | 16-beat incrementing |

### HSIZE — Transfer Size `[2:0]`

| Macro | Giá trị | Kích thước |
|-------|---------|-----------|
| `HSIZE_BYTE` | `3'b000` | 8-bit |
| `HSIZE_HALFWORD` | `3'b001` | 16-bit |
| `HSIZE_WORD` | `3'b010` | 32-bit |
| `HSIZE_DWORD` | `3'b011` | 64-bit |
| `HSIZE_4WORD` | `3'b100` | 128-bit |
| `HSIZE_8WORD` | `3'b101` | 256-bit |
| `HSIZE_16WORD` | `3'b110` | 512-bit |
| `HSIZE_32WORD` | `3'b111` | 1024-bit |

### HRESP — Response Code `[1:0]`

| Macro | Giá trị | Ý nghĩa |
|-------|---------|---------|
| `HRESP_OKAY` | `2'b00` | Transfer thành công |
| `HRESP_ERROR` | `2'b01` | Lỗi transfer |
| `HRESP_RETRY` | `2'b10` | Slave chưa sẵn sàng, thử lại |
| `HRESP_SPLIT` | `2'b11` | Split transaction |

### HPROT — Protection Control `[3:0]`

| Bit | `0` | `1` |
|-----|-----|-----|
| [0] | Instruction fetch | Data access |
| [1] | User level | Privileged |
| [2] | Non-bufferable | Bufferable |
| [3] | Non-cacheable | Cacheable |

---

## Bộ nhớ SRAM

| Tham số | Giá trị |
|---------|---------|
| Số bank | 8 (2 nhóm × 4 SRAM) |
| Kích thước mỗi SRAM | 8K × 8-bit |
| Tổng dung lượng | 64 KB |
| Độ rộng địa chỉ | 13-bit (`[12:0]`) |
| Địa chỉ AHB base | `0x0000_0000` |
| Địa chỉ AHB end | `0x0000_3FFF` |
| Bit chọn bank | `HADDR[13]` |

---

## Cách sử dụng `ahb_defines.v`

```verilog
`include "ahb_defines.v"

// Kiểm tra transfer hợp lệ
if (`AHB_VALID_TRANS(htrans) && hwrite)
    state <= WRITE_STATE;

// Decode địa chỉ SRAM
assign hsel = `AHB_SRAM_SEL(haddr);

// Lấy địa chỉ nội bộ SRAM
assign sram_addr = `AHB_TO_SRAM_ADDR(haddr);

// Chọn bank
assign bank_sel = `AHB_BANK_SEL(haddr);

// Phản hồi mặc định
assign hresp = `HRESP_OKAY;
```

---

## Tham khảo

- [AMBA AHB Specification — ARM IHI0011A](https://developer.arm.com/documentation/ihi0011/a)
- [AMBA 2.0 Specification](https://developer.arm.com/documentation/ihi0011/latest)
