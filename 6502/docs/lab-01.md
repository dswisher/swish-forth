# Lab 1: Hello, X16

## Objectives

- Install and verify the toolchain (ca65, ld65, x16emu)
- Write a minimal 6502 assembly program
- Assemble and link it into an X16-compatible binary
- Run it in the Commander X16 emulator

## Prerequisites

- Toolchain installed per [setup.md](setup.md)
- Basic familiarity with 6502 assembly concepts (registers, addressing modes,
  JSR/RTS). If you need a refresher, the
  [Easy 6502](https://skilldrick.github.io/easy6502/) tutorial is a good
  quick read. The [6502 instruction reference](https://www.masswerk.at/6502/6502_instruction_set.html)
  is useful to keep open as a reference.

---

## Background

### How the X16 Boots

When the X16 starts, it runs a BASIC interpreter stored in ROM. For our
purposes we want to run our own machine code instead. The standard way to do
this on the X16 is to produce a **PRG file** - the same binary format used by
Commodore 64 programs.

A PRG file is simple: the first two bytes are a little-endian 16-bit load
address, followed by the raw machine code. The BASIC `LOAD` command reads the
load address from those two bytes and places the program there in RAM. Then
`SYS <address>` jumps to it.

For this lab we will load our program at address `$0801`, which is where BASIC
programs normally live. We will place a tiny stub there that looks like a valid
(but empty) BASIC program, followed immediately by a `SYS` call that jumps to
our assembly code. This is the classic "BASIC stub" technique used on the C64
and it works identically on the X16.

### The X16 KERNAL

The X16 inherits the Commodore KERNAL - a set of ROM routines for I/O,
file access, and other system services. We call them via `JSR` to fixed
addresses in the `$FF00`-`$FFFF` range.

The two KERNAL routines you need for this lab:

| Routine | Address | Purpose |
|---------|---------|---------|
| `CHROUT` | `$FFD2` | Output one character. Put the character code in the accumulator before calling. |
| `CLRCHN` | `$FFCC` | Reset I/O channels to defaults (keyboard/screen). |

These calling conventions will reappear when we implement FORTH's `EMIT` word.

---

## The Assignment

Create a directory `lab-01/` in the project root. Inside it you will create
three files:

```
lab-01/
  hello.asm       ; the assembly source
  hello.cfg       ; the ld65 linker config
  Makefile        ; build automation
```

### Part 1 - The Assembly Source

Create `hello.asm`. Your program should:

1. Print the string `Hello, X16!` followed by a carriage return (`$0D`)
   to the screen using `CHROUT`
2. Return cleanly to BASIC when done

Here is enough structure to get you started. The gaps are left for you to fill
in:

```asm
; hello.asm - Lab 1: Hello, X16!

; KERNAL routines
CHROUT = $FFD2
CLRCHN = $FFCC

; --- PRG header ---
.segment "HEADER"
    .word $0801             ; PRG load address

; --- BASIC stub ---
; This sits at $0801 and tricks BASIC into thinking there is a one-line
; BASIC program that reads: 10 SYS 2061
; $080D is the start of our actual code (just after the stub).

.segment "BASICSTUB"
    .word $080D         ; pointer to next BASIC line
    .word 10            ; line number 10
    .byte $9E           ; BASIC token for SYS
    .byte "2061"        ; address as ASCII digits
    .byte 0             ; end of BASIC line
    .word 0             ; end of BASIC program

; --- Our code starts here ($080D) ---
.segment "CODE"

main:
    ; Your code here:
    ; Loop through the message and call CHROUT for each character,
    ; then call CLRCHN and RTS.

    rts

message:
    .byte "HELLO, X16!", $0D, 0
```

A few things to note:

- `CHROUT` expects the character in the **accumulator** (`A` register)
- The message is null-terminated (`0` byte at the end) - use that to know
  when to stop
- Either `X` or `Y` can index through a string using absolute indexed
  addressing (`lda message,x` or `lda message,y`). The difference matters in
  indirect addressing modes: only Y supports indirect indexed `lda (ptr),y`,
  which is the 6502 workhorse for pointer-based access. In FORTH we will use
  that pattern constantly, so Y is worth getting comfortable with - but for
  a simple labeled string either register works fine.
- `CLRCHN` resets I/O channels - good practice to call before returning to BASIC
- For short loops, `jmp loop` is correct and clear. The 65C02 (which the X16
  uses) adds a true unconditional relative branch `bra`, but ca65 requires
  `--cpu 65c02` to enable it. This course targets the base 6502 instruction
  set for portability, so `jmp` is preferred throughout.

### Part 2 - The Linker Config

ca65 separates assembly from linking. The assembler produces object files;
the linker combines them and places segments at specific memory addresses.
You control this with a linker config file.

Create `hello.cfg`. You need to define:

- A **`HEADER` memory region** for the two-byte PRG load address, written
  first in the output file but not loaded into RAM
- A **`RAM` memory region** starting at `$0801`
- Three **segments**: `HEADER`, `BASICSTUB`, and `CODE`

```
MEMORY {
    HEADER: start = $0000, size = 2,     file = %O;
    RAM:    start = $0801, size = $F000, file = %O;
}

SEGMENTS {
    HEADER:    load = HEADER, type = ro;
    BASICSTUB: load = RAM,    type = ro;
    CODE:      load = RAM,    type = rw;
}
```

The `file = %O` tells ld65 to write this region to the output file. The two
memory regions are written in order: `HEADER` first (two bytes), then `RAM`
(your code). This is what makes it a valid PRG file.

> **Note**: The `HEADER` region uses `start = $0000` as a placeholder - that
> address is never actually loaded into RAM. Only the `RAM` region is loaded
> by the emulator; `HEADER` just contributes its two bytes to the front of the
> output file.

### Part 3 - The Makefile

Create a `Makefile` that has at least these targets:

| Target | Action |
|--------|--------|
| `all` | Assemble and link, producing `hello.prg` |
| `run` | Launch the emulator with `hello.prg` loaded |
| `clean` | Remove generated files |

> **Note**: By default, ld65 writes its output to a file named `a.out`. Use
> the `-o` flag to specify the output filename:
> ```
> ld65 -o hello.prg ...
> ```

For the `run` target, the emulator can auto-run a PRG file at startup with
the `-prg` and `-run` flags:

```
x16emu -rom ~/.local/share/x16/rom.bin -prg hello.prg -run
```

The `-run` flag tells the emulator to type `RUN` automatically after loading.

### Part 4 - Run It

```zsh
cd lab-01
make
make run
```

You should see `HELLO, X16!` printed on the X16 screen, followed by the
BASIC `READY.` prompt.

> **Note**: The X16 boots in "uppercase/graphics" mode, where the byte values
> used by lowercase ASCII letters (`$61`-`$7A`) are mapped to graphic and
> line-drawing characters instead. Use uppercase in your message to avoid this.
> Lowercase can be enabled by sending the PETSCII control code `$0E` to
> `CHROUT` before printing, but uppercase is the natural fit for this
> environment and is conventional in FORTH.

---

## Questions to Think About

These don't need written answers - they are here to guide your thinking as
you work through later labs:

1. The BASIC stub contains the ASCII digits `"2061"` as the `SYS` target
   address. What happens if your `CODE` segment grows and `main` moves to a
   different address? How would you fix this more robustly?

2. `CHROUT` is called once per character. For FORTH's `EMIT` word, this is
   exactly the pattern we will use. What would a FORTH word that calls `CHROUT`
   look like at the assembly level?

3. The null-terminated string loop you wrote is a mini version of FORTH's
   `TYPE` word (print a string of known length). How does null-termination
   differ from FORTH's counted strings, and which is more convenient in a
   FORTH system?

4. The X16 boots in uppercase/graphics mode. If you wanted to enable
   lowercase, you could send `$0E` to `CHROUT` at startup. Where in your
   program would you add that, and why does it matter that it happens before
   any output?

---

## Stretch Goals

If you finish early and want to dig deeper:

- **Change the message** to print multiple lines (hint: `$0D` is carriage
  return on the X16, same as C64)
- **Print a number** - convert a small integer (say, `42`) to its decimal
  ASCII representation and print it. This foreshadows FORTH's `.` (dot) word.
- **Fix the BASIC stub** - make the `SYS` address in the stub computed
  automatically from the actual address of `main`, rather than hardcoded as
  `2061`. This requires a bit of creative use of ca65's expression evaluation.
