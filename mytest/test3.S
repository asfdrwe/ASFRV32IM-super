.section .text

.global _start


_start:
  li sp, 0xff00
  la a0, hello
  li a1, 123
  li a2, 0x21
  jal debug_printf
_loop:
  j _loop

.section .rodata
hello:
  .string "hello %d, %d\n"
