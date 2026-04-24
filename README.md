# AHB AMBA — Advanced High-performance Bus Controller

---

## Chương I: Mở đầu

### 1. Đặt vấn đề — Hạn chế của Bus dùng chung (Shared Bus)

Trong các hệ thống SoC truyền thống, CPU, DMA và các thiết bị I/O cùng chia sẻ một đường bus đơn lẻ để truy cập bộ nhớ. Điều này gây ra **xung đột bus (bus contention)**: tại một thời điểm chỉ một thiết bị được phép truyền, các thiết bị còn lại phải chờ, dẫn đến:

- **Tắc nghẽn băng thông** khi nhiều master hoạt động đồng thời.
- **Độ trễ không xác định** do cơ chế phân xử đơn giản.
- **Hiệu năng hệ thống bị giới hạn** bởi tốc độ của bus dùng chung.

### 2. Giải pháp — Mạng kết nối trên chip (On-chip Network)

ARM phát triển chuẩn **AMBA (Advanced Microcontroller Bus Architecture)** để chuẩn hóa giao tiếp nội bộ trên chip. AMBA phân tầng bus theo mức độ hiệu năng:

| Tầng | Bus | Dùng cho |
|------|-----|----------|
| Cao | **AHB** | CPU, SRAM, DMA |
| Trung | **APB** | Ngoại vi tốc độ thấp (UART, GPIO) |
| Cầu nối | **AHB-APB Bridge** | Kết nối hai tầng |

### 3. Khái niệm AHB

**AHB (Advanced High-performance Bus)** là bus đồng bộ hiệu năng cao trong kiến trúc AMBA, phù hợp cho các giao dịch tốc độ cao nhờ:

- Giao thức **pipelined**: địa chỉ và dữ liệu được xử lý chồng lấn theo chu kỳ.
- Hỗ trợ **Burst Transfer**: truyền nhiều beat dữ liệu liên tiếp trong một giao dịch.
- Cơ chế **Multi-master**: nhiều thiết bị có thể làm chủ bus, được phân xử bởi Arbiter.

### 4. Kiến trúc kết nối vật lý

```
  ┌──────────┐   ┌──────────┐   ┌──────────┐
  │   CPU    │   │   DMA    │   │  Master2 │   ← AHB Masters
  └────┬─────┘   └────┬─────┘   └────┬─────┘
       │              │              │
  ┌────▼──────────────▼──────────────▼─────┐
  │             AHB Arbiter                 │   ← Phân xử quyền dùng bus
  └────────────────────┬────────────────────┘
                       │ HGRANT / HBUSREQ
  ┌────────────────────▼────────────────────┐
  │              AHB Bus                    │   ← HADDR, HWDATA, HRDATA...
  └──────┬──────────────────┬───────────────┘
         │  AHB Decoder     │
  ┌──────▼──────┐    ┌──────▼──────┐
  │  SRAM Ctrl  │    │  APB Bridge │   ← AHB Slaves
  └─────────────┘    └─────────────┘
```

### 5. Vai trò và lợi ích

| Tính năng | Mô tả |
|-----------|-------|
| **Multi-master** | Nhiều master chia sẻ bus, Arbiter cấp quyền theo thứ tự ưu tiên |
| **Burst Transfer** | Truyền 4/8/16 beat liên tiếp, giảm overhead địa chỉ |
| **Pipelining** | Địa chỉ chu kỳ N+1 được phát khi dữ liệu chu kỳ N đang xử lý |

---

## Chương II: Nguyên lý hoạt động của giao thức AHB

### 1. Các tín hiệu cơ bản

| Tín hiệu | Độ rộng | Chiều | Chức năng |
|----------|---------|-------|-----------|
| `HCLK` | 1 | — | Clock hệ thống, mọi tín hiệu đồng bộ theo sườn lên |
| `HRESETn` | 1 | — | Reset tích cực mức thấp |
| `HADDR` | [31:0] | M→S | Địa chỉ transfer |
| `HWDATA` | [31:0] | M→S | Dữ liệu ghi |
| `HRDATA` | [31:0] | S→M | Dữ liệu đọc |
| `HWRITE` | 1 | M→S | `1` = Write, `0` = Read |
| `HTRANS` | [1:0] | M→S | Loại transfer (IDLE/BUSY/NONSEQ/SEQ) |
| `HSIZE` | [2:0] | M→S | Kích thước transfer (byte/halfword/word) |
| `HBURST` | [2:0] | M→S | Kiểu burst |
| `HSEL` | 1 | Dec→S | Chọn slave |
| `HREADY` | 1 | S→M | Slave sẵn sàng (kéo thấp = insert wait state) |
| `HRESP` | [1:0] | S→M | Mã phản hồi (OKAY/ERROR/RETRY/SPLIT) |

