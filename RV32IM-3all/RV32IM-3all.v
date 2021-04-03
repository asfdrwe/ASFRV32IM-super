// Copyright (c) 2020, 2021 asfdrwe (asfdrwe@gmail.com)
// SPDX-License-Identifier: MIT
module DECODE_EXEC(input wire [31:0] opcode, input wire [31:0] pc,
output wire [4:0] r_addr1, output wire [4:0] r_addr2, output wire [4:0] w_addr,
input wire [31:0] r_data1, input wire [31:0] r_data2,
output wire [31:0] alu_data,
output wire [2:0] funct3, output wire mem_rw, output wire rf_wen, output wire [1:0] wb_sel, output wire pc_sel2
);
  wire [31:0] imm;
  wire [4:0] alucon;
  wire op1sel, op2sel;
  wire [1:0] pc_sel;

  wire [6:0] op;
  assign op = opcode[6:0];

  localparam [6:0] RFORMAT       = 7'b0110011;
  localparam [6:0] IFORMAT_ALU   = 7'b0010011;
  localparam [6:0] IFORMAT_LOAD  = 7'b0000011;
  localparam [6:0] SFORMAT       = 7'b0100011;
  localparam [6:0] SBFORMAT      = 7'b1100011;
  localparam [6:0] UFORMAT_LUI   = 7'b0110111;
  localparam [6:0] UFORMAT_AUIPC = 7'b0010111;
  localparam [6:0] UJFORMAT      = 7'b1101111;
  localparam [6:0] IFORMAT_JALR  = 7'b1100111;
  localparam [6:0] ECALLEBREAK   = 7'b1110011;
  localparam [6:0] FENCE         = 7'b0001111;
  localparam [6:0] MULDIV        = 7'b0110011;

  assign r_addr1 = (op == UFORMAT_LUI) ? 5'b0 : opcode[19:15];
  assign r_addr2 = opcode[24:20];
  assign w_addr =  opcode[11:7];

  assign imm[31:20] = ((op == UFORMAT_LUI) || (op == UFORMAT_AUIPC)) ? opcode[31:20] : 
		      (opcode[31] == 1'b1) ? 12'hfff : 12'b0;
  assign imm[19:12] = ((op == UFORMAT_LUI) || (op == UFORMAT_AUIPC) || (op == UJFORMAT)) ? opcode[19:12] :
                      (opcode[31] == 1'b1) ? 8'hff : 8'b0;
  assign imm[11] = (op == SBFORMAT) ? opcode[7] :
                   ((op == UFORMAT_LUI) || (op == UFORMAT_AUIPC)) ? 1'b0 :
                   (op == UJFORMAT) ? opcode[20] : opcode[31];
  assign imm[10:5] = ((op == UFORMAT_LUI) || (op == UFORMAT_AUIPC)) ? 6'b0 : opcode[30:25];
  assign imm[4:1] = ((op == IFORMAT_ALU) || (op == IFORMAT_LOAD) || (op == IFORMAT_JALR) || (op == UJFORMAT)) ? opcode[24:21] :
		    ((op == SFORMAT) || (op == SBFORMAT)) ? opcode[11:8] : 4'b0;
  assign imm[0] = ((op == IFORMAT_ALU) || (op == IFORMAT_LOAD) || (op == IFORMAT_JALR)) ? opcode[20] :
		  (op == SFORMAT) ? opcode[7] : 1'b0;

  assign alucon = ((op == RFORMAT) || (op == MULDIV)) ? {opcode[30], opcode[25], opcode[14:12]} :
                  ((op == IFORMAT_ALU) && (opcode[14:12] == 3'b101)) ? {opcode[30], opcode[25], opcode[14:12]} : // SRLI or SRAI
                  (op == IFORMAT_ALU) ? {2'b00, opcode[14:12]} : 5'b0;
  assign funct3 = opcode[14:12];
  assign op1sel = ((op == SBFORMAT) || (op == UFORMAT_AUIPC) || (op == UJFORMAT)) ? 1'b1 : 1'b0;
  assign op2sel = ((op == RFORMAT) || (op == MULDIV)) ? 1'b0 : 1'b1;
  assign mem_rw = (op == SFORMAT) ? 1'b1 : 1'b0;
  assign wb_sel = (op == IFORMAT_LOAD) ? 2'b01 :
                  ((op == UJFORMAT) || (op == IFORMAT_JALR)) ? 2'b10 : 2'b00;
  assign rf_wen = (((op == RFORMAT) && ({opcode[31],opcode[29:25]} == 6'b000000)) ||
                   ((op == MULDIV) && ({opcode[31:25]} == 7'b000001)) ||
                   ((op == IFORMAT_ALU) && (({opcode[31:25], opcode[14:12]} == 10'b00000_00_001) || ({opcode[31], opcode[29:25], opcode[14:12]} == 9'b0_000_00_101) ||  // SLLI or SRLI or SRAI
                                            (opcode[14:12] == 3'b000) || (opcode[14:12] == 3'b010) || (opcode[14:12] == 3'b011) || (opcode[14:12] == 3'b100) || (opcode[14:12] == 3'b110) || (opcode[14:12] == 3'b111))) ||
                   (op == IFORMAT_LOAD) || (op == UFORMAT_LUI) || (op == UFORMAT_AUIPC) || (op == UJFORMAT) || (op == IFORMAT_JALR)) ? 1'b1 : 1'b0;
  assign pc_sel = (op == SBFORMAT) ? 2'b01 :
                  ((op == UJFORMAT) || (op == IFORMAT_JALR) || (op == ECALLEBREAK)) ? 2'b10 : 2'b00;

  // SELECTOR  
  wire [31:0] s_data1, s_data2;
  assign s_data1 = (op1sel == 1'b1) ? pc : r_data1;
  assign s_data2 = (op2sel == 1'b1) ? imm : r_data2;

  // ALU
  reg [63:0] tmpalu;

  function [31:0] ALU_EXEC( input [4:0] control, input [31:0] data1, input [31:0] data2);
    case(control)
    5'b00000: // ADD ADDI (ADD)
      ALU_EXEC = data1 + data2;
    5'b10000: // SUB (SUB)
      ALU_EXEC = data1 - data2;
    5'b00001: // SLL SLLI (SHIFT LEFT (LOGICAL))
      ALU_EXEC = data1 << data2[4:0];
    5'b00010: // SLT SLTI (SET_ON_LESS_THAN (SIGNED))
      ALU_EXEC = ($signed(data1) < $signed(data2)) ? 32'b1 :32'b0;
    5'b00011: // SLTU SLTUI (SET_ON_LESS_THAN (UNSIGNED))
      ALU_EXEC = (data1 < data2) ? 32'b1 :32'b0;
    5'b00100: // XOR XORI (XOR)
      ALU_EXEC = data1 ^ data2;
    5'b00101: // SRL SRLI (SHIFT RIGHT (LOGICAL))
      ALU_EXEC = data1 >> data2[4:0];
    5'b10101: // SRA SRAI (SHIFT RIGHT (ARITHMETIC))
      ALU_EXEC = $signed(data1[31:0]) >>> data2[4:0];
    5'b00110: // OR ORI (OR)
      ALU_EXEC = data1 | data2;
    5'b00111: // AND ANDI (AND)
      ALU_EXEC = data1 & data2;
    5'b01000: // MUL (MULTIPLE)
      ALU_EXEC = data1 * data2;
    5'b01001: begin // MULH (MULTIPLE)
      tmpalu = $signed(data1) * $signed(data2);
      ALU_EXEC = $signed(tmpalu) >>> 32;
    end
    5'b01010: begin // MULHSU (MULTIPLE)
      tmpalu = $signed(data1) * $signed({1'b0, data2});
      ALU_EXEC = tmpalu >> 32;
    end
    5'b01011: begin // MULHU (MULTIPLE)
      tmpalu = data1 * data2;
      ALU_EXEC = tmpalu >> 32;
    end
    5'b01100: // DIV (DIVIDE)
      ALU_EXEC = (data2 == 32'b0) ? 32'hffff_ffff : 
                 ((data1 == 32'h8000_0000) && (data2 == 32'hffff_ffff)) ? 32'h8000_0000 : $signed($signed(data1) / $signed(data2));
    5'b01101: // DIVU (DIVIDE)
      ALU_EXEC = (data2 == 32'b0) ? 32'hffff_ffff : (data1 / data2);
    5'b01110: // REM (DIVIDE REMINDER)
      ALU_EXEC = (data2 == 32'b0) ? data1 : 
                 ((data1 == 32'h8000_0000) && (data2 == 32'hffff_ffff)) ? 32'h0 : $signed($signed(data1) % $signed(data2));
    5'b01111: // REMU (DIVIDE REMINDER)
      ALU_EXEC = (data2 == 32'b0) ? data1 : (data1 % data2);
    default: // ILLEGAL
      ALU_EXEC = 32'b0;
    endcase
  endfunction

  assign alu_data = ALU_EXEC(alucon, s_data1, s_data2);

  // BRANCH

  function BRANCH_EXEC( input [2:0] branch_op, input [31:0] data1, input [31:0] data2, input [1:0] pc_sel);
    case(pc_sel)
    2'b00: // PC + 4
      BRANCH_EXEC = 1'b0;
    2'b01: begin // BRANCH
      case(branch_op)
      3'b000: // BEQ
        BRANCH_EXEC = (data1 == data2) ? 1'b1 : 1'b0;
      3'b001: // BNE
        BRANCH_EXEC = (data1 != data2) ? 1'b1 : 1'b0;
      3'b100: // BLT
        BRANCH_EXEC = ($signed(data1) < $signed(data2)) ? 1'b1 : 1'b0;
      3'b101: // BGE
        BRANCH_EXEC = ($signed(data1) >= $signed(data2)) ? 1'b1 : 1'b0;
      3'b110: // BLTU
        BRANCH_EXEC = (data1 < data2) ? 1'b1 : 1'b0;
      3'b111: // BGEU
        BRANCH_EXEC = (data1 >= data2) ? 1'b1 : 1'b0;
      default: // ILLEGAL
        BRANCH_EXEC = 1'b0;
      endcase
    end 
    2'b10: // JAL JALR
      BRANCH_EXEC = 1'b1;
    default: // ILLEGAL
      BRANCH_EXEC = 1'b0;
    endcase
  endfunction

  assign pc_sel2 = BRANCH_EXEC(funct3, r_data1, r_data2, pc_sel);
endmodule

module RV32IM(input wire clock, input wire reset_n, output wire [31:0] pc_out, output wire [95:0] op_out, output wire [95:0] alu_out, output wire [8:0] uart_out);
  // REGISTER
  reg [31:0] pc;
  assign pc_out = pc; // for DEBUG
  reg [31:0] regs[0:31];

  // MEMORY 64KB 
  reg [7:0] mem[0:16'hffff]; // MEMORY 64KB
  initial $readmemh("test.hex", mem); // MEMORY INITIALIZE 

  // UART OUTPUT and CYCLE COUNTER
  reg [8:0] uart = 9'b0; // uart[8] for output sign, uart[7:0] for data
  assign uart_out = uart;
  localparam [31:0] UART_MMIO_ADDR = 32'h0000_fff0; // ADDRESS 0xfff0 for UART
  localparam [31:0] UART_MMIO_FLAG = 32'h0000_fff1; // ADDRESS 0xfff1 for UART FLAG
  reg [31:0] counter = 32'b0;
  localparam [31:0] COUNTER_MMIO_ADDR = 32'h0000_fff4; // ADDRESS 0xfff4 for COUNTER

  localparam [6:0] RFORMAT       = 7'b0110011;
  localparam [6:0] IFORMAT_ALU   = 7'b0010011;
  localparam [6:0] IFORMAT_LOAD  = 7'b0000011;
  localparam [6:0] SFORMAT       = 7'b0100011;
  localparam [6:0] SBFORMAT      = 7'b1100011;
  localparam [6:0] UFORMAT_LUI   = 7'b0110111;
  localparam [6:0] UFORMAT_AUIPC = 7'b0010111;
  localparam [6:0] UJFORMAT      = 7'b1101111;
  localparam [6:0] IFORMAT_JALR  = 7'b1100111;
  localparam [6:0] ECALLEBREAK   = 7'b1110011;
  localparam [6:0] FENCE         = 7'b0001111;
  localparam [6:0] MULDIV        = 7'b0110011;

  // FETCH & PREDECODE
  wire [31:0] opcode1, opcode2, opcode3;
  wire [31:0] tmpopcode1, tmpopcode2, tmpopcode3;
  assign tmpopcode1 = {mem[pc +  3], mem[pc +  2], mem[pc + 1], mem[pc    ]};
  assign tmpopcode2 = {mem[pc +  7], mem[pc +  6], mem[pc + 5], mem[pc + 4]};
  assign tmpopcode3 = {mem[pc + 11], mem[pc + 10], mem[pc + 9], mem[pc + 8]};
  
  wire [6:0] op1, op2, op3;
  wire [4:0] regd_1, regd_2, regd_3;
  wire [4:0] reg1_2, reg2_2, reg1_3, reg2_3;
  assign op1 = tmpopcode1[6:0];
  assign op2 = tmpopcode2[6:0];
  assign op3 = tmpopcode3[6:0];
  assign regd_1 = tmpopcode1[11:7];
  assign regd_2 = tmpopcode2[11:7];
  assign regd_3 = tmpopcode3[11:7];
  assign reg1_2 = tmpopcode2[19:15];
  assign reg2_2 = tmpopcode2[24:20];
  assign reg1_3 = tmpopcode3[19:15];
  assign reg2_3 = tmpopcode3[24:20];

  wire isBranch1;
  wire isBP1;
  wire isBranch2;
  wire isBP2;
  wire isMemOp2; // MEMORY OPERATION RESTRICTED on dec_exec2
  wire isMemOp3; // MEMORY OPERATION RESTRICTED on dec_exec3
  wire isRegD_1;
  wire isRegD_2;
  wire isReg1_2;
  wire isReg2_2;
  wire isReg1_3;
  wire isReg2_3;
  
  assign isBranch1 = (op1 == UJFORMAT) || (op1 == IFORMAT_JALR) || (op1 == ECALLEBREAK);
  assign isBP1 = (op1 == SBFORMAT);
  assign isBranch2 = (op2 == UJFORMAT) || (op2 == IFORMAT_JALR) || (op2 == ECALLEBREAK); 
  assign isBP2 = (op2 == SBFORMAT);
  assign isMemOp2 = (op1 == SFORMAT) && (op2 == IFORMAT_LOAD); // MEMORY STORE & LOAD DEPENDANCY 1-2
  assign isMemOp3 = ((op1 == SFORMAT) || (op2 == SFORMAT)) && (op3 == IFORMAT_LOAD);// MEMORY STORE & LOAD DEPENDANCY 1-3 or 2-3
  assign isRegD_1 = (regd_1 != 5'b0) &&
                  ((op1 == RFORMAT) || (op1 == IFORMAT_ALU) || (op1 == IFORMAT_LOAD) || (op1 == UFORMAT_LUI) || 
                   (op1 == UFORMAT_AUIPC) || (op1 == UJFORMAT) || (op1 == IFORMAT_JALR) || (op1 == MULDIV));
  assign isRegD_2 = (regd_2 != 5'b0) &&
                  ((op2 == RFORMAT) || (op2 == IFORMAT_ALU) || (op2 == IFORMAT_LOAD) || (op2 == UFORMAT_LUI) || 
                   (op2 == UFORMAT_AUIPC) || (op2 == UJFORMAT) || (op2 == IFORMAT_JALR) || (op2 == MULDIV));
  assign isReg1_2 = (reg1_2 != 5'b0) &&
                  ((op2 == RFORMAT) || (op2 == IFORMAT_ALU) || (op2 == IFORMAT_LOAD) || (op2 == SFORMAT) || 
                   (op2 == SBFORMAT) || (op2 == IFORMAT_JALR) || (op2 == MULDIV));
  assign isReg2_2 = (reg2_2 != 5'b0) &&
                  ((op2 == RFORMAT) || (op2 == SFORMAT) || (op2 == SBFORMAT) || (op2 == MULDIV));
  assign isReg1_3 = (reg1_3 != 5'b0) &&
                  ((op3 == RFORMAT) || (op3 == IFORMAT_ALU) || (op3 == IFORMAT_LOAD) || (op3 == SFORMAT) || 
                   (op3 == SBFORMAT) || (op3 == IFORMAT_JALR) || (op3 == MULDIV));
  assign isReg2_3 = (reg2_3 != 5'b0) &&
                  ((op3 == RFORMAT) || (op3 == SFORMAT) || (op3 == SBFORMAT) || (op3 == MULDIV));
                  
  wire [1:0] superscalar;
  assign superscalar = (!isBranch1 && !isBranch2 && // not BRANCH on 1,2
                        !isMemOp2 && !isMemOp3 && // not MemOP on 2,3
                        (!isRegD_1 || (!isReg1_2 || (regd_1 != reg1_2)) && (!isReg2_2 || (regd_1 != reg2_2))) && // not REGISTER DEPENDANCY 1-2
                        (!isRegD_1 || (!isReg1_3 || (regd_1 != reg1_3)) && (!isReg2_3 || (regd_1 != reg2_3))) && // not REGISTER DEPENDANCY 1-3
                        (!isRegD_2 || (!isReg1_3 || (regd_2 != reg1_3)) && (!isReg2_3 || (regd_2 != reg2_3)))) ? 2'b10 : // not REGISTER DEPENDANCY 2-3
                       (!isBranch1 && // not BRANCH1
                        !isMemOp2 && // not MemOP2
                        (!isRegD_1 || (!isReg1_2 || (regd_1 != reg1_2)) && (!isReg2_2 || (regd_1 != reg2_2)))) ? 2'b01 : // not REGISTER DEPENDANCY 1-2
                        2'b00;

  assign opcode1 = tmpopcode1;
  assign opcode2 = ((superscalar == 2'b10) || (superscalar == 2'b01)) ? tmpopcode2 : 32'b0;
  assign opcode3 = (superscalar == 2'b10) ? tmpopcode3 : 32'b0;
  assign op_out = {opcode3, opcode2, opcode1}; // for DEBUG

  // DECODE & EXECUTION 1
  wire [4:0] r_addr1, r_addr2, w_addr;
  wire mem_rw, rf_wen;
  wire [2:0] funct3;
  wire [1:0] wb_sel;
  wire pc_sel2;
  wire [31:0] r_data1, r_data2;
  wire [2:0] mem_val;
  wire [31:0] alu_data;

  // REGISTER READ 1
  assign r_data1 = (r_addr1 == 5'b00000) ? 32'b0 : regs[r_addr1]; 
  assign r_data2 = (r_addr2 == 5'b00000) ? 32'b0 : regs[r_addr2]; 

  DECODE_EXEC dec_exe1(opcode1, pc, r_addr1, r_addr2, w_addr, r_data1, r_data2, alu_data, mem_val, mem_rw, rf_wen, wb_sel, pc_sel2);

  // DECODE & EXECUTION 2
  wire [4:0] r_addr1_2, r_addr2_2, w_addr_2;
  wire mem_rw_2, rf_wen_2;
  wire [2:0] funct3_2;
  wire [1:0] wb_sel_2;
  wire pc_sel2_2;
  wire [31:0] r_data1_2, r_data2_2;
  wire [2:0] mem_val_2;
  wire [31:0] alu_data_2;

  // REGISTER READ 2
  assign r_data1_2 = (r_addr1_2 == 5'b00000) ? 32'b0 : regs[r_addr1_2]; 
  assign r_data2_2 = (r_addr2_2 == 5'b00000) ? 32'b0 : regs[r_addr2_2]; 

  DECODE_EXEC dec_exe2(opcode2, pc + 4, r_addr1_2, r_addr2_2, w_addr_2, r_data1_2, r_data2_2, alu_data_2, mem_val_2, mem_rw_2, rf_wen_2, wb_sel_2, pc_sel2_2);

  // DECODE & EXECUTION 3
  wire [4:0] r_addr1_3, r_addr2_3, w_addr_3;
  wire mem_rw_3, rf_wen_3;
  wire [2:0] funct3_3;
  wire [1:0] wb_sel_3;
  wire pc_sel2_3;
  wire [31:0] r_data1_3, r_data2_3;
  wire [2:0] mem_val_3;
  wire [31:0] alu_data_3;

  // REGISTER READ 3
  assign r_data1_3 = (r_addr1_3 == 5'b00000) ? 32'b0 : regs[r_addr1_3]; 
  assign r_data2_3 = (r_addr2_3 == 5'b00000) ? 32'b0 : regs[r_addr2_3]; 

  DECODE_EXEC dec_exe3(opcode3, pc + 8, r_addr1_3, r_addr2_3, w_addr_3, r_data1_3, r_data2_3, alu_data_3, mem_val_3, mem_rw_3, rf_wen_3, wb_sel_3, pc_sel2_3);

  assign alu_out = {alu_data_3, alu_data_2, alu_data}; // for DEBUG

  // MEMORY 1
  wire [31:0] mem_data;
  wire [31:0] mem_addr;
  assign mem_addr = alu_data;
  
  // MEMORY READ 1
  assign mem_data = (mem_rw == 1'b1) ? 32'b0 : // when MEMORY WRITE, the output from MEMORY is 32'b0
		    ((mem_val == 3'b010) && (mem_addr == COUNTER_MMIO_ADDR)) ? counter : // MEMORY MAPPED IO for CLOCK CYCLE COUNTER
		    ((mem_val[1:0] == 2'b00) && (mem_addr == UART_MMIO_FLAG)) ? 8'b1 : // MEMORY MAPPED IO for UART FLAG(always enabled(8'b1))
                     (mem_val == 3'b000) ?  (mem[mem_addr][7] == 1'b1 ? {24'hffffff, mem[mem_addr]} : {24'h000000, mem[mem_addr]}) : // LB
                     (mem_val == 3'b001) ?  (mem[mem_addr + 1][7] == 1'b1 ? {16'hffff, mem[mem_addr + 1], mem[mem_addr]} : {16'h0000, mem[mem_addr + 1], mem[mem_addr]}) : // LH
                     (mem_val == 3'b010) ? {mem[mem_addr + 3], mem[mem_addr + 2], mem[mem_addr + 1], mem[mem_addr]} : // LW
                     (mem_val == 3'b100) ? {24'h000000, mem[mem_addr]} : // LBU
                     (mem_val == 3'b101) ? {16'h0000, mem[mem_addr + 1], mem[mem_addr]} : // LHU
                                           32'b0;
  // MEMORY 2
  wire [31:0] mem_data_2;
  wire [31:0] mem_addr_2;
  assign mem_addr_2 = alu_data_2;
  
  // MEMORY READ 2
  assign mem_data_2 = (mem_rw_2 == 1'b1) ? 32'b0 : // when MEMORY WRITE, the output from MEMORY is 32'b0
		     ((mem_val_2 == 3'b010) && (mem_addr_2 == COUNTER_MMIO_ADDR)) ? counter : // MEMORY MAPPED IO for CLOCK CYCLE COUNTER
		     ((mem_val_2[1:0] == 2'b00) && (mem_addr_2 == UART_MMIO_FLAG)) ? 8'b1 : // MEMORY MAPPED IO for UART FLAG(always enabled(8'b1))
                      (mem_val_2 == 3'b000) ?  (mem[mem_addr_2][7] == 1'b1 ? {24'hffffff, mem[mem_addr_2]} : {24'h000000, mem[mem_addr_2]}) : // LB
                      (mem_val_2 == 3'b001) ?  (mem[mem_addr_2 + 1][7] == 1'b1 ? {16'hffff, mem[mem_addr_2 + 1], mem[mem_addr_2]} : {16'h0000, mem[mem_addr_2 + 1], mem[mem_addr_2]}) : // LH
                      (mem_val_2 == 3'b010) ? {mem[mem_addr_2 + 3], mem[mem_addr_2 + 2], mem[mem_addr_2 + 1], mem[mem_addr_2]} : // LW
                      (mem_val_2 == 3'b100) ? {24'h000000, mem[mem_addr_2]} : // LBU
                      (mem_val_2 == 3'b101) ? {16'h0000, mem[mem_addr_2 + 1], mem[mem_addr_2]} : // LHU
                                              32'b0;
  // MEMORY 3
  wire [31:0] mem_data_3;
  wire [31:0] mem_addr_3;
  assign mem_addr_3 = alu_data_3;
  
  // MEMORY READ 3
  assign mem_data_3 = (mem_rw_3 == 1'b1) ? 32'b0 : // when MEMORY WRITE, the output from MEMORY is 32'b0
		     ((mem_val_3 == 3'b010) && (mem_addr_3 == COUNTER_MMIO_ADDR)) ? counter : // MEMORY MAPPED IO for CLOCK CYCLE COUNTER
		     ((mem_val_3[1:0] == 2'b00) && (mem_addr_3 == UART_MMIO_FLAG)) ? 8'b1 : // MEMORY MAPPED IO for UART FLAG(always enabled(8'b1))
                      (mem_val_3 == 3'b000) ?  (mem[mem_addr_3][7] == 1'b1 ? {24'hffffff, mem[mem_addr_3]} : {24'h000000, mem[mem_addr_3]}) : // LB
                      (mem_val_3 == 3'b001) ?  (mem[mem_addr_3 + 1][7] == 1'b1 ? {16'hffff, mem[mem_addr_3 + 1], mem[mem_addr_3]} : {16'h0000, mem[mem_addr_3 + 1], mem[mem_addr_3]}) : // LH
                      (mem_val_3 == 3'b010) ? {mem[mem_addr_3 + 3], mem[mem_addr_3 + 2], mem[mem_addr_3 + 1], mem[mem_addr_3]} : // LW
                      (mem_val_3 == 3'b100) ? {24'h000000, mem[mem_addr_3]} : // LBU
                      (mem_val_3 == 3'b101) ? {16'h0000, mem[mem_addr_3 + 1], mem[mem_addr_3]} : // LHU
                                              32'b0;

  // MEMORY WRITE
  // intentionally blocking statement
  always @(posedge clock) begin
    if (mem_rw == 1'b1)
      case (mem_val)
        3'b000: // SB
          mem[mem_addr] = r_data2[7:0];
        3'b001: // SH
          {mem[mem_addr + 1], mem[mem_addr]} = r_data2[15:0];
        3'b010: // SW
          {mem[mem_addr + 3], mem[mem_addr + 2], mem[mem_addr + 1], mem[mem_addr]} = r_data2;
        default: begin end // ILLEGAL
      endcase
    if ((mem_rw_2 == 1'b1) && !((isBP1 == 1'b1) && (pc_sel2 == 1'b1)))
      case (mem_val_2)
        3'b000: // SB
          mem[mem_addr_2] = r_data2_2[7:0];
        3'b001: // SH
          {mem[mem_addr_2 + 1], mem[mem_addr_2]} = r_data2_2[15:0];
        3'b010: // SW
          {mem[mem_addr_2 + 3], mem[mem_addr_2 + 2], mem[mem_addr_2 + 1], mem[mem_addr_2]} = r_data2_2;
        default: begin end // ILLEGAL
      endcase
    if ((mem_rw_3 == 1'b1) && !((isBP1 == 1'b1) && (pc_sel2 == 1'b1)) && !((isBP2 == 1'b1) && (pc_sel2_2 == 1'b1)))
      case (mem_val_3)
        3'b000: // SB
          mem[mem_addr_3] = r_data2_3[7:0];
        3'b001: // SH
          {mem[mem_addr_3 + 1], mem[mem_addr_3]} = r_data2_3[15:0];
        3'b010: // SW
          {mem[mem_addr_3 + 3], mem[mem_addr_3 + 2], mem[mem_addr_3 + 1], mem[mem_addr_3]} = r_data2_3;
        default: begin end // ILLEGAL
      endcase
    // MEMORY MAPPED IO to UART
    if ((mem_rw == 1'b1) && (mem_addr == UART_MMIO_ADDR))
      uart = {1'b1, r_data2[7:0]};
    else if ((mem_rw_2 == 1'b1) && (mem_addr_2 == UART_MMIO_ADDR) && !((isBP1 == 1'b1) && (pc_sel2 == 1'b1)))
      uart = {1'b1, r_data2_2[7:0]};
    else  if ((mem_rw_3 == 1'b1) && (mem_addr_3 == UART_MMIO_ADDR) && (pc_sel2 == 1'b1) && !((isBP2 == 1'b1) && (pc_sel2_2 == 1'b1)))
      uart = {1'b1, r_data2_3[7:0]};
    else
      uart = 9'b0;
  end

  // REGISTER WRITE BACK
  // intentionally blocking statement
  wire [31:0] w_data;
  assign w_data   = (wb_sel   == 2'b00) ? alu_data : 
                    (wb_sel   == 2'b01) ? mem_data :
                    (wb_sel   == 2'b10) ? pc + 4 : 32'b0; // ILLEGAL
  wire [31:0] w_data_2;
  assign w_data_2 = (wb_sel_2 == 2'b00) ? alu_data_2 : 
                    (wb_sel_2 == 2'b01) ? mem_data_2 :
                    (wb_sel_2 == 2'b10) ? pc + 8 : 32'b0; // ILLEGAL
  wire [31:0] w_data_3;
  assign w_data_3 = (wb_sel_3 == 2'b00) ? alu_data_3 : 
                    (wb_sel_3 == 2'b01) ? mem_data_3 :
                    (wb_sel_3 == 2'b10) ? pc + 12 : 32'b0; // ILLEGAL

  always @(posedge clock) begin
    if ((rf_wen   == 1'b1) && (w_addr   != 5'b00000))
      regs[w_addr  ] = w_data;
    if ((rf_wen_2 == 1'b1) && (w_addr_2 != 5'b00000) &&
      !((isBP1 == 1'b1) && (pc_sel2 == 1'b1))) // if not BRANCH1
      regs[w_addr_2] = w_data_2;
    if ((rf_wen_3 == 1'b1) && (w_addr_3 != 5'b00000) &&
      !((isBP1 == 1'b1) && (pc_sel2 == 1'b1)) && // if not BRANCH1
      !((isBP2 == 1'b1) && (pc_sel2_2 == 1'b1))) // if not BRANCH2
      regs[w_addr_3] = w_data_3;
  end

  // NEXT PC
  wire [31:0] next_pc;
  assign next_pc = (superscalar == 2'b10) ? ((isBP1 == 1'b1) && (pc_sel2   == 1'b1)) ? {alu_data  [31:1], 1'b0} : // BRANCH1 Prediction failed
                                            ((isBP2 == 1'b1) && (pc_sel2_2 == 1'b1)) ? {alu_data_2 [31:1], 1'b0} : // BRANCH2 Prediction failed
                                            (pc_sel2_3 == 1'b1) ? {alu_data_3[31:1], 1'b0} : pc + 12 :
                   (superscalar == 2'b01) ? ((isBP1 == 1'b1) && (pc_sel2   == 1'b1)) ? {alu_data  [31:1], 1'b0} : // BRANCH1 Prediction failed
                                            (pc_sel2_2 == 1'b1) ? {alu_data_2[31:1], 1'b0} : pc +  8 :
					    (pc_sel2   == 1'b1) ? {alu_data  [31:1], 1'b0} : pc +  4 ;

  // NEXT PC WRITE BACK and CYCLE COUNTER
  always @(posedge clock or negedge reset_n) begin
   if (!reset_n) begin
      pc <= 32'b0;
      counter <= 32'b0;
    end else begin
      pc <= #1 next_pc; 
      counter <= counter + 1;
    end
  end
endmodule
