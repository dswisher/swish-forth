# swish-forth: RISC-V

A FORTH kernel built from scratch in RISC-V 32-bit assembly, targeting
bare-metal via QEMU system-mode. This is a continuation of the 6502 work
in the sibling directory, restarted on a more ergonomic architecture with
better debugging tooling.

## Goals

- Implement a minimal FORTH kernel in RISC-V 32-bit assembly
- Get to self-hosting quickly: implement a small assembly core, then write
  the rest of the kernel in FORTH itself (e.g., `INTERPRET` as a FORTH word)
- Keep the kernel platform-independent; swap only a small driver file to
  target different hardware (QEMU `virt`, Raspberry Pi Pico 2, etc.)
- Use a native macOS toolchain — no Docker required

## Key Decisions

### Architecture: RISC-V 32-bit

Chosen over 6502 (too few registers, weak debugger), 68000 (good registers,
but weak emulator/debugger tooling), and ARM32 (knowledge doesn't transfer
to Apple Silicon AArch64 anyway). RISC-V 32-bit offers:

- A clean, regular ISA: fixed 32-bit instruction width, 32 registers, no
  condition codes, no mode switching
- The same register richness as 68000 without its quirks
- First-class GDB support via QEMU's GDB remote stub

### Bare-metal: no Linux syscalls

The kernel runs on bare hardware (or QEMU system-mode emulation) with no
OS underneath. All I/O is done via memory-mapped UART registers. This
approach:

- Eliminates Docker — the native macOS toolchain works directly
- Makes the kernel portable to real hardware with only a linker script and
  driver file swap
- Enables clean two-window debugging (UART I/O in one terminal, GDB in the
  other) without container boundary issues

See [docs/bare-metal.md](docs/bare-metal.md) for the full rationale and
migration notes.

### Platform abstraction

Platform-specific code lives in `platform/<name>.s`:

| File | Target |
|------|--------|
| `platform/qemu-virt.s` | QEMU `virt` machine (development) |
| `platform/pico2.s` | Raspberry Pi Pico 2 / RP2350 (future) |

Each platform file provides `platform_putc`, `platform_getc`, `halt_code`,
and the `EMIT`, `KEY`, `NOP` Forth words. `forth.s` and `forth.inc` are
platform-independent.

### BLOCK words instead of INCLUDE-FILE

Rather than implementing filesystem syscalls, Forth source files will be
assembled into read-only memory blocks (ANS Forth BLOCK word set). A small
script generates the assembly from `.fth` source files. This works
identically on QEMU and on real hardware where source lives in flash.

### Debugging: QEMU GDB stub

Two-terminal workflow — no spin-loop tricks needed. QEMU system-mode halts
before the first instruction when launched with `-S`:

```sh
# Terminal 1 (I/O appears here)
make qemu-wait

# Terminal 2
make gdb-attach
```

QEMU blocks waiting for GDB, so there is no race condition.

## Toolchain

Install once via Homebrew:

```sh
brew install riscv64-elf-binutils riscv64-elf-gdb qemu
```

| Tool | Homebrew package | Purpose |
|------|-----------------|---------|
| `riscv64-elf-as` | `riscv64-elf-binutils` | Assembler |
| `riscv64-elf-ld` | `riscv64-elf-binutils` | Linker |
| `riscv64-elf-objdump` | `riscv64-elf-binutils` | Disassembler |
| `riscv64-elf-gdb` | `riscv64-elf-gdb` | Debugger |
| `qemu-system-riscv32` | `qemu` | System-mode emulator |

## Make Targets

| Target | Description |
|--------|-------------|
| `make` | Assemble and link |
| `make run` | Run under QEMU (Ctrl-A X to exit) |
| `make qemu-wait` | Run under QEMU, halted, waiting for GDB (window 1) |
| `make gdb-attach` | Connect GDB to a waiting QEMU instance (window 2) |
| `make disasm` | Disassemble the binary |
| `make clean` | Remove build artifacts |

## File Layout

```
forth.s              - Platform-independent kernel
forth.inc            - Register assignments, NEXT macro, defword macro
forth.ld             - Linker script (QEMU virt / bare-metal)
platform/
  qemu-virt.s        - UART driver + EMIT/KEY/NOP for QEMU virt machine
Makefile
docs/
  step-NN.md         - Per-step design notes
  bare-metal.md      - Rationale and notes for the bare-metal migration
```

## Implementation Outline

The kernel is built in small, verifiable steps. Each step has a dedicated
doc file with design details and implementation notes.

| Step | Topic | Doc |
|------|-------|-----|
| 1 | Register definitions and memory layout | [step-01.md](docs/step-01.md) |
| 2 | Stack initialization | [step-02.md](docs/step-02.md) |
| 3 | `NEXT` macro and `EXIT` | [step-03.md](docs/step-03.md) |
| 4 | Stack primitives: `DUP`, `DROP`, `SWAP`, `OVER` | [step-04.md](docs/step-04.md) |
| 5 | `LIT`, `BRANCH`, `0BRANCH` | [step-05.md](docs/step-05.md) |
| 6 | `DOCOL` and hand-threaded test | [step-06.md](docs/step-06.md) |
| 7 | `EMIT` and `KEY` | [step-07.md](docs/step-07.md) |
| 8 | Input buffer, `>IN`, `PARSE-NAME` | [step-08.md](docs/step-08.md) |
| 9 | Dictionary structure, `CREATE`, `:`, `;` | [step-09.md](docs/step-09.md) |
| 10 | Outer interpreter: `FIND`, `NUMBER`, `EXECUTE` | [step-10.md](docs/step-10.md) |
| 11 | `BLOCK` and `LOAD` (replaces file I/O) | [step-11.md](docs/step-11.md) |
| 12 | Core word set in Forth source files | [step-12.md](docs/step-12.md) |

## References

- [jonesforth](https://github.com/nornagon/jonesforth) - A complete FORTH
  kernel in x86 Linux assembly with extensive explanatory comments; the
  primary conceptual reference for this project
- [RISC-V ISA Specification](https://riscv.org/technical/specifications/) -
  Official ISA reference
- [RISC-V Cheat Sheet](https://projectf.io/posts/riscv-cheat-sheet/)
- [QEMU virt machine](https://www.qemu.org/docs/master/system/riscv/virt.html) -
  Memory map and peripheral addresses
- [GDB Cheat Sheet](https://github.com/reveng007/GDB-Cheat-Sheet)
- [Forth-2012 Standard](https://forth-standard.org/standard/words) - the implementation target
- *Threaded Interpretive Languages* by R. G. Loeliger - low-level FORTH
  implementation detail
- [*Starting FORTH*](https://www.forth.com/wp-content/uploads/2018/01/Starting-FORTH.pdf)
  by Leo Brodie - the classic FORTH introduction
- [RP2350 datasheet](https://datasheets.raspberrypi.com/rp2350/rp2350-datasheet.pdf) -
  For the eventual Raspberry Pi Pico 2 port
