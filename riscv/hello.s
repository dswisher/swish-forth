# hello.s - Hello World for RISC-V 32-bit Linux
#
# Linux syscall convention (RV32):
#   a7 = syscall number
#   a0 = arg1, a1 = arg2, a2 = arg3
#   ecall
#
# Syscalls used:
#   write(fd, buf, len)  = 64
#   exit(code)           = 93

    .section .data

msg:
    .string "Hello, Forth!\n"
msg_len = . - msg

    .section .text
    .globl _start

_start:
    # write(stdout, msg, msg_len)
    li      a7, 64              # syscall: write
    li      a0, 1               # fd: stdout
    la      a1, msg             # buf: address of message
    li      a2, msg_len         # len: length of message
    ecall

    # exit(0)
    li      a7, 93              # syscall: exit
    li      a0, 0               # exit code: 0
    ecall
