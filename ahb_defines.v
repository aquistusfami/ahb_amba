// =============================================================================
// File    : ahb_defines.v
// Brief   : AHB AMBA bus width parameters & status code definitions
// Standard: AMBA AHB (ARM IHI0011A)
// =============================================================================

`ifndef AHB_DEFINES_V
`define AHB_DEFINES_V

// -----------------------------------------------------------------------------
// Bus Width Parameters
// -----------------------------------------------------------------------------
`define AHB_ADDR_WIDTH      32
`define AHB_ADDR_MSB        31
`define AHB_DATA_WIDTH      32
`define AHB_DATA_MSB        31
`define AHB_DATA_BYTES      4
`define AHB_RESP_WIDTH      2
`define AHB_TRANS_WIDTH     2
`define AHB_BURST_WIDTH     3
`define AHB_SIZE_WIDTH      3
`define AHB_PROT_WIDTH      4
`define AHB_MASTER_WIDTH    4
`define AHB_SPLIT_WIDTH     16

// Internal SRAM: 8K x 8, depth = 2^13
`define SRAM_ADDR_WIDTH     13
`define SRAM_DATA_WIDTH     8
`define SRAM_DEPTH          8192
`define SRAM_BANK_NUM       8

// -----------------------------------------------------------------------------
// HTRANS — Transfer Type  [1:0]
// -----------------------------------------------------------------------------
`define HTRANS_IDLE         2'b00   // No transfer
`define HTRANS_BUSY         2'b01   // Busy (mid-burst pause)
`define HTRANS_NONSEQ       2'b10   // Single or first-of-burst
`define HTRANS_SEQ          2'b11   // Subsequent burst beat

// -----------------------------------------------------------------------------
// HBURST — Burst Type  [2:0]
// -----------------------------------------------------------------------------
`define HBURST_SINGLE       3'b000  // Single transfer
`define HBURST_INCR         3'b001  // Incrementing, undefined length
`define HBURST_WRAP4        3'b010  // 4-beat wrapping
`define HBURST_INCR4        3'b011  // 4-beat incrementing
`define HBURST_WRAP8        3'b100  // 8-beat wrapping
`define HBURST_INCR8        3'b101  // 8-beat incrementing
`define HBURST_WRAP16       3'b110  // 16-beat wrapping
`define HBURST_INCR16       3'b111  // 16-beat incrementing

// -----------------------------------------------------------------------------
// HSIZE — Transfer Size  [2:0]
// -----------------------------------------------------------------------------
`define HSIZE_BYTE          3'b000  //   8-bit
`define HSIZE_HALFWORD      3'b001  //  16-bit
`define HSIZE_WORD          3'b010  //  32-bit
`define HSIZE_DWORD         3'b011  //  64-bit
`define HSIZE_4WORD         3'b100  // 128-bit
`define HSIZE_8WORD         3'b101  // 256-bit
`define HSIZE_16WORD        3'b110  // 512-bit
`define HSIZE_32WORD        3'b111  // 1024-bit

// -----------------------------------------------------------------------------
// HRESP — Response Status Codes  [1:0]
// -----------------------------------------------------------------------------
`define HRESP_OKAY          2'b00   // Transfer successful
`define HRESP_ERROR         2'b01   // Transfer error
`define HRESP_RETRY         2'b10   // Slave not ready, retry later
`define HRESP_SPLIT         2'b11   // Split transaction

`define RESP_OK             `HRESP_OKAY
`define RESP_ERR            `HRESP_ERROR
`define RESP_RETRY          `HRESP_RETRY
`define RESP_SPLIT          `HRESP_SPLIT

// -----------------------------------------------------------------------------
// HPROT — Protection Control  [3:0]
// Bit[0]: 0=opcode  1=data
// Bit[1]: 0=user    1=privileged
// Bit[2]: 0=non-buf 1=bufferable
// Bit[3]: 0=non-cac 1=cacheable
// -----------------------------------------------------------------------------
`define HPROT_OPCODE        4'b0000
`define HPROT_DATA          4'b0001
`define HPROT_PRIVILEGED    4'b0010
`define HPROT_BUFFERABLE    4'b0100
`define HPROT_CACHEABLE     4'b1000
`define HPROT_PRIV_DATA     4'b0011  // Privileged data (common for SRAM)
`define HPROT_USER_CACHE    4'b1101  // User, bufferable, cacheable

// -----------------------------------------------------------------------------
// Address Map
// -----------------------------------------------------------------------------
`define SRAM_BASE_ADDR      32'h0000_0000
`define SRAM_END_ADDR       32'h0000_3FFF
`define SRAM_ADDR_MASK      32'hFFFF_C000
`define SRAM_BANK_BIT       13

// -----------------------------------------------------------------------------
// Reset Defaults & Feature Enables
// -----------------------------------------------------------------------------
`define AHB_MAX_WAIT        16
`define AHB_HRESP_RST       `HRESP_OKAY
`define AHB_HRDATA_RST      32'h0000_0000
`define AHB_HREADY_RST      1'b1
`define BIST_ENABLE         1'b1
`define DFT_ENABLE          1'b1

// -----------------------------------------------------------------------------
// Utility Macros
// -----------------------------------------------------------------------------
`define AHB_VALID_TRANS(htrans) \
    ((htrans == `HTRANS_NONSEQ) || (htrans == `HTRANS_SEQ))

`define AHB_SINGLE_TRANS(htrans, hburst) \
    ((htrans == `HTRANS_NONSEQ) && (hburst == `HBURST_SINGLE))

`define AHB_SRAM_SEL(haddr) \
    ((haddr & `SRAM_ADDR_MASK) == (`SRAM_BASE_ADDR & `SRAM_ADDR_MASK))

`define AHB_TO_SRAM_ADDR(haddr) \
    (haddr[`SRAM_ADDR_WIDTH-1:0])

`define AHB_BANK_SEL(haddr) \
    (haddr[`SRAM_BANK_BIT])

`endif // AHB_DEFINES_V
