IVERILOG = iverilog

PROGRAM = RV32IM-3bp
SRC = RV32IM-3bp.v
SRC_TEST = ../RV32IM-testbench/RV32IM-3_test.v
PROGRAM_UART = RV32IM-3bp_uart
SRC_UART_TEST = ../RV32IM-testbench/RV32IM-3_uart_test.v
PROGRAM_COREMARK = RV32IM-3bp_coremark
SRC_COREMARK_TEST = ../RV32IM-testbench/RV32IM-3_coremark_test.v

PROG = $(PROGRAM) $(PROGRAM_UART) $(PROGRAM_COREMARK)

all: $(PROG)

$(PROGRAM): $(SRC) $(SRC_TEST)
	$(IVERILOG) -o $(PROGRAM) $(SRC) $(SRC_TEST)
$(PROGRAM_UART): $(SRC) $(SRC_UART_TEST)
	$(IVERILOG) -o $(PROGRAM_UART) $(SRC) $(SRC_UART_TEST)
$(PROGRAM_COREMARK): $(SRC) $(SRC_COREMARK_TEST)
	$(IVERILOG) -o $(PROGRAM_COREMARK) $(SRC) $(SRC_COREMARK_TEST)
	
clean:
	rm -f $(PROG)
