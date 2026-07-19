# swish-forth

A FORTH kernel built from scratch in 6502 assembly, targeting the
[Commander X16](https://www.commanderx16.com/) platform.

This project is structured as a self-guided course: each lesson introduces
new concepts, implemented first in assembly and then extended in FORTH itself.
The goal is not just a working FORTH, but a deep understanding of how FORTH
works at the hardware level.

## Goals

- Implement a minimal FORTH kernel in 6502 assembly
- Extend the kernel using FORTH words loaded from source files
- Use the Commander X16 as the target platform (real hardware or emulator)
- Keep the assembly kernel as small as possible - get to self-hosting quickly
- Structure the work so the kernel can later be ported to other processors
  (Z80, 68000, etc.) while reusing the FORTH-level code

## Approach

The kernel is built in layers:

1. **Assembly primitives** - the smallest possible set of words needed to
   bootstrap the system (`NEXT`, `DOCOL`, `EXIT`, stack ops, arithmetic, I/O)
2. **Inner interpreter** - the threading engine that drives execution
3. **Outer interpreter** - reads input, looks up words, parses numbers
4. **Self-extension** - once the outer interpreter works, load the rest from
   `.forth` source files edited on the host machine

The threading model is **indirect-threaded code (ITC)**, a classic and
well-documented approach that maps cleanly to the 6502.

## Toolchain

| Tool | Purpose |
|------|---------|
| [ca65](https://cc65.github.io/doc/ca65.html) | 6502 cross-assembler |
| [ld65](https://cc65.github.io/doc/ld65.html) | Linker (part of cc65) |
| [Commander X16 Emulator](https://github.com/X16Community/x16-emulator) | Target platform emulator |
| Neovim | Editor |
| zsh | Shell / build scripting |

See [docs/setup.md](docs/setup.md) for installation instructions.

## Labs

| Lab | Topic |
|-----|-------|
| [01](docs/lab-01.md) | Hello, X16 - toolchain and first assembly program |
| [02](docs/lab-02.md) | Memory map and threading model |
| [03](docs/lab-03.md) | The inner interpreter: NEXT and the threading engine |
| [04](docs/lab-04.md) | Colon definitions: DOCOL and EXIT |
| [05](docs/lab-05.md) | Primitive words: stack ops, arithmetic, memory access |
| 06 | The dictionary and FIND *(coming soon)* |
| 07 | The outer interpreter: INTERPRET, number parsing, the FORTH prompt *(coming soon)* |

## References

- [jonesforth](https://github.com/nornagon/jonesforth) - A well-commented FORTH
  in x86 assembly; excellent conceptual reference
- [6502.org source code library](http://www.6502.org/source/) - includes FIG FORTH kernel and other 6502 FORTH resources
- [Commander X16 documentation](https://github.com/X16Community/x16-docs)
- [*Starting FORTH*](https://www.forth.com/wp-content/uploads/2018/01/Starting-FORTH.pdf) by Leo Brodie - the classic FORTH introduction
- *Threaded Interpretive Languages* by R. G. Loeliger - low-level implementation detail
