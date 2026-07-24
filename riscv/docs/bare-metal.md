# Plan: Switch to Bare-Metal QEMU (No Docker, No Linux Syscalls)

## Motivation

The current setup runs as a Linux ELF binary under `qemu-riscv32` (user-mode QEMU),
which only works on Linux hosts. This forces everything into a Docker container on
macOS, which creates friction — especially for two-window debugging (GDB + live I/O).

Switching to bare-metal eliminates Docker entirely:
- QEMU system-mode (`qemu-system-riscv32`) runs natively on macOS
- GDB connects directly from a second terminal
- stdin/stdout map cleanly to the UART in window 1
- The kernel becomes portable to real hardware (Raspberry Pi Pico 2) with only
  a linker script and UART driver swap

## Target Machine

**QEMU `virt` machine** (`-machine virt`): a generic RISC-V virtual board with:
- A 16550-compatible UART at a fixed memory-mapped address
- RAM starting at `0x80000000`
- No firmware or bootloader required when loading an ELF directly via `-kernel`

The Pico 2's RISC-V core (Hazard3, RP2350) has a different memory map and a
different UART peripheral, but the Forth kernel itself is fully portable. Only the
linker script and UART driver need to change per target.

## What Changes

### Remove
- Docker entirely (no `Dockerfile`, no `docker run` wrappers in `Makefile`)
- All Linux syscall usage (`ecall` instructions for `write`, `read`, `exit`, `sigaction`)
- The ELF Linux ABI (`-mabi=ilp32` stays for the assembler, but the output is no
  longer a Linux ELF userspace binary)

### Add
- **Linker script** (`forth.ld`): places `.text` at `0x80000000`, defines stack top,
  provides `_start` at the reset vector
- **UART driver** (small section in `forth.s` or a new `uart.s`): memory-mapped I/O
  for the 16550 UART on the `virt` machine
- **Bare-metal exit**: replace the `exit` syscall with an infinite loop or a write to
  QEMU's power-off register (via the `virt` machine's test device at `0x100000`)

### Modify
- `EMIT`: replace `SYS_write` ecall with a UART transmit routine
- `KEY`: replace `SYS_read` ecall with a UART receive (polling) routine
- `Makefile`: remove Docker wrappers, add native QEMU system-mode targets

## Linker Script Sketch (`forth.ld`)

```ld
OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 128M
}

SECTIONS
{
    . = 0x80000000;

    .text : { *(.text*) } > RAM
    .rodata : { *(.rodata*) } > RAM
    .bss (NOLOAD) : { *(.bss*) } > RAM

    _end = .;
}
```

## UART Driver Sketch

The `virt` machine's 16550 UART is at base address `0x10000000`.

```asm
.equ UART_BASE,  0x10000000
.equ UART_THR,   0           # Transmit Holding Register (write)
.equ UART_RBR,   0           # Receive Buffer Register (read)
.equ UART_LSR,   5           # Line Status Register
.equ UART_LSR_THRE, 0x20     # Transmit Holding Register Empty bit
.equ UART_LSR_DR,   0x01     # Data Ready bit

# uart_putc: send character in a0, clobbers t0/t1
uart_putc:
    li      t0, UART_BASE
.Lwait_tx:
    lb      t1, UART_LSR(t0)
    andi    t1, t1, UART_LSR_THRE
    beqz    t1, .Lwait_tx
    sb      a0, UART_THR(t0)
    ret

# uart_getc: receive character into a0, blocks until ready, clobbers t0/t1
uart_getc:
    li      t0, UART_BASE
.Lwait_rx:
    lb      t1, UART_LSR(t0)
    andi    t1, t1, UART_LSR_DR
    beqz    t1, .Lwait_rx
    lb      a0, UART_RBR(t0)
    ret
```

`EMIT` calls `uart_putc`, `KEY` calls `uart_getc`. No scratch buffer needed.

## Clean Exit

Replace the `exit` syscall in `halt_code` with a write to QEMU's test/power device:

```asm
.equ QEMU_EXIT_ADDR, 0x100000
.equ QEMU_EXIT_PASS, 0x5555     # QEMU virt "pass" exit code

halt_code:
    li      t0, QEMU_EXIT_ADDR
    li      t1, QEMU_EXIT_PASS
    sw      t1, 0(t0)
    # Should not reach here; spin just in case
1:  j       1b
```

## New Makefile Targets

```makefile
AS      := riscv64-linux-gnu-as
LD      := riscv64-linux-gnu-ld
GDB     := gdb-multiarch
QEMU    := qemu-system-riscv32

ASFLAGS := -march=rv32i -mabi=ilp32 -g
LDFLAGS := -m elf32lriscv -T forth.ld --no-relax

GDB_PORT := 1234
QEMU_FLAGS := -machine virt -nographic -bios none -kernel forth.elf

# Build
all: forth.elf

forth.elf: $(OBJS)
	$(LD) $(LDFLAGS) -o $@ $^

# Run (window 1: I/O appears here)
run: forth.elf
	$(QEMU) $(QEMU_FLAGS)

# Run with GDB stub, waiting for connection (window 1)
qemu-wait: forth.elf
	$(QEMU) $(QEMU_FLAGS) -s -S

# Connect GDB to waiting QEMU (window 2)
gdb-attach: forth.elf
	$(GDB) -q \
	    -ex "set architecture riscv:rv32" \
	    -ex "target remote :$(GDB_PORT)" \
	    forth.elf
```

Two-window workflow:
1. Terminal 1: `make qemu-wait` — QEMU starts, halts, waits; UART I/O is here
2. Terminal 2: `make gdb-attach` — GDB connects; set breakpoints, then `continue`

## BLOCK Words Instead of INCLUDE-FILE

Rather than implementing `INCLUDE-FILE` (which requires filesystem syscalls), the
Forth source library is assembled directly into read-only memory as 1KB blocks
following the ANS Forth BLOCK word set.

- A script (e.g. `tools/mkblocks.py`) reads `.fth` source files and emits an
  assembly file (`blocks.s`) containing `.rodata` data with the block contents
  padded to 1024 bytes each
- `blocks.s` is assembled and linked alongside `forth.s`
- The Forth words `BLOCK`, `LOAD`, etc. index into this read-only region by block
  number; no file I/O required
- On the Pico 2, the same block data lives in flash; the Forth kernel is identical

This replaces step 10 (File I/O and `INCLUDE-FILE`) entirely.

## Migration Path

The kernel steps completed so far (1–7) do not need to be redone. The migration is
a configuration and I/O change, not a kernel rewrite. Suggested order:

1. Write `forth.ld` and verify the binary links and loads under QEMU system-mode
2. Add `uart_putc` / `uart_getc` and update `EMIT` and `KEY`
3. Update `halt_code` to use the QEMU power-off device
4. Rewrite the `Makefile` to remove Docker; verify `make run` and two-window debug
5. Delete the `Dockerfile` and Docker-related infrastructure
6. Continue with step 8 (dictionary) onwards on the new substrate
7. Write `tools/mkblocks.py` and implement `BLOCK`/`LOAD` in place of step 10

## References

- [QEMU `virt` machine documentation](https://www.qemu.org/docs/master/system/riscv/virt.html)
- [16550 UART programming](https://en.wikibooks.org/wiki/Serial_Programming/8250_UART_Programming)
- [RP2350 datasheet](https://datasheets.raspberrypi.com/rp2350/rp2350-datasheet.pdf) — for eventual Pico 2 port
- [ANS Forth BLOCK word set](https://forth-standard.org/standard/block)