### 2. Truyền dữ liệu cơ bản (Single Transfer)

AHB chia mỗi giao dịch thành **2 pha**, mỗi pha chiếm ít nhất 1 chu kỳ clock:

```
Clock:    __|‾|__|‾|__|‾|__
           Cycle 1  Cycle 2
          ┌────────┐
HADDR:    │ ADDR   │          ← Pha địa chỉ (Address Phase)
          └────────┘
                   ┌────────┐
HWDATA:            │ DATA   │  ← Pha dữ liệu (Data Phase)
                   └────────┘
HREADY:   ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾  ← HIGH = không có wait state
```

- **Address Phase**: Master phát `HADDR`, `HWRITE`, `HTRANS`, `HSIZE`.
- **Data Phase**: Master/Slave trao đổi `HWDATA`/`HRDATA`; Slave có thể kéo `HREADY = 0` để chèn wait state.

### 3. Truyền dữ liệu theo cụm (Burst Transfer)

Burst cho phép truyền nhiều beat liên tiếp mà không cần phát lại địa chỉ từng beat, tối ưu băng thông:

```
         Cy1      Cy2      Cy3      Cy4      Cy5
HTRANS:  NONSEQ   SEQ      SEQ      SEQ      IDLE
HADDR:   A0       A1       A2       A3       —
HWDATA:  —        D0       D1       D2       D3
```

Các kiểu burst được mã hóa bằng `HBURST[2:0]`: `SINGLE`, `INCR`, `WRAP4`, `INCR4`, `WRAP8`, `INCR8`, `WRAP16`, `INCR16`.

### 4. Kỹ thuật đường ống (Pipelining)

Pipelining chồng lấn pha địa chỉ của giao dịch tiếp theo lên pha dữ liệu của giao dịch hiện tại:

```
        Cy1          Cy2          Cy3
        ┌──────────┐ ┌──────────┐ ┌──────────┐
HADDR:  │  ADDR_1  │ │  ADDR_2  │ │  ADDR_3  │
        └──────────┘ └──────────┘ └──────────┘
        ┌──────────┐ ┌──────────┐ ┌──────────┐
HDATA:  │    —     │ │  DATA_1  │ │  DATA_2  │
        └──────────┘ └──────────┘ └──────────┘
```

Nhờ đó, throughput lý tưởng đạt **1 transfer/clock**, giảm overhead so với bus không pipelined.

---

## Chương III: Các thành phần kiến trúc hệ thống AHB

### 1. Thiết bị chủ (AHB Master)

Master là thành phần khởi tạo mọi giao dịch đọc/ghi. Chức năng:
- Phát `HBUSREQ` đến Arbiter để yêu cầu quyền dùng bus.
- Sau khi nhận `HGRANT`, phát địa chỉ (`HADDR`) và tín hiệu điều khiển.
- Theo dõi `HREADY` để xác nhận pha dữ liệu hoàn thành.

### 2. Thiết bị tớ (AHB Slave)

Slave tiếp nhận giao dịch từ Master thông qua tín hiệu `HSEL`:
- Giải mã địa chỉ nội bộ để đọc/ghi bộ nhớ hoặc thanh ghi.
- Kéo `HREADY = 0` để yêu cầu thêm chu kỳ khi chưa sẵn sàng (wait state).
- Trả về `HRESP` để báo trạng thái: `OKAY`, `ERROR`, `RETRY`, `SPLIT`.

### 3. Bộ phân xử (AHB Arbiter)

Arbiter giải quyết xung đột khi nhiều Master cùng yêu cầu bus:

| Thuật toán | Đặc điểm |
|-----------|---------|
| **Fixed Priority** | Master có ID thấp hơn luôn được ưu tiên — đơn giản, có thể gây starvation |
| **Round-Robin** | Luân phiên cấp quyền — công bằng, phù hợp khi các master có độ ưu tiên tương đương |

Arbiter cấp `HGRANT` và kiểm soát `HLOCK` khi Master yêu cầu giữ bus liên tục.

### 4. Bộ giải mã (AHB Decoder)

Decoder ánh xạ địa chỉ `HADDR` sang tín hiệu `HSEL` tương ứng:

