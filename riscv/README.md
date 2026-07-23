# swish-forth: RISC-V

A FORTH kernel built from scratch in RISC-V 32-bit assembly, targeting a
Linux userspace environment via QEMU. This is a continuation of the 6502
work in the sibling directory, restarted on a more ergonomic architecture
with better debugging tooling.

## Goals

- Implement a minimal FORTH kernel in RISC-V 32-bit assembly
- Get to self-hosting quickly: implement a small assembly core, then write
  the rest of the kernel in FORTH itself (e.g., `INTERPRET` as a FORTH word)
- Load FORTH source files from disk so the host editor (Neovim) can be used
  directly, with no copy step
- Use a consistent development environment across Mac, Windows, and Linux

## Key Decisions

### Architecture: RISC-V 32-bit

Chosen over 6502 (too few registers, weak debugger), 68000 (good registers,
but weak emulator/debugger tooling), and ARM32 (knowledge doesn't transfer
to Apple Silicon AArch64 anyway). RISC-V 32-bit offers:

- A clean, regular ISA: fixed 32-bit instruction width, 32 registers, no
  condition codes, no mode switching
- The same register richness as 68000 without its quirks
- First-class GDB support via QEMU's GDB remote stub

### No bare-metal: Linux syscalls

Rather than implementing UART and filesystem drivers on bare-metal, the
kernel runs as a Linux process and uses Linux syscalls for all I/O:

- Console input/output: `read` (syscall 63) and `write` (syscall 64)
- File I/O: `open`/`read`/`close` for loading FORTH source files
- `exit` (syscall 93) for clean termination

This means zero driver code — all effort goes into FORTH, not hardware.
This is the same approach used by the well-known
[jonesforth](https://github.com/nornagon/jonesforth) kernel (which targets
x86 Linux).

### Development environment: Docker + Ubuntu 24.04

QEMU user-mode emulation (`qemu-riscv32`) only works on Linux hosts, not
macOS. To get a consistent environment across Mac, Windows, and Linux,
everything runs inside a Docker container:

- **Image:** Ubuntu 24.04 (Alpine lacks the required cross-toolchain packages)
- **Toolchain:** `binutils-riscv64-linux-gnu` + `gcc-riscv64-linux-gnu`
  (the `riscv64` prefix is misleading — these tools emit 32-bit code when
  passed `-march=rv32i -mabi=ilp32`)
- **Emulator:** `qemu-user` (provides `qemu-riscv32`)
- **Debugger:** `gdb-multiarch`

Source files are mounted from the host into the container at `/work`, so
Neovim on the host edits the same files that are assembled and run inside
the container.

### Debugging: QEMU GDB stub

GDB connects to QEMU's built-in GDB remote stub rather than attaching to
a local process (which would require ptrace permissions):

```sh
# Terminal 1
qemu-riscv32 -g 1234 ./forth

# Terminal 2
gdb-multiarch -ex "set arch riscv:rv32" -ex "target remote :1234" ./forth
```

`make debug` automates both steps in a single container session.

## Toolchain

| Tool | Package | Purpose |
|------|---------|---------|
| `riscv64-linux-gnu-as` | `binutils-riscv64-linux-gnu` | Assembler |
| `riscv64-linux-gnu-ld` | `binutils-riscv64-linux-gnu` | Linker |
| `qemu-riscv32` | `qemu-user` | Run RV32 Linux ELF binaries |
| `gdb-multiarch` | `gdb-multiarch` | Debugger |

## Make Targets

| Target | Description |
|--------|-------------|
| `make image` | Build the Docker image (run once, or after Dockerfile changes) |
| `make` | Assemble and link |
| `make run` | Run the binary under QEMU |
| `make debug` | Run under QEMU with GDB stub and launch GDB |
| `make shell` | Open a bash shell in the container |
| `make clean` | Remove build artifacts |

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
| 8 | Dictionary structure, `:` and `;` | [step-08.md](docs/step-08.md) |
| 9 | Outer interpreter: number parsing and word lookup | [step-09.md](docs/step-09.md) |
| 10 | File I/O and `INCLUDE-FILE` | [step-10.md](docs/step-10.md) |
| 11 | Core word set in Forth source files | [step-11.md](docs/step-11.md) |

## References

- [jonesforth](https://github.com/nornagon/jonesforth) - A complete FORTH
  kernel in x86 Linux assembly with extensive explanatory comments; the
  primary conceptual reference for this project
- [RISC-V ISA Specification](https://riscv.org/technical/specifications/) -
  Official ISA reference
- [RISC-V Cheat Sheet](https://projectf.io/posts/riscv-cheat-sheet/)
- [Linux RISC-V syscall table](https://jborza.com/post/2021-05-11-riscv-linux-syscalls/) -
  Syscall numbers and calling convention
- [GDB Cheat Sheet](https://github.com/reveng007/GDB-Cheat-Sheet)
- [Forth-2012 Standard](https://forth-standard.org/standard/words) - the implementation target
- *Threaded Interpretive Languages* by R. G. Loeliger - low-level FORTH
  implementation detail
- [*Starting FORTH*](https://www.forth.com/wp-content/uploads/2018/01/Starting-FORTH.pdf)
  by Leo Brodie - the classic FORTH introduction
