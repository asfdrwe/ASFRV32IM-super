.globl _start

_start:
  li x1, 0x08
  li x2, 0xbeefa664
  sw x2, 0(x1)
  nop
  nop
  li x1, 0x0c
  li x2, 0x12345678
  sw x2, 0(x1)
  nop
  nop
  li x1, 0x02
  li x2, 0x04
  li x3, 0xff
  slli x3, x1, 1
  add x3, x3, x2
  lw x3, 0(x3)
  add x5, x0, x3
  add x5, x0, x3
  add x5, x0, x3
  slli x3, x1, 2
  add x3, x3, x2
  lw x3, 0(x3)
  add x5, x0, x3
  add x5, x0, x3
  add x5, x0, x3
  slli x3, x1, 3
  add x3, x3, x2
  lw x3, 0(x3)
  add x5, x0, x3
  slli x3, x1, 1
  add x3, x3, x2
  lw x3, 0(x3)
  add x5, x0, x3
  add x5, x0, x3
  add x5, x0, x3
  
_loop:
  jal x0, _loop