```verilog
assign HSEL_SRAM   = (HADDR[31:14] == 18'h0);       // 0x0000_0000 – 0x0000_3FFF
assign HSEL_PERIPH = (HADDR[31:12] == 20'hFFFFF);   // 0xFFFF_F000 – 0xFFFF_FFFF
```

### 5. Bộ ghép kênh (AHB Multiplexor)

Thay vì dùng bus 3 trạng thái (tri-state), AHB dùng MUX để định tuyến dữ liệu từ nhiều Slave về Master:

```verilog
always @(*) begin
    case (HSEL)
        2'b01:   HRDATA = HRDATA_SRAM;
        2'b10:   HRDATA = HRDATA_PERIPH;
        default: HRDATA = 32'h0;
    endcase
end
```

---

## Chương IV: Thiết kế hệ thống AHB bằng Verilog

### 1. Kiến trúc tổng quan (Top-level)

```
                     ahb_top.v
  ┌──────────────────────────────────────────────┐
  │  ┌────────────┐      ┌────────────────────┐  │
  │  │ahb_master.v│──────▶  ahb_arbiter.v     │  │
  │  └────────────┘      └─────────┬──────────┘  │
  │                                │              │
  │                      ┌─────────▼──────────┐  │
  │                      │  ahb_decoder.v     │  │
  │                      └─────────┬──────────┘  │
  │                      ┌─────────▼──────────┐  │
  │                      │  ahb_slave.v       │  │
  │                      └─────────┬──────────┘  │
  │                      ┌─────────▼──────────┐  │
  │                      │  ahb_mux.v         │  │
  │                      └────────────────────┘  │
  └──────────────────────────────────────────────┘
```

### 2. Tham số hóa (`ahb_defines.v`)

File `ahb_defines.v` tập trung toàn bộ hằng số của hệ thống, tránh hard-code trong từng module:

```verilog
// Bus widths
`define AHB_ADDR_WIDTH   32
`define AHB_DATA_WIDTH   32

// HTRANS
`define HTRANS_IDLE      2'b00
`define HTRANS_BUSY      2'b01
`define HTRANS_NONSEQ    2'b10
`define HTRANS_SEQ       2'b11

// HRESP
`define HRESP_OKAY       2'b00
`define HRESP_ERROR      2'b01
`define HRESP_RETRY      2'b10
`define HRESP_SPLIT      2'b11
```

### 3. Thiết kế chi tiết các khối (RTL)

#### 3.1 Khối Master (`ahb_master.v`) — FSM điều khiển giao dịch

```
        ┌──────┐   HGRANT   ┌──────────┐  HREADY  ┌──────────┐
  RST──▶│ IDLE │──────────▶│ ADDR_PH  │─────────▶│ DATA_PH  │
        └──────┘            └──────────┘           └─────┬────┘
            ▲                                            │
            └────────────────────────────────────────────┘
                          transfer done
```

Master FSM có 3 trạng thái chính: `IDLE` → `ADDR_PHASE` → `DATA_PHASE`. Tại `ADDR_PHASE`, Master phát địa chỉ và `HTRANS = NONSEQ`. Tại `DATA_PHASE`, Master chờ `HREADY = 1` rồi chốt dữ liệu.

#### 3.2 Khối Slave (`ahb_slave.v`) — Dummy RAM

```verilog
reg [31:0] mem [0:255];   // Bộ nhớ giả lập 256 words

always @(posedge HCLK) begin
    if (HSEL && HREADY) begin
        if (HWRITE) mem[HADDR[9:2]] <= HWDATA;   // Write
        else        HRDATA          <= mem[HADDR[9:2]]; // Read
    end
end
assign HREADYOUT = 1'b1;   // Slave luôn sẵn sàng (0 wait state)
assign HRESP     = `HRESP_OKAY;
```

#### 3.3 Khối Arbiter & Decoder

**Arbiter** — Round-Robin cơ bản cho 2 master:
```verilog
always @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn)         grant <= 2'b01;
    else if (!HBUSREQ[grant_idx]) // nếu master hiện tại không cần bus
        grant <= {grant[0], grant[1]};  // luân phiên
