// Copyright (c) 2020 asfdrwe (asfdrwe@gmail.com)
// SPDX-License-Identifier: MIT
module DECODE_EXEC(input wire [31:0] opcode, input wire [31:0] pc,
input wire[17:0] opcode2, // for Macro op fusion
output wire [4:0] r_addr1, output wire [4:0] r_addr2, output wire [4:0] w_addr,
input wire [31:0] r_data1, input wire [31:0] r_data2,
output wire [31:0] alu_data,
output wire [2:0] funct3, output wire mem_rw, output wire rf_wen, output wire [1:0] wb_sel, output wire pc_sel2
);
  wire [31:0] imm;
  wire [4:0] alucon;
  wire [1:0] op1sel;
  wire op2sel;
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

  localparam [6:0] MACROPFUSION1 = 7'b0001011;
  localparam [6:0] MACROPFUSION2 = 7'b0101011;

  // Macro-Operation Fusion
  // from https://people.eecs.berkeley.edu/~krste/papers/EECS-2016-130.pdf
  //
  // Load Effective Address 
  // 31      25 24 20 19  15 14  12 11      7 6     0   17  1514          3 2  0
  // | 0000000shamt | rs1  |funct3 |  rd     |0001011| +|000  |000000rs2   |010|
  // slli rd, rs1, {1,2} (funct3=010 or 011)
  // add rd, rd, rs2
  //
  // Indexed Load
  // 31      25 24 20 19  15 14  12 11      7 6     0   17  1514          3 2  0
  // | 0x00000| rs2 | rs1  |funct3 |  rd     |0001011| +|memop|000000000000|011|
  // (add or any op) rd, rs1, rs2
  // lb or lbu or lh or lhu or lw rd, 0(rd)
  //
  // Load Immediate Idiom1
  // 31      25 24 20 19  15 14  12 11      7 6     0   17  1514          3 2  0
  // | imm[31:12]                   |  rd    |0001011| +|000  |imm[11:0]   |100|
  // lui rd, imm[31:12]
  // addi rd, rd, imm[11:0]
  //
  // Load Immediate Idiom2
  // 31      25 24 20 19  15 14  12 11      7 6     0   17  1514          3 2  0
  // | imm[31:12]                   |  rd    |0001011| +|memop|imm[11:0]   |101|
  // lui rd, imm[31:12]
  // lb or lbu or lh or lhu or lw rd, imm[11:0](rd)
  //
  // Load Global
  // 31      25 24 20 19  15 14  12 11      7 6     0   17  1514          3 2  0
  // | imm[31:12]                   |  rd    |0001011| +|memop|imm[11:0]   |110|
  // auipc rd, imm[31:12]
  // lb or lbu or lh or lhu or lw rd, imm[11:0](rd)
  
  wire [2:0] op2;
  assign op2 = opcode2[2:0];
  wire [4:0] op2_reg2;
  assign op2_reg2 = opcode2[7:3];
  wire [2:0] op2_funct3;
  assign op2_funct3 = opcode2[17:15];
  wire [11:0] op2_imm;
  assign op2_imm = opcode2[14:3]; // for LII1 or LII2

  wire macroLEA;
  assign macroLEA  = (op == MACROPFUSION1) && (op2 == 3'b010); // Load Effective Address
  wire macroIL;
  assign macroIL   = (op == MACROPFUSION1) && (op2 == 3'b011); // Indexed Load
  wire macroLII1;
  assign macroLII1 = (op == MACROPFUSION1) && (op2 == 3'b100); // Load Immediate Idiom1
  wire macroLII2;
  assign macroLII2 = (op == MACROPFUSION1) && (op2 == 3'b101); // Load Immediate Idiom2
  wire macroLG;
  assign macroLG   = (op == MACROPFUSION1) && (op2 == 3'b110); // Load Global

  assign r_addr1 = ((op == UFORMAT_LUI) || macroLII1 || macroLII2) ? 5'b0 : opcode[19:15];
  assign r_addr2 = macroLEA ? op2_reg2 : opcode[24:20];
  assign w_addr =  opcode[11:7];

  assign imm[31:20] = ((op == UFORMAT_LUI) || (op == UFORMAT_AUIPC) || macroLII1 || macroLII2 || macroLG) ? opcode[31:20] : 
		      (opcode[31] == 1'b1) ? 12'hfff : 12'b0;
  assign imm[19:12] = ((op == UFORMAT_LUI) || (op == UFORMAT_AUIPC) || (op == UJFORMAT) || macroLII1 || macroLII2 || macroLG) ? opcode[19:12] :
                      (opcode[31] == 1'b1) ? 8'hff : 8'b0;
  assign imm[11] = (op == SBFORMAT) ? opcode[7] :
                   ((op == UFORMAT_LUI) || (op == UFORMAT_AUIPC)) ? 1'b0 :
                   (op == UJFORMAT) ? opcode[20] :
                   (macroLII1 || macroLII2 || macroLG) ? op2_imm[11] : opcode[31];
  assign imm[10:5] = ((op == UFORMAT_LUI) || (op == UFORMAT_AUIPC)) ? 6'b0 : 
                     (macroLII1 || macroLII2 || macroLG) ? op2_imm[10:5] : opcode[30:25];
  assign imm[4:1] = ((op == IFORMAT_ALU) || (op == IFORMAT_LOAD) || (op == IFORMAT_JALR) || (op == UJFORMAT)) ? opcode[24:21] :
		    ((op == SFORMAT) || (op == SBFORMAT)) ? opcode[11:8] : 
                    (macroLII1 || macroLII2 || macroLG) ? op2_imm[4:1] : 4'b0;
  assign imm[0] = ((op == IFORMAT_ALU) || (op == IFORMAT_LOAD) || (op == IFORMAT_JALR)) ? opcode[20] :
		  (op == SFORMAT) ? opcode[7] : 
                  (macroLII1 || macroLII2 || macroLG) ? op2_imm[0] : 1'b0;

  assign alucon = ((op == RFORMAT) || (op == MULDIV) || macroIL) ? {opcode[30], opcode[25], opcode[14:12]} :
                  ((op == IFORMAT_ALU) && (opcode[14:12] == 3'b101)) ? {opcode[30], opcode[25], opcode[14:12]} : // SRLI or SRAI
                  (op == IFORMAT_ALU) ? {2'b00, opcode[14:12]} : 5'b0;
  assign funct3 = (macroIL || macroLII2 || macroLG) ? op2_funct3 : 
                  opcode[14:12];
  assign op1sel = (macroLEA && (opcode[21:20] == 2'b10)) ? 2'b11 : (macroLEA && (opcode[21:20] == 2'b01)) ? 2'b10 :
                  ((op == SBFORMAT) || (op == UFORMAT_AUIPC) || (op == UJFORMAT) || macroLG) ? 2'b01 : 2'b00;
  assign op2sel = ((op == RFORMAT) || (op == MULDIV) || macroLEA || macroIL ) ? 1'b0 : 1'b1;
  assign mem_rw = (op == SFORMAT) ? 1'b1 : 1'b0;
  assign wb_sel = ((op == IFORMAT_LOAD) || macroIL || macroLII2 || macroLG) ? 2'b01 :
                  ((op == UJFORMAT) || (op == IFORMAT_JALR)) ? 2'b10 : 2'b00;
  assign rf_wen = (((op == RFORMAT) && ({opcode[31],opcode[29:25]} == 6'b000000)) ||
                   ((op == MULDIV) && ({opcode[31:25]} == 7'b000001)) ||
                   ((op == IFORMAT_ALU) && (({opcode[31:25], opcode[14:12]} == 10'b00000_00_001) || ({opcode[31], opcode[29:25], opcode[14:12]} == 9'b0_000_00_101) ||  // SLLI or SRLI or SRAI
                                            (opcode[14:12] == 3'b000) || (opcode[14:12] == 3'b010) || (opcode[14:12] == 3'b011) || (opcode[14:12] == 3'b100) || (opcode[14:12] == 3'b110) || (opcode[14:12] == 3'b111))) ||
                   (op == IFORMAT_LOAD) || (op == UFORMAT_LUI) || (op == UFORMAT_AUIPC) || (op == UJFORMAT) || (op == IFORMAT_JALR) ||
                   (op == MACROPFUSION1)) ? 1'b1 : 1'b0;
  assign pc_sel = (op == SBFORMAT) ? 2'b01 :
                  ((op == UJFORMAT) || (op == IFORMAT_JALR) || (op == ECALLEBREAK)) ? 2'b10 : 2'b00;

  // SELECTOR  
  wire [31:0] s_data1, s_data2;
  assign s_data1 = (op1sel == 2'b11) ? (r_data1 << 2) : (op1sel == 2'b10) ? (r_data1 << 1) : // LEA
                   (op1sel == 2'b01) ? pc : r_data1;
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

module RV32IM(input wire clock, input wire reset_n, output wire [31:0] pc_out, output wire [63:0] op_out, output wire [17:0] op2_out, output wire [63:0] alu_out, output wire [8:0] uart_out);
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

  localparam [6:0] MACROPFUSION1 = 7'b0001011;
  localparam [6:0] MACROPFUSION2 = 7'b0101011;

  // FETCH & PREDECODE
  wire [31:0] opcode1, opcode2;
  wire [17:0] opcode1_2, opcode2_2;
  wire [31:0] tmpopcode1, tmpopcode2;
  assign tmpopcode1 = {mem[pc + 3], mem[pc + 2], mem[pc + 1], mem[pc    ]};
  assign tmpopcode2 = {mem[pc + 7], mem[pc + 6], mem[pc + 5], mem[pc + 4]};

  wire [6:0] op1, op2;
  wire [4:0] regd1, regd2, reg1, reg2;
  wire [4:0] aluc1, aluc2;
  assign op1 = tmpopcode1[6:0];
  assign op2 = tmpopcode2[6:0];
  assign regd1 = tmpopcode1[11:7];
  assign regd2 = tmpopcode2[11:7];
  assign aluc1 = {tmpopcode1[30], tmpopcode1[25], tmpopcode1[14:12]};
  assign aluc2 = {tmpopcode2[30], tmpopcode2[25], tmpopcode2[14:12]};
  assign reg1 = tmpopcode2[19:15];
  assign reg2 = tmpopcode2[24:20];

  wire isBranch1;
  wire isBP1;
  wire isMemOp2; // MEMORY OPERATION RESTRICTED on dec_exec2
  wire isRegD;
  wire isReg1;
  wire isReg2;
  assign isBranch1 = (op1 == UJFORMAT) || (op1 == IFORMAT_JALR) || (op1 == ECALLEBREAK);
  assign isBP1 = (op1 == SBFORMAT);
  assign isMemOp2 = ((op1 == SFORMAT) && (op2 == IFORMAT_LOAD) && (tmpopcode1[14:12] != tmpopcode2[14:12])); // op1 MEMORY STORE & op2 MEMORY LOAD DEPENDANCY except sw & lw
  assign isRegD = (regd1 != 5'b0) &&
                  ((op1 == RFORMAT) || (op1 == IFORMAT_ALU) || (op1 == IFORMAT_LOAD) || (op1 == UFORMAT_LUI) || 
                   (op1 == UFORMAT_AUIPC) || (op1 == UJFORMAT) || (op1 == IFORMAT_JALR) || (op1 == MULDIV));
  assign isReg1 = (reg1 != 5'b0) &&
                  ((op2 == RFORMAT) || (op2 == IFORMAT_ALU) || (op2 == IFORMAT_LOAD) || (op2 == SFORMAT) || 
                   (op2 == SBFORMAT) || (op2 == IFORMAT_JALR) || (op2 == MULDIV));
  assign isReg2 = (reg2 != 5'b0) &&
                  ((op2 == RFORMAT) || (op2 == SFORMAT) || (op2 == SBFORMAT) || (op2 == MULDIV));

  wire isLEA; // Load Effective Address
  assign isLEA = (op1 == IFORMAT_ALU) && (aluc1[2:0] == 3'b001) && ((tmpopcode1[24:20] == 5'b00001) || (tmpopcode1[24:20] == 5'b00010)) && // first  slli 1 or 2
                 (op2 == RFORMAT) && (aluc2 == 5'b00000) && // second add
                 (regd1 != 5'b0) && (regd1 == reg1) && (regd1 == regd2); 
  wire isIL; // Indexed Load
  assign isIL = (op1 == RFORMAT) && // first RFORMAT
                (op2 == IFORMAT_LOAD) && (tmpopcode2[31:20] == 12'b0) && // second lb or lh or ld with imm = 0
                (regd1 != 5'b0) && (regd1 == reg1) && (regd1 == regd2);
  wire isLII1; // Load Immediate Idiom1
  assign isLII1 = (op1 == UFORMAT_LUI) &&  // first LUI
                  (op2 == IFORMAT_ALU) && (aluc2[2:0] == 3'b000) &&  // second addi
                  (regd1 != 5'b0) && (regd1 == regd2); 
  wire isLII2; // Load Immediate Idiom2
  assign isLII2 = (op1 == UFORMAT_LUI) && // first LUI
                  (op2 == IFORMAT_LOAD) && // second load
                  (regd1 != 5'b0) && (regd1 == reg1) && (regd1 == regd2);
  wire isLG; // Load Global
  assign isLG = (op1 == UFORMAT_AUIPC) && // first AUIPC
                  (op2 == IFORMAT_LOAD) && // second load
                  (regd1 != 5'b0) && (regd1 == reg1) && (regd1 == regd2);

  wire [31:0] mop_imm;
  assign mop_imm = {tmpopcode1[31:12], 12'b0} + {{20{tmpopcode2[31]}}, tmpopcode2[31:20]};
  wire mopfusion;
  assign mopfusion = (isLEA || isIL || isLII1 || isLII2 || isLG);
  wire superscalar;
  assign superscalar = (mopfusion || 
                        (isBranch1 != 1'b1) && (isMemOp2 != 1'b1) &&
                        ((isRegD != 1'b1) || 
                         (((isReg1 != 1'b1) || (regd1 != reg1)) &&
                          ((isReg2 != 1'b1) || (regd1 != reg2))))) ? 1'b1 : 1'b0;
  assign opcode1 = isLEA  ? {tmpopcode1[31:7], MACROPFUSION1} : // Load Effective Address
                   isIL   ? {tmpopcode1[31:7], MACROPFUSION1} : // Indexed Load
                   isLII1 ? {mop_imm[31:12], tmpopcode1[11:7], MACROPFUSION1} : // Load Immediate Idiom1
                   isLII2 ? {mop_imm[31:12], tmpopcode1[11:7], MACROPFUSION1} : // Load Immediate Idiom2
                   isLG   ? {mop_imm[31:12], tmpopcode1[11:7], MACROPFUSION1} : // Load Global
                   tmpopcode1;
  assign opcode1_2 = isLEA  ? {3'b0, 7'b0, reg2, 3'b010}: // Load Effective Address
                     isIL   ? {tmpopcode2[14:12], 12'b0, 3'b011} : // Indexed Load
                     isLII1 ? {3'b0, mop_imm[11:0], 3'b100} : // Load Immediate Idiom1
                     isLII2 ? {tmpopcode2[14:12], mop_imm[11:0], 3'b101} : // Load Immediate Idiom2
                     isLG   ? {tmpopcode2[14:12], mop_imm[11:0], 3'b110} : // Load Global
                     18'b0;
  assign opcode2 = ((mopfusion != 1'b1) && superscalar) ? tmpopcode2 : 32'b0;
  assign opcode2_2 = 18'b0;
  assign op_out = {opcode2, opcode1}; // for DEBUG
  assign op2_out = opcode1_2; // for DEBUG

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

  DECODE_EXEC dec_exe1(opcode1, pc, opcode1_2, r_addr1, r_addr2, w_addr, r_data1, r_data2, alu_data, mem_val, mem_rw, rf_wen, wb_sel, pc_sel2);

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

  DECODE_EXEC dec_exe2(opcode2, pc + 4, opcode2_2, r_addr1_2, r_addr2_2, w_addr_2, r_data1_2, r_data2_2, alu_data_2, mem_val_2, mem_rw_2, rf_wen_2, wb_sel_2, pc_sel2_2);

  assign alu_out = {alu_data_2, alu_data}; // for DEBUG

  // MEMORY 1
  wire [31:0] mem_data;
  wire [31:0] mem_addr;
  assign mem_addr = (mem_val == 3'b010) ? {alu_data[31:2], 2'b00} : 
                    (mem_val[1:0] == 2'b01) ? {alu_data[31:1], 1'b0} :
                    alu_data;
  
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
  assign mem_addr_2 = (mem_val_2 == 3'b010) ? {alu_data_2[31:2], 2'b00} : 
                      (mem_val_2[1:0] == 2'b01) ? {alu_data_2[31:1], 1'b0} :
                      alu_data_2;
  
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
  wire [31:0] mem_buf;
  assign mem_buf = ((opcode1[6:0] == SFORMAT) && (opcode2[6:0] == IFORMAT_LOAD) && (mem_val == mem_val_2) && (mem_addr == mem_addr_2)) ? 
                   (mem_val_2 == 3'b010) ? r_data2 :
                   (mem_val_2 == 3'b000) ? {{24{r_data2[7]}}, r_data2[7:0]} :
                   (mem_val_2 == 3'b100) ? {24'h00000, r_data2[7:0]} :
                   (mem_val_2 == 3'b001) ? {{16{r_data2[15]}}, r_data2[15:0]} :
                   (mem_val_2 == 3'b101) ? {16'h0000, r_data2[15:0]} :
                   mem_data_2 : mem_data_2;

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
    // MEMORY MAPPED IO to UART
    if ((mem_rw == 1'b1) && (mem_addr == UART_MMIO_ADDR))
      uart = {1'b1, r_data2[7:0]};
    else if ((mem_rw_2 == 1'b1) && (mem_addr_2 == UART_MMIO_ADDR) && !((isBP1 == 1'b1) && (pc_sel2 == 1'b1)))
      uart = {1'b1, r_data2_2[7:0]}; 
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
                    (wb_sel_2 == 2'b01) ? mem_buf :
                    (wb_sel_2 == 2'b10) ? pc + 8 : 32'b0; // ILLEGAL

  always @(posedge clock) begin
    if ((rf_wen   == 1'b1) && (w_addr   != 5'b00000))
      regs[w_addr  ] = w_data;
    if ((rf_wen_2 == 1'b1) && (w_addr_2 != 5'b00000) &&
        !((isBP1 == 1'b1) && (pc_sel2 == 1'b1))) // if not BRANCH
      regs[w_addr_2] = w_data_2;
  end

  // NEXT PC
  wire [31:0] next_pc;
  assign next_pc = (superscalar == 1'b1) ? ((isBP1 == 1'b1) && (pc_sel2 == 1'b1)) ? {alu_data  [31:1], 1'b0} : // BRANCH Prediction failed
                                           (pc_sel2_2 == 1'b1) ? {alu_data_2[31:1], 1'b0} : pc + 8 :
		                           (pc_sel2   == 1'b1) ? {alu_data  [31:1], 1'b0} : pc + 4; 

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
