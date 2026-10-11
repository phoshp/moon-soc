// ============================================================================
// File: rtl/core/moon_pkg.sv
// Description: Global types, enumerations, opcodes, and constants for Moon-SoC
//              RV64IMAFD (RV64G) 64-bit RISC-V Processor Core
// ============================================================================

`ifndef MOON_PKG_SV
`define MOON_PKG_SV

package moon_pkg;

  // --------------------------------------------------------------------------
  // Data Widths and Standard Constants
  // --------------------------------------------------------------------------
  localparam int XLEN          = 64;           // Integer register width
  localparam int FLEN          = 64;           // Floating-point register width
  localparam int ILEN          = 32;           // Instruction width
  localparam int HART_MAX      = 8;            // Maximum number of CPU harts
  localparam int CACHE_LINE_SZ = 64;           // Cache line size in bytes (512 bits)
  localparam int CACHE_LINE_BITS = CACHE_LINE_SZ * 8; // 512 bits

  // --------------------------------------------------------------------------
  // RV64 Major Opcodes (opcode[6:0])
  // --------------------------------------------------------------------------
  typedef enum logic [6:0] {
    OPCODE_LUI      = 7'b0110111,
    OPCODE_AUIPC    = 7'b0010111,
    OPCODE_JAL      = 7'b1101111,
    OPCODE_JALR     = 7'b1100111,
    OPCODE_BRANCH   = 7'b1100011,
    OPCODE_LOAD     = 7'b0000011,
    OPCODE_STORE    = 7'b0100011,
    OPCODE_OP_IMM   = 7'b0010011,  // 64-bit immediate ops (ADDI, etc.)
    OPCODE_OP       = 7'b0110011,  // 64-bit register-register (ADD, MUL, etc.)
    OPCODE_OP_IMM_32= 7'b0011011,  // 32-bit word immediate ops (ADDIW, etc.)
    OPCODE_OP_32    = 7'b0111011,  // 32-bit word register ops (ADDW, MULW, etc.)
    OPCODE_MISC_MEM = 7'b0001111,  // FENCE, FENCE.I
    OPCODE_SYSTEM   = 7'b1110011,  // ECALL, EBREAK, CSR, MRET
    OPCODE_AMO      = 7'b0101111,  // RV64A Atomic operations
    OPCODE_LOAD_FP  = 7'b0000111,  // FLW, FLD
    OPCODE_STORE_FP = 7'b0100111,  // FSW, FSD
    OPCODE_FP       = 7'b1010011,  // Floating-point operations
    OPCODE_MADD     = 7'b1000011,  // FMADD.S, FMADD.D
    OPCODE_MSUB     = 7'b1000111,  // FMSUB.S, FMSUB.D
    OPCODE_NMSUB    = 7'b1001011,  // FNMSUB.S, FNMSUB.D
    OPCODE_NMADD    = 7'b1001111   // FNMADD.S, FNMADD.D
  } opcode_e;

  // --------------------------------------------------------------------------
  // ALU Operation Codes
  // --------------------------------------------------------------------------
  typedef enum logic [4:0] {
    ALU_ADD    = 5'd0,
    ALU_SUB    = 5'd1,
    ALU_AND    = 5'd2,
    ALU_OR     = 5'd3,
    ALU_XOR    = 5'd4,
    ALU_SLL    = 5'd5,
    ALU_SRL    = 5'd6,
    ALU_SRA    = 5'd7,
    ALU_SLT    = 5'd8,
    ALU_SLTU   = 5'd9,
    // 32-bit Word Operations
    ALU_ADDW   = 5'd10,
    ALU_SUBW   = 5'd11,
    ALU_SLLW   = 5'd12,
    ALU_SRLW   = 5'd13,
    ALU_SRAW   = 5'd14,
    // Pass-throughs
    ALU_COPY_A = 5'd15,
    ALU_COPY_B = 5'd16
  } alu_op_e;

  // --------------------------------------------------------------------------
  // Multiplier / Divider Operations (RV64M)
  // --------------------------------------------------------------------------
  typedef enum logic [3:0] {
    MULDIV_NONE   = 4'd0,
    MULDIV_MUL    = 4'd1,   // 64-bit low
    MULDIV_MULH   = 4'd2,   // 64-bit high signed*signed
    MULDIV_MULHSU = 4'd3,   // 64-bit high signed*unsigned
    MULDIV_MULHU  = 4'd4,   // 64-bit high unsigned*unsigned
    MULDIV_DIV    = 4'd5,   // 64-bit signed divide
    MULDIV_DIVU   = 4'd6,   // 64-bit unsigned divide
    MULDIV_REM    = 4'd7,   // 64-bit signed remainder
    MULDIV_REMU   = 4'd8,   // 64-bit unsigned remainder
    MULDIV_MULW   = 4'd9,   // 32-bit multiply sign-extended
    MULDIV_DIVW   = 4'd10,  // 32-bit signed divide
    MULDIV_DIVUW  = 4'd11,  // 32-bit unsigned divide
    MULDIV_REMW   = 4'd12,  // 32-bit signed remainder
    MULDIV_REMUW  = 4'd13   // 32-bit unsigned remainder
  } muldiv_op_e;

  // --------------------------------------------------------------------------
  // Atomic Memory Operations (RV64A - funct5[4:0])
  // --------------------------------------------------------------------------
  typedef enum logic [4:0] {
    AMO_LR      = 5'b00010,
    AMO_SC      = 5'b00011,
    AMO_SWAP    = 5'b00001,
    AMO_ADD     = 5'b00000,
    AMO_XOR     = 5'b00100,
    AMO_AND     = 5'b01100,
    AMO_OR      = 5'b01000,
    AMO_MIN     = 5'b10000,
    AMO_MAX     = 5'b10100,
    AMO_MINU    = 5'b11000,
    AMO_MAXU    = 5'b11100
  } amo_op_e;

  // --------------------------------------------------------------------------
  // Branch Conditions (funct3[2:0])
  // --------------------------------------------------------------------------
  typedef enum logic [2:0] {
    BRANCH_BEQ  = 3'b000,
    BRANCH_BNE  = 3'b001,
    BRANCH_BLT  = 3'b100,
    BRANCH_BGE  = 3'b101,
    BRANCH_BLTU = 3'b110,
    BRANCH_BGEU = 3'b111
  } branch_type_e;

  // --------------------------------------------------------------------------
  // Memory Access Widths (funct3[2:0])
  // --------------------------------------------------------------------------
  typedef enum logic [2:0] {
    MEM_BYTE    = 3'b000,  // LB / SB
    MEM_HALF    = 3'b001,  // LH / SH
    MEM_WORD    = 3'b010,  // LW / SW
    MEM_DWORD   = 3'b011,  // LD / SD (RV64)
    MEM_BYTE_U  = 3'b100,  // LBU
    MEM_HALF_U  = 3'b101,  // LHU
    MEM_WORD_U  = 3'b110   // LWU (RV64)
  } mem_width_e;

  // --------------------------------------------------------------------------
  // Forwarding Source Selection
  // --------------------------------------------------------------------------
  typedef enum logic [1:0] {
    FWD_REG = 2'b00,  // Operand from Register File (no hazard)
    FWD_EX  = 2'b01,  // Forwarded from EX/MEM stage
    FWD_MEM = 2'b10   // Forwarded from MEM/WB stage
  } fwd_sel_e;

  // --------------------------------------------------------------------------
  // Machine Mode Control and Status Registers (CSR Addresses)
  // --------------------------------------------------------------------------
  localparam logic [11:0] CSR_MSTATUS   = 12'h300;
  localparam logic [11:0] CSR_MISA      = 12'h301;
  localparam logic [11:0] CSR_MIE       = 12'h304;
  localparam logic [11:0] CSR_MTVEC     = 12'h305;
  localparam logic [11:0] CSR_MEPC      = 12'h341;
  localparam logic [11:0] CSR_MCAUSE    = 12'h342;
  localparam logic [11:0] CSR_MTVAL     = 12'h343;
  localparam logic [11:0] CSR_MIP       = 12'h344;
  localparam logic [11:0] CSR_MHARTID   = 12'hF14;
  localparam logic [11:0] CSR_MCYCLE    = 12'hB00;
  localparam logic [11:0] CSR_MINSTRET  = 12'hB02;

  // Floating-point CSR
  localparam logic [11:0] CSR_FFLAGS    = 12'h001;
  localparam logic [11:0] CSR_FRM       = 12'h002;
  localparam logic [11:0] CSR_FCSR      = 12'h003;

  // --------------------------------------------------------------------------
  // Trap / Exception Causes (mcause[62:0], bit 63 is Interrupt bit)
  // --------------------------------------------------------------------------
  localparam logic [62:0] CAUSE_MISALIGNED_FETCH    = 63'd0;
  localparam logic [62:0] CAUSE_FETCH_ACCESS_FAULT  = 63'd1;
  localparam logic [62:0] CAUSE_ILLEGAL_INSTRUCTION = 63'd2;
  localparam logic [62:0] CAUSE_BREAKPOINT          = 63'd3;
  localparam logic [62:0] CAUSE_MISALIGNED_LOAD     = 63'd4;
  localparam logic [62:0] CAUSE_LOAD_ACCESS_FAULT   = 63'd5;
  localparam logic [62:0] CAUSE_MISALIGNED_STORE    = 63'd6;
  localparam logic [62:0] CAUSE_STORE_ACCESS_FAULT  = 63'd7;
  localparam logic [62:0] CAUSE_ECALL_U_MODE        = 63'd8;
  localparam logic [62:0] CAUSE_ECALL_M_MODE        = 63'd11;

  // Interrupt Causes
  localparam logic [62:0] INT_SOFTWARE_M            = 63'd3;
  localparam logic [62:0] INT_TIMER_M               = 63'd7;
  localparam logic [62:0] INT_EXTERNAL_M            = 63'd11;

  // --------------------------------------------------------------------------
  // Cache Coherence (MESI) State Definitions
  // --------------------------------------------------------------------------
  typedef enum logic [1:0] {
    MESI_INVALID   = 2'b00,
    MESI_SHARED    = 2'b01,
    MESI_EXCLUSIVE = 2'b10,
    MESI_MODIFIED  = 2'b11
  } mesi_state_e;

endpackage : moon_pkg

`endif // MOON_PKG_SV
