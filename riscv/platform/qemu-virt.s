# platform/qemu-virt.s - Platform driver for QEMU riscv32 "virt" machine
#
# Provides:
#   platform_init  - initialise UART
#   platform_putc  - transmit one character (arg in a0, clobbers t0/t1)
#   platform_getc  - receive one character (result in a0, clobbers t0/t1)
#   halt_code      - terminate cleanly
#
# Hardware:
#   UART: NS16550A-compatible at 0x10000000
#   Exit: QEMU sifive_test device at 0x100000 (write 0x5555 = PASS/exit 0)

# -- Platform constants --------------------------------------------------------

.equ UART_BASE,      0x10000000
.equ UART_THR,       0           # Transmit Holding Register (write)
.equ UART_RBR,       0           # Receive Buffer Register (read)
.equ UART_LSR,       5           # Line Status Register (byte offset)
.equ UART_LSR_THRE,  0x20        # TX Holding Register Empty bit
.equ UART_LSR_DR,    0x01        # Data Ready (RX) bit

.equ QEMU_EXIT_ADDR, 0x100000    # sifive_test device
.equ QEMU_EXIT_PASS, 0x5555      # Write this to exit with code 0

# -- platform_init --------------------------------------------------------------
# Initialise the UART for I/O.
# Clobbers: t0, t1

    .text
    .balign 4
    .globl  platform_init
platform_init:
    li      t0, UART_BASE
    li      t1, 0x03
    sb      t1, 3(t0)            # LCR = 3 (8 data bits, 1 stop bit, no parity)
    ret

# -- platform_putc -------------------------------------------------------------
# Transmit one character.
# In:  a0 = character to send
# Out: (none)
# Clobbers: t0, t1

    .text
    .balign 4
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

    .balign 4
    .globl  platform_getc
platform_getc:
    li      t0, UART_BASE
.Lwait_rx:
    lb      t1, UART_LSR(t0)
    andi    t1, t1, UART_LSR_DR
    beqz    t1, .Lwait_rx
    lb      a0, UART_RBR(t0)
    ret


# -- halt_code -----------------------------------------------------------------
# Terminate the program cleanly.
# Writes to QEMU's sifive_test device to signal a "pass" exit.

    .balign 4
    .globl  halt_code
halt_code:
    li      t0, QEMU_EXIT_ADDR
    li      t1, QEMU_EXIT_PASS
    sw      t1, 0(t0)
1:  j       1b                  # spin; should never reach here
