# Bare-Metal Migration Notes

## Why Bare-Metal?

The original setup ran as a Linux ELF binary under `qemu-riscv32` (user-mode
QEMU), which only works on Linux hosts. This forced everything into a Docker
container on macOS, creating friction — especially for two-window debugging
(GDB in one terminal, live UART I/O in the other).

Switching to bare-metal eliminated Docker entirely:
- `qemu-system-riscv32` runs natively on macOS
- GDB connects directly from a second terminal
- UART I/O maps cleanly to the terminal running QEMU
- The kernel is portable to real hardware by swapping only the linker script
  and platform driver

## What Was Done

### New files

| File | Purpose |
|------|---------|
| `forth.ld` | Linker script: places code at `0x80000000` (QEMU `virt` RAM base) |
| `platform/qemu-virt.s` | UART driver, `EMIT`, `KEY`, `NOP`, `halt_code` |

### Modified files

| File | Change |
|------|--------|
| `forth.s` | Removed Linux syscalls (`ecall`), `emit_buf`, `EMIT`, `NOP`; added comment pointing to `platform/` |
| `forth.inc` | Added `.globl` directives to `defword` macro so `_header`, `_cfa`, `_code` labels are visible across translation units |
| `Makefile` | Removed Docker; native bare-metal build using `riscv64-elf-*` toolchain and `qemu-system-riscv32` |
| `README.md` | Updated toolchain, make targets, and key decisions sections |

### Removed

- Docker (`Dockerfile`, `docker run` wrappers in Makefile)
- Linux syscalls for `write`, `read`, `exit`
- `emit_buf` scratch buffer (no longer needed — UART driver takes the char directly)

## Platform Abstraction

Each platform file provides:

| Symbol | Description |
|--------|-------------|
| `platform_putc` | Transmit one character (arg in `a0`) |
| `platform_getc` | Receive one character (result in `a0`), blocking |
| `halt_code` / `platform_halt` | Terminate cleanly |
| `EMIT` Forth word | Calls `platform_putc` |
| `KEY` Forth word | Calls `platform_getc` |
| `NOP` Forth word | Debugging breakpoint target |

The kernel (`forth.s`) references `EMIT_cfa`, `NOP_cfa`, and `halt_code` by
name; the linker resolves them from whichever platform file is included in
the build. To add a new platform, create `platform/<name>.s` providing those
symbols and set `PLATFORM=<name>` when invoking make.

## QEMU `virt` Machine Details

| Resource | Address | Notes |
|----------|---------|-------|
| RAM | `0x80000000` | 128 MB; kernel loaded here |
| UART (NS16550A) | `0x10000000` | `-nographic` wires this to the terminal |
| sifive_test device | `0x100000` | Write `0x5555` for clean exit (PASS) |

## Two-Window Debug Workflow

No spin-loop required. QEMU system-mode halts before the first instruction
when launched with `-S`, so GDB connects before any code runs.

```sh
# Terminal 1 — program output (UART) appears here
make qemu-wait

# Terminal 2 — full GDB control
make gdb-attach
# then: set more breakpoints if desired, then 'continue'
```

## BLOCK Words (Future: replaces INCLUDE-FILE)

Rather than implementing filesystem syscalls, Forth source files will be
assembled into read-only memory as 1 KB blocks following the ANS Forth BLOCK
word set. A script (`tools/mkblocks.py`, not yet written) will read `.fth`
source files and emit an assembly file with the block contents padded to
1024 bytes each.

- `BLOCK` ( u -- addr ): return address of block u in the read-only region
- `LOAD` ( u -- ): interpret block u
- On the Pico 2, the same block data lives in flash; the kernel is identical

This replaces step 10 (originally "File I/O and INCLUDE-FILE").

## Eventual Pico 2 Port

The Raspberry Pi Pico 2 (RP2350) has RISC-V Hazard3 cores. To port:

1. Write `platform/pico2.s` with the RP2350 UART driver (PL011 peripheral)
2. Write `pico2.ld` placing `.text` in flash (`0x10000000`) and `.bss` in RAM (`0x20000000`)
3. `make PLATFORM=pico2` (and use the Pico SDK or `picotool` to flash)

The kernel (`forth.s`, `forth.inc`) requires no changes.

## References

- [QEMU `virt` machine documentation](https://www.qemu.org/docs/master/system/riscv/virt.html)
- [NS16550A UART programming](https://en.wikibooks.org/wiki/Serial_Programming/8250_UART_Programming)
- [RP2350 datasheet](https://datasheets.raspberrypi.com/rp2350/rp2350-datasheet.pdf)
- [ANS Forth BLOCK word set](https://forth-standard.org/standard/block)
