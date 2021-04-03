.global _start

_start:
  li a1, 0xfff0
  li a2, 0x61
  sb a2, (a1)
  nop
  nop
  li a2, 'G'
  sb a2, (a1)
  nop
  nop
  li a2, '\n'
  sb a2, (a1)
_loop:
  j _loop
