.globl _start

_start:
  li x1, 0x2
  li x2, 0x5
  mulh x3, x1, x2
  mul x4, x1, x2
  add x5, x0, x3
  add x6, x0, x4
  mulhsu x3, x1, x2
  mul x4, x1, x2
  add x5, x0, x3
  add x6, x0, x4
  mulhu x3, x1, x2
  mul x4, x1, x2
  add x5, x0, x3
  add x6, x0, x4
  li x1, 0x1000
  li x2, 0xfabc1234
  mulh x3, x1, x2
  mul x4, x1, x2
  add x5, x0, x3
  add x6, x0, x4
  mulhsu x3, x1, x2
  mul x4, x1, x2
  add x5, x0, x3
  add x6, x0, x4
  mulhsu x3, x2, x1
  mul x4, x2, x1
  add x5, x0, x3
  add x6, x0, x4
  mulhu x3, x1, x2
  mul x4, x1, x2
  add x5, x0, x3
  add x6, x0, x4
  lui x1, 0x80000
  addi x1, x1, 0x123
  mulh x3, x1, x0
  mul x4, x1, x0
  add x5, x0, x3
  add x6, x0, x4
  mulhsu x3, x1, x0
  mul x4, x1, x0
  add x5, x0, x3
  add x6, x0, x4
  mulhu x3, x1, x0
  mul x4, x1, x0
  add x5, x0, x3
  add x6, x0, x4
  li x2, 0x5
  mulh x3, x1, x2
  mul x4, x1, x2
  add x5, x0, x3
  add x6, x0, x4
  mulhsu x3, x1, x2
  mul x4, x1, x2
  add x5, x0, x3
  add x6, x0, x4
  mulhsu x3, x2, x1
  mul x4, x2, x1
  add x5, x0, x3
  add x6, x0, x4
  mulh x3, x1, x2
  mul x4, x1, x2
  add x5, x0, x3
  add x6, x0, x4
  
  li x6, 0x6
  
  
_loop:
  jal x0, _loop
