# platform/qemu-virt.s - Platform driver for QEMU riscv32 "virt" machine
#
# Provides:
#   platform_putc  - transmit one character (arg in a0, clobbers t0/t1)
#   platform_getc  - receive one character (result in a0, clobbers t0/t1)
#   platform_halt  - terminate cleanly
#
# Also defines EMIT and KEY Forth words that call the above routines.
#
# Hardware:
#   UART: NS16550A-compatible at 0x10000000
#   Exit: QEMU sifive_test device at 0x100000 (write 0x5555 = PASS/exit 0)

    .include "forth.inc"

# -- Platform constants --------------------------------------------------------

.equ UART_BASE,      0x10000000
.equ UART_THR,       0           # Transmit Holding Register (write)
.equ UART_RBR,       0           # Receive Buffer Register (read)
.equ UART_LSR,       5           # Line Status Register (byte offset)
.equ UART_LSR_THRE,  0x20        # TX Holding Register Empty bit
.equ UART_LSR_DR,    0x01        # Data Ready (RX) bit

.equ QEMU_EXIT_ADDR, 0x100000    # sifive_test device
.equ QEMU_EXIT_PASS, 0x5555      # Write this to exit with code 0

# -- platform_putc -------------------------------------------------------------
# Transmit one character.
# In:  a0 = character to send
# Out: (none)
# Clobbers: t0, t1

    .text
    .balign CELL
    .globl  platform_putc
platform_putc:
    li      t0, UART_BASE
.Lwait_tx:
    lb      t1, UART_LSR(t0)
    andi    t1, t1, UART_LSR_THRE
    beqz    t1, .Lwait_tx
    sb      a0, UART_THR(t0)
    ret


# -- platform_getc -------------------------------------------------------------
# Receive one character, blocking until one is available.
# In:  (none)
# Out: a0 = character received
# Clobbers: t0, t1

    .balign CELL
    .globl  platform_getc
platform_getc:
    li      t0, UART_BASE
.Lwait_rx:
    lb      t1, UART_LSR(t0)
    andi    t1, t1, UART_LSR_DR
    beqz    t1, .Lwait_rx
    lb      a0, UART_RBR(t0)
    ret


# -- platform_halt -------------------------------------------------------------
# Terminate the program cleanly.
# Writes to QEMU's sifive_test device to signal a "pass" exit.

    .balign CELL
    .globl  platform_halt
    .globl  halt_code
platform_halt:
halt_code:
    li      t0, QEMU_EXIT_ADDR
    li      t1, QEMU_EXIT_PASS
    sw      t1, 0(t0)
1:  j       1b                  # spin; should never reach here


# -- EMIT ----------------------------------------------------------------------
#
# EMIT  ( char -- )
# Send the character on top of the data stack to the output device.

    defword "EMIT", EMIT, ZBRANCH_header
    lw      a0, 0(s3)           # a0 = char (low byte used by platform_putc)
    addi    s3, s3, 4           # pop DSP
    call    platform_putc
    NEXT


# -- KEY -----------------------------------------------------------------------
#
# KEY  ( -- char )
# Read one character from the input device and push it onto the data stack.

    defword "KEY", KEY, EMIT_header
    call    platform_getc
    addi    s3, s3, -4          # push DSP
    sw      a0, 0(s3)           # *DSP = char
    NEXT


# -- NOP -----------------------------------------------------------------------
# Temporary debugging word - remove once assembly-level debugging is done.

    defword "NOP", NOP, KEY_header
    nop
    NEXT
