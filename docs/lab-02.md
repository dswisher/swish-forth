# Lab 2: Memory Map and Threading Model

## Objectives

- Understand the X16 memory map and decide where FORTH will live
- Understand what "threaded code" means and why FORTH uses it
- Choose a threading model and understand the register assignments it requires
- Use BASIC `PEEK`/`POKE` to explore memory directly
- Use the X16 machine language monitor to inspect memory and registers

## Prerequisites

- Lab 1 complete - toolchain installed, familiar with building and running a PRG
- [X16 Memory Map reference](https://github.com/X16Community/x16-docs/blob/master/X16%20Reference%20-%2008%20-%20Memory%20Map.md)

---

## Background

### The X16 Memory Map

The X16 has a 16-bit address bus, so the CPU can directly address 64 KB
(`$0000`-`$FFFF`). Here is the high-level layout:

```
$0000-$00FF   Zero page         (256 bytes, special fast addressing)
$0100-$01FF   Hardware stack    (256 bytes, used by JSR/RTS/PHA etc.)
$0200-$03FF   KERNAL/BASIC variables and vectors
$0400-$07FF   Available for machine code
$0800-$9EFF   BASIC program area / available to user programs (~38 KB)
$9F00-$9FFF   I/O area          (VERA, sound, VIA chips)
$A000-$BFFF   Banked RAM window (8 KB, one of 256 banks)
$C000-$FFFF   Banked ROM        (16 KB, KERNAL, BASIC, etc.)
```

A few things to note:

- **Zero page** (`$0000`-`$00FF`) is special: many 6502 addressing modes can
  reference it with a single byte instead of two, making zero-page accesses
  faster and more compact. It is prime real estate.
- **The hardware stack** (`$0100`-`$01FF`) is fixed. The `S` register is the
  stack pointer; `JSR`, `RTS`, `PHA`, `PHP` all use it automatically. We
  cannot move it.
- **`$0400`-`$07FF`** is described in the X16 docs as available for machine
  code. This is a natural home for a small helper routine or lookup table.
- **`$0800`-`$9EFF`** is where BASIC programs live - and where our PRG files
  load. When we are not running BASIC, this entire region is ours.

### Where Will FORTH Live?

Since we load via the BASIC stub, our code lands at `$0801`. Once the FORTH
system is running, BASIC is gone and we own everything from `$0801` to
`$9EFF` - about 38 KB of contiguous RAM. That is more than enough for a
complete FORTH system.

A reasonable initial plan:

```
$0022-$007F   Zero page: FORTH's key "virtual registers" (see below)
$0801-$08FF   FORTH kernel code (inner interpreter, primitives)
$0900-$????   FORTH dictionary (grows upward)
????-$9EFF    FORTH stacks and data area (grows downward from top)
```

The exact boundaries will shift as we build. The important point is to
establish the *intent* now so later decisions are consistent.

### The 6502 Register Problem

FORTH needs several "registers" that do not exist in hardware on the 6502:

| FORTH register | Purpose |
|----------------|---------|
| **W** (Working) | Address of the current word being executed |
| **IP** (Instruction Pointer) | Points to the next word in the current thread |
| **PSP** (Parameter Stack Pointer) | Top of the data stack |
| **RSP** (Return Stack Pointer) | Top of the return stack |

The 6502 gives us: `A`, `X`, `Y`, `S` (hardware stack pointer), and `PC`.

The hardware stack (`S`) is already used by `JSR`/`RTS`. We will repurpose it
as FORTH's **return stack** - this is the classic 6502 FORTH trick. That gives
us RSP for free.

For the data stack (PSP), we will use a zero-page pointer and index with `X`.
`IP` and `W` will also live in zero page as 16-bit values.

A typical register assignment:

```
$0022-$0023   W   (working register, 2 bytes)
$0024-$0025   IP  (instruction pointer, 2 bytes)
X register    PSP (data stack pointer, indexed into a stack in RAM)
S register    RSP (return stack pointer, hardware stack)
```

We will refine these assignments in Lab 3 when we write the inner interpreter.
For now, just understand *why* zero page is so important to a 6502 FORTH.

### Threading Models

FORTH code is not compiled to native machine code in the traditional sense.
Instead, a FORTH word is a list of *pointers* to other words. An "inner
interpreter" walks this list and dispatches each word in turn. This is
**threaded code**.

There are three common variants:

**Indirect-Threaded Code (ITC)**
Each word in the thread is a pointer to a code field, which contains another
pointer to the actual machine code. Two levels of indirection. Classic,
well-documented, easy to understand.

**Direct-Threaded Code (DTC)**
Each word in the thread is a pointer directly to machine code (often a `JMP`
instruction). One level of indirection. Slightly faster than ITC.

**Subroutine-Threaded Code (STC)**
Each word in the thread is a `JSR` instruction. Fastest, but words take more
space and the inner interpreter nearly disappears.

We will use **ITC**. It is the most studied model, it maps clearly to the
classic FORTH literature, and the extra indirection cost is negligible for our
purposes.

### What a FORTH Word Looks Like in Memory (ITC)

Every FORTH word has the same structure in the dictionary:

```
+------------------+
| Link field       |  2 bytes: pointer to previous word in dictionary
+------------------+
| Name field       |  1 byte length + characters (e.g. $03, 'D','U','P')
+------------------+
| Code field (CFA) |  2 bytes: pointer to the executor for this word
+------------------+
| Parameter field  |  variable length: the word's "body"
| (PFA)            |
+------------------+
```

For a **primitive** (written in assembly), the CFA points to the word's own
machine code, which ends with a `NEXT` macro that advances IP.

For a **colon definition** (written in FORTH), the CFA points to `DOCOL`, a
shared routine that pushes IP onto the return stack and starts executing the
word's thread. The PFA contains a list of CFAs of other words.

The inner interpreter's job is simply: fetch the CFA at IP, advance IP, jump
through the CFA to the code. That loop is `NEXT`.

---

## Part A - Hands On: PEEK and POKE in BASIC

Boot the X16 emulator to the BASIC prompt (no `-run` flag):

```zsh
x16emu -rom ~/.local/share/x16/rom.bin
```

### Exploring zero page

At the BASIC prompt, try reading a few zero-page locations with `PEEK`:

```basic
PRINT PEEK(0)
PRINT PEEK(1)
```

Location `$0000` is the current RAM bank and `$0001` is the current ROM bank.
You should see `1` and `0` respectively - the KERNAL sets these on startup.

Now try some nearby locations:

```basic
FOR I = 0 TO 31 : PRINT I, PEEK(I) : NEXT I
```

These are the banking registers and the 16 KERNAL API registers (`r0`-`r15`).
Most will be zero or small values left over from the boot sequence.

### Writing to memory with POKE

The X16 screen is memory-mapped through the VERA chip and not directly
accessible via `POKE` in the same way a C64's screen RAM is. But RAM is RAM -
you can `POKE` into the available area (`$0400`-`$07FF`) and read it back:

```basic
POKE $0400, 42
PRINT PEEK($0400)
```

You should see `42`. You just wrote to and read from raw RAM - the same
mechanism FORTH will use for everything.

### The stack in action

The hardware stack lives at `$0100`-`$01FF`. Poke a value in and watch what
`S` (the stack pointer) tells you:

```basic
PRINT PEEK($0100 + PEEK($0100))
```

This is a little circuitous in BASIC - the monitor (Part B) gives a much
cleaner view. But convince yourself that `$0100`-`$01FF` contains real data
by peeking at several locations.

---

## Part B - Hands On: The Machine Language Monitor

The X16 has a built-in machine language monitor - a low-level tool for
inspecting and modifying memory, viewing registers, and even entering assembly
by hand. Enter it from BASIC:

```basic
MON
```

You will see something like:

```
   PC  RA RO AC XR YR SP NV#BDIZC
.;E3BB 01 04 00 00 00 F6 ........
```

The columns are: Program Counter, RAM bank, ROM bank, Accumulator, X, Y,
Stack Pointer, and the status flags. Exit the monitor at any time with `X`.

### Dumping memory

The `M` command dumps memory as hex bytes. Try dumping zero page:

```
M 0000 00FF
```

You will see 256 bytes of zero page. Look for:
- `$0000`: RAM bank (`01`)
- `$0001`: ROM bank (`00` or similar)
- `$0002`-`$0021`: KERNAL API registers (mostly zero)
- `$0022`-`$007F`: Available - this is where FORTH's virtual registers will live

Now dump the stack area:

```
M 0100 01FF
```

The stack grows downward from `$01FF`. The SP value from the register display
(e.g. `F6`) tells you the current top - look for non-zero bytes near `$01F6`
and above.

Dump the BASIC program area:

```
M 0800 08FF
```

This is currently empty (zeroes) since we have no BASIC program loaded. This
is exactly where our FORTH kernel will land.

### Disassembling the KERNAL

The `D` command disassembles memory. Try disassembling the KERNAL warm-start
vector area:

```
D FF80 FFFF
```

You will see the KERNAL jump table - a series of `JMP` instructions at fixed
addresses. These are the KERNAL routines we call with `JSR`. Find `$FFD2`
(`CHROUT`) and `$FFCC` (`CLRCHN`) in the listing.

### Viewing and modifying registers

The `R` command shows registers (same as the header line). You can also modify
them - for example, to set the accumulator to `$41` and then use `G` to run
code. We will use this more in later labs.

---

## Questions to Think About

1. Zero page locations `$0022`-`$007F` are listed as "available to the user"
   in the X16 docs. That is 94 bytes. Our FORTH system needs at minimum: W (2
   bytes), IP (2 bytes), and a few scratch locations. What other things might
   we want to keep in zero page for performance?

2. We said the hardware stack (`$0100`-`$01FF`) will serve as FORTH's return
   stack. The 6502 stack is 256 bytes deep. A FORTH return stack entry is 2
   bytes (a 16-bit address). How deeply nested can FORTH words be before the
   return stack overflows? Is that a practical concern?

3. In ITC, every word has a Code Field Address (CFA) that points to its
   executor. For a primitive, the CFA points to the word's own code. For a
   colon definition, the CFA points to `DOCOL`. Why is this uniform structure
   useful? What would change if primitives and colon definitions had different
   structures?

4. Look at the KERNAL jump table you disassembled at `$FF80`-`$FFFF`. Each
   entry is a `JMP` instruction (3 bytes). Why use a jump table of fixed
   addresses rather than calling the actual routines directly? What does this
   give the ROM designers?

---

## Stretch Goals

- **Map our FORTH layout**: Write out the full intended memory map for the
  FORTH system as a comment block that will go at the top of `forth.asm` in
  a future lab. Include addresses, sizes, and what grows in which direction.
- **Poke the stack**: From BASIC, call a subroutine using `SYS` and then
  immediately enter the monitor. Observe the return address that `SYS` pushed
  onto the stack at `$0100`+SP. Can you identify the two bytes of the return
  address?
- **Read the X16 memory map doc**: Skim
  [Chapter 8](https://github.com/X16Community/x16-docs/blob/master/X16%20Reference%20-%2008%20-%20Memory%20Map.md)
  of the X16 reference. Note the banked RAM at `$A000`-`$BFFF`. Could a
  large FORTH dictionary spill into banked RAM? What complications would
  that introduce?
