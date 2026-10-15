// ============================================================================
// File: tb/core/tb_moon_core.sv
// Description: Standalone SystemVerilog testbench for moon_core verifying
//              RV64I, RV64M, and RV64A instruction execution.
// ============================================================================

`timescale 1ns/1ps

`include "moon_pkg.sv"
`include "moon_core.sv"

module tb_moon_core (
  input  logic clk,
  input  logic rst_n,
  output logic test_passed,
  output logic test_failed,
  output logic [31:0] test_error_code,
  output logic [63:0] debug_pc,
  output logic [31:0] debug_instr
);

  assign debug_pc    = dut.u_if_stage.pc_q;
  assign debug_instr = imem_rdata;

  import moon_pkg::*;

  // Core instruction memory interface
  logic             imem_req;
  logic [XLEN-1:0]  imem_addr;
  logic             imem_valid;
  logic [ILEN-1:0]  imem_rdata;

  // Core data memory interface
  logic             dmem_req;
  logic             dmem_we;
  logic [XLEN-1:0]  dmem_addr;
  logic [XLEN-1:0]  dmem_wdata;
  logic [7:0]       dmem_wstrb;
  logic             dmem_valid;
  logic [XLEN-1:0]  dmem_rdata;

  // Interrupt lines
  logic             timer_irq;
  logic             software_irq;
  logic             external_irq;

  assign timer_irq    = 1'b0;
  assign software_irq = 1'b0;
  assign external_irq = 1'b0;

  // --------------------------------------------------------------------------
  // Core Instantiation
  // --------------------------------------------------------------------------
  moon_core #(
    .HART_ID(0)
  ) dut (
    .clk_i          (clk),
    .rst_ni         (rst_n),
    .imem_req_o     (imem_req),
    .imem_addr_o    (imem_addr),
    .imem_valid_i   (imem_valid),
    .imem_rdata_i   (imem_rdata),
    .dmem_req_o     (dmem_req),
    .dmem_we_o      (dmem_we),
    .dmem_addr_o    (dmem_addr),
    .dmem_wdata_o   (dmem_wdata),
    .dmem_wstrb_o   (dmem_wstrb),
    .dmem_valid_i   (dmem_valid),
    .dmem_rdata_i   (dmem_rdata),
    .timer_irq_i    (timer_irq),
    .software_irq_i (software_irq),
    .external_irq_i (external_irq),
    .inv_valid_i    (1'b0),
    .inv_addr_i     ('0)
  );

  // --------------------------------------------------------------------------
  // Simulated Memory (256 KB)
  // Memory addresses: 0x0000_1000 upwards (ROM) and 0x8000_0000 upwards (RAM)
  // --------------------------------------------------------------------------
  logic [7:0] mem [0:262143]; // 256 KB byte-addressable

  // Single-cycle memory response
  assign imem_valid = imem_req;
  assign dmem_valid = dmem_req;

  // Instruction Fetch Read
  wire [31:0] imem_idx = {14'b0, imem_addr[17:0]};
  always_comb begin
    imem_rdata = {mem[imem_idx + 3], mem[imem_idx + 2], mem[imem_idx + 1], mem[imem_idx]};
  end

  // Data Memory Read (64-bit little-endian)
  wire [31:0] dmem_idx = {14'b0, dmem_addr[17:0]};
  always_comb begin
    dmem_rdata = {
      mem[dmem_idx + 7], mem[dmem_idx + 6], mem[dmem_idx + 5], mem[dmem_idx + 4],
      mem[dmem_idx + 3], mem[dmem_idx + 2], mem[dmem_idx + 1], mem[dmem_idx + 0]
    };
  end

  // Data Memory Write with Byte Strobes
  always_ff @(posedge clk) begin
    if (dmem_req && dmem_we) begin
      // Test pass/fail indicator address: 0x8000_1000
      if (dmem_addr[31:0] == 32'h8000_1000) begin
        if (dmem_wdata[31:0] == 32'hCAFE_BABE) begin
          test_passed <= 1'b1;
        end else begin
          test_failed      <= 1'b1;
          test_error_code  <= dmem_wdata[31:0];
        end
      end

      for (int i = 0; i < 8; i++) begin
        if (dmem_wstrb[i]) begin
          mem[dmem_idx + i] <= dmem_wdata[i*8 +: 8];
        end
      end
    end

    if (debug_pc == 64'h10ce) begin
      $display("[%0t ns] [DEBUG at 0x10ce] rs1(a3)=0x%0x rs2(a1)=0x%0x (rf a3=0x%0x, a1=0x%0x)",
               $time, dut.id_ex_rs1_data, dut.id_ex_rs2_data,
               dut.u_id_stage.u_regfile.regs[13], dut.u_id_stage.u_regfile.regs[11]);
    end

    if (debug_pc == 64'h10d0) begin
      $display("[%0t ns] [AT 0x10d0] ptw_state=%0d dtlb_req=%0d itlb_req=%0d dmem_vaddr=0x%0x dtlb_hit=%0d dtlb_store_fault=%0d",
               $time, dut.u_mmu.u_ptw.state_q, dut.u_mmu.dtlb_ptw_req, dut.u_mmu.itlb_ptw_req, dut.dmem_vaddr, dut.u_mmu.dtlb_hit, dut.u_mmu.dtlb_store_fault);
    end

    if (debug_pc == 64'h10e2) begin
      $display("[%0t ns] [AT 0x10e2] req=%0d we=%0d addr=0x%0x wdata=0x%0x hit=%0d busy=%0d",
               $time, dmem_req, dmem_we, dmem_addr, dmem_wdata, dut.mmu_data_hit, dut.mmu_busy);
    end
  end

  string hex_file = "sw/tests/asm/test_rv64_all.hex";
  int fd, r;
  logic [31:0] word;
  int addr;

  initial begin
    $dumpfile("waveform_core.vcd");
    test_passed     = 1'b0;
    test_failed     = 1'b0;
    test_error_code = 32'd0;

    for (int i = 0; i < 262144; i++) begin
      mem[i] = 8'h00;
    end

    void'($value$plusargs("hex_file=%s", hex_file));
    fd = $fopen(hex_file, "r");
    if (fd != 0) begin
      addr = 32'h0000_1000;
      while (!$feof(fd)) begin
        r = $fscanf(fd, "%h\n", word);
        if (r == 1) begin
          mem[addr + 0] = word[7:0];
          mem[addr + 1] = word[15:8];
          mem[addr + 2] = word[23:16];
          mem[addr + 3] = word[31:24];
          addr = addr + 4;
        end
      end
      $fclose(fd);
      $display("[TB] Loaded firmware from %s (%0d bytes)", hex_file, addr - 32'h1000);
    end else begin
      $display("[TB ERROR] Could not open hex file: %s", hex_file);
    end
  end

endmodule
