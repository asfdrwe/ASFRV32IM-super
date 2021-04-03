.globl _start

_start:
  li x1, 0x7
  li x2, 0x2
  div x3, x1, x2
  rem x4, x1, x2
  add x5, x0, x3
  add x6, x0, x4
  divu x3, x1, x2
  remu x4, x1, x2
  add x5, x0, x3
  add x6, x0, x4
  li x1, 25
  li x2, 3
  div x3, x1, x2
  rem x4, x1, x2
  add x5, x0, x3
  add x6, x0, x4
  divu x3, x1, x2
  remu x4, x1, x2
  add x5, x0, x3
  add x6, x0, x4
  li x1, 3
  li x2, 25
  div x3, x1, x2
  rem x4, x1, x2
  add x5, x0, x3
  add x6, x0, x4
  divu x3, x1, x2
  remu x4, x1, x2
  add x5, x0, x3
  add x6, x0, x4
  li x1, 25
  li x2, -7
  div x3, x1, x2
  rem x4, x1, x2
  add x5, x0, x3
  add x6, x0, x4
  divu x3, x1, x2
  remu x4, x1, x2
  add x5, x0, x3
  add x6, x0, x4
  
_loop:
  jal x0, _loop
