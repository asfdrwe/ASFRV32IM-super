module RV32IM_test;
  reg clock = 1'b0;
  reg reset_n = 1'b0;
  wire [31:0] pc_out;
  wire [63:0] op_out, alu_out;
  wire [17:0] op2_out;
  wire [8:0] uart_out;
  
  RV32IM rv1(clock, reset_n, pc_out, op_out, op2_out, alu_out, uart_out);

  initial begin
    $dumpfile("RV32IM.vcd");
    $dumpvars(0, RV32IM_test);
    $monitor("%t: PC = %h, OPCODE = %h, OPCODE2 = %h, ALU_DATA = %h, UART = %h",
             $time, pc_out, op_out, op2_out, alu_out, uart_out[7:0]);
  end

  initial begin
    clock = 1'b0;
    forever begin
      #1 clock = ~clock;
    end
  end

  initial begin
    reset_n = 1'b0;

    #1 reset_n = 1'b1;
    #10000 $finish;
  end

endmodule
