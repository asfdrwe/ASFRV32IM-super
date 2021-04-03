.globl _start

_start:
  li x1, 0x10
  li x2, 0x05
  li x5, 0x322a0a
  li x3, 0x30a
  li x4, 0x3a
  lui x6, 0x0300
  addi x6, x6, 0xfb
  li x1, 0x12
  li x6, 0x322a0a
  li x1, 0x12
  li x7, 0xa12a0a
  li x1, 0x1
  li x2, 0x2
  li x3, 0x3
  li x4, 0x4
  slli x3, x1, 1
  add x3, x3, x2
  slli x3, x1, 2
  add x3, x3, x2
  li x1, 0x8
  li x2, 0x4
  add x3, x1, x2
  lw x3, 0(x3)
  add x5, x0, x3
  li x5, 0x5
  sub x3, x1, x2
  lb x3, 0(x3)
  add x5, x0, x3
  li x5, 0x5
  lui x3, 0x00000
  lw x3, 4(x3)
  add x5, x0, x3
  li x5, 0x5
  auipc x3, 0x00000
  lw x3, -4(x3)
  add x5, x0, x3
  li x5, 0x5
  auipc x3, 0x00001
  lw x3, -200(x3)
  add x5, x0, x3
  li x5, 0x5
  
_loop:
  jal x0, _loop
