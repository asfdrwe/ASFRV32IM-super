.globl _start

_start:
  li x1, 0x0
  lw x2, 0(x1)
  lw x3, 4(x1)
  addi x0, x2, 0
  addi x0, x3, 0
  li x1, 0x4
  lw x2, 4(x1)
  lw x3, 8(x1)
  addi x0, x2, 0
  addi x0, x3, 0
  li x1, 0x100
  li x2, 0x11ffaa99
  li x3, 0xbb883322
  sw x2, 0(x1)
  sw x3, 4(x1)
  lw x4, 0(x1)
  lw x5, 4(x1)
  addi x0, x4, 0
  addi x0, x5, 0
  sw x2, 4(x1)
  sw x3, 0(x1)
  lw x4, 4(x1)
  lw x5, 0(x1)
  addi x0, x4, 0
  addi x0, x5, 0
  lw x6, 0(x1)
  addi x1, x1, 4
  addi x0, x1, 0
  
  
  
_loop:
  jal x0, _loop