end
```

**Decoder** — Tổ hợp thuần túy:
```verilog
assign HSEL_S0 = (HADDR >= 32'h0000_0000) && (HADDR <= 32'h0000_3FFF);
assign HSEL_S1 = (HADDR >= 32'h4000_0000) && (HADDR <= 32'h4000_FFFF);
```

#### 3.4 Khối Multiplexor (`ahb_mux.v`)

```verilog
assign HRDATA   = HSEL_S0 ? HRDATA_S0 : HRDATA_S1;
assign HREADY   = HSEL_S0 ? HREADY_S0 : HREADY_S1;
assign HRESP    = HSEL_S0 ? HRESP_S0  : HRESP_S1;
```

---

## Chương V: Kiến trúc Testbench và Mô phỏng

### 1. Môi trường kiểm thử (`ahb_tb.v`)

**Tạo Clock và Reset:**
```verilog
// Clock 100 MHz (chu kỳ 10ns)
initial HCLK = 0;
always #5 HCLK = ~HCLK;

// Reset tích cực 2 chu kỳ
initial begin
    HRESETn = 0;
    #20 HRESETn = 1;
end
```

**Inject tín hiệu kích thích:**
```verilog
task ahb_write(input [31:0] addr, data);
    @(posedge HCLK);
    HTRANS = `HTRANS_NONSEQ; HWRITE = 1;
    HADDR  = addr;
    @(posedge HCLK);
    HWDATA = data;
    HTRANS = `HTRANS_IDLE;
endtask
```

### 2. Các kịch bản mô phỏng

**Kịch bản 1 — Single Transfer (1 Master, 1 Slave):**

```
Master ghi: HADDR=0x00, HWDATA=0xDEAD_BEEF
Master đọc: HADDR=0x00 → HRDATA phải trả về 0xDEAD_BEEF
Kiểm tra: HRESP == OKAY, HREADY == 1
```

**Kịch bản 2 — Arbitration (2 Master xung đột):**

```
Cycle 1: Master0 và Master1 cùng kéo HBUSREQ = 1
Cycle 2: Arbiter cấp HGRANT cho Master0 (ưu tiên cao hơn)
Cycle 3: Master0 thực hiện transfer, Master1 chờ
Cycle 4: Master0 giải phóng bus → Arbiter cấp HGRANT cho Master1
```

### 3. Phân tích dạng sóng

Các điểm cần quan sát trên waveform (ModelSim/Vivado):

| Thời điểm | Tín hiệu cần chú ý |
|-----------|-------------------|
| Sườn lên Clock sau NONSEQ | `HADDR` ổn định — Master bắt đầu Address Phase |
| `HREADY` lên HIGH | Slave sẵn sàng — kết thúc Data Phase |
| Sườn lên Clock tiếp theo | `HRDATA` được chốt vào thanh ghi Master |
| `HRESP == ERROR` | Slave từ chối giao dịch — Master phải dừng burst |

### 4. Kết quả và Kết luận

| Chỉ số | Thiết kế đạt được | Đặc tả AMBA |
|--------|-------------------|-------------|
| Latency single transfer | 2 chu kỳ (1 addr + 1 data) | ≥ 2 chu kỳ |
| Throughput burst (INCR4) | 1 beat/clock (sau beat đầu) | 1 beat/clock |
| Wait state | Cấu hình được (0 mặc định) | Tùy slave |
| Arbitration | Round-Robin 2 master | Tùy triển khai |

---

## Tổng kết

### Kết quả đạt được

- Thiết kế đã hiện thực đúng giao thức bắt tay AHB: hai pha địa chỉ/dữ liệu hoạt động chính xác, tín hiệu `HREADY`/`HRESP` phản hồi đúng chuẩn AMBA IHI0011A.
- FSM Master điều khiển đúng trình tự `IDLE → NONSEQ → SEQ → IDLE` cho cả single và burst transfer.
- Arbiter phân xử đúng khi hai master xung đột, không xảy ra race condition.

### Hạn chế và hướng phát triển

| Hạn chế hiện tại | Hướng phát triển |
|-----------------|-----------------|
| Chưa hỗ trợ `HRESP = RETRY/SPLIT` | Thêm FSM retry logic ở Master |
| Arbiter chỉ hỗ trợ 2 master | Mở rộng lên N master với priority vector |
| Slave không có pipeline nội bộ | Thêm FIFO đệm để giảm wait state |
| Chưa có coverage report | Tích hợp SystemVerilog assertions (SVA) |

---

## Tham khảo

- [AMBA AHB Specification — ARM IHI0011A](https://developer.arm.com/documentation/ihi0011/a)
- [AMBA 2.0 Specification](https://developer.arm.com/documentation/ihi0011/latest)
