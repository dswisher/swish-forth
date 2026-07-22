# Lab 3: The Inner Interpreter

## Objectives

- Create the `forth.asm` source file that will grow into the FORTH kernel
- Establish the zero-page layout for FORTH's virtual registers
- Understand and implement the `NEXT` macro
- Write a minimal inner interpreter loop that you can trace in the monitor

## Prerequisites

- Lab 2 complete - comfortable with the monitor, memory map, and threading model
- The lab-01 Makefile as a reference for building PRG files

---

## Background

### What NEXT Does

In Lab 2 we described ITC (Indirect-Threaded Code): a FORTH word's body is a
list of pointers to other words' Code Field Addresses (CFAs). The inner
interpreter walks this list. In the classic FORTH literature, the step that
advances to the next word in the thread is called `NEXT`.

Here is the algorithm in pseudocode:

```
NEXT:
    W  = memory[IP]       ; fetch the CFA of the next word
    IP = IP + 2           ; advance IP past the pointer we just fetched
    PC = memory[W]        ; jump through the CFA to the machine code
```

Step by step:
1. `IP` points at a cell in the current thread. That cell holds the CFA of the
   next word to execute.
2. We load that CFA into `W`.
3. We advance `IP` by 2 (one 16-bit pointer).
4. We jump to the address stored *at* `W` - that is the machine code for the
   word.

The two levels of indirection are what make it "indirect" threaded:
- Thread cell → CFA (`W`) → machine code

### Register Assignments

From Lab 2, our plan is:

```
$0022-$0023   W   (working register, 2 bytes, lo/hi)
$0024-$0025   IP  (instruction pointer, 2 bytes, lo/hi)
$0026-$0027   WX  (scratch register for NEXT, 2 bytes, lo/hi)
X register    PSP (parameter stack pointer)
S register    RSP (return stack pointer, hardware stack)
```

`WX` is needed by `NEXT` to perform the second level of indirection (see
below). `W` must remain intact after `NEXT` because the code being dispatched
to may need it - this becomes important in Lab 4 with `DOCOL`.

We will define these as zero-page labels at the top of `forth.asm`.

### The 6502 Implementation of NEXT

On the 6502, indirect addressing through a zero-page pointer uses the form
`lda (ptr),y`. With `Y = 0`, this reads the byte at the address stored in
`ptr`/`ptr+1`.

A 16-bit fetch through `IP` into `W` looks like this:

```asm
; Fetch low byte of CFA into W
ldy #0
lda (IP),y      ; W_lo = memory[IP]
sta W

; Fetch high byte
iny
lda (IP),y      ; W_hi = memory[IP+1]
sta W+1

; Advance IP by 2
clc
lda IP
adc #2
sta IP
bcc @no_carry
inc IP+1
@no_carry:

; W holds the CFA address. Read through it to get the code address into WX.
; We cannot overwrite W because DOCOL (Lab 4) needs it intact.
ldy #0
lda (W),y
sta WX
iny
lda (W),y
sta WX+1

; Jump to the machine code
jmp (WX)
```

`NEXT` performs two levels of indirection:
1. Fetch the CFA address from the thread into `W` (thread cell → `W`)
2. Read through `W` to get the code address into `WX` (`W` → `WX`)
3. Jump to the code via `jmp (WX)`

This is why it is called *indirect*-threaded code.

Note that anonymous labels (`:+`) do not work correctly inside ca65 macros.
Use `@`-prefixed local labels instead - ca65 makes them unique per expansion.

`NEXT` will be used at the end of *every* primitive, so we define it as a
ca65 macro to avoid repeating this code everywhere:

```asm
.macro NEXT
    ldy #0
    lda (IP),y
    sta W
    iny
    lda (IP),y
    sta W+1
    clc
    lda IP
    adc #2
    sta IP
    bcc @no_carry
    inc IP+1
@no_carry:
    ldy #0
    lda (W),y
    sta WX
    iny
    lda (W),y
    sta WX+1
    jmp (WX)
.endmacro
```

---

## The Assignment

### Part 1 - Project Setup

Create a new directory `lab-03/` in the project root with these files:

```
lab-03/
  forth.asm       ; the FORTH kernel (starts here, grows through future labs)
  forth.cfg       ; linker config
  Makefile        ; build automation
```

The `Makefile` and `forth.cfg` can be adapted directly from lab-01. The output
file should be `forth.prg`.

### Part 2 - Zero Page Layout

At the top of `forth.asm`, after the HEADER and BASICSTUB segments, define the
zero-page labels:

```asm
; Zero page layout
W   = $22       ; working register (2 bytes: $22-$23)
IP  = $24       ; instruction pointer (2 bytes: $24-$25)
WX  = $26       ; NEXT scratch register (2 bytes: $26-$27)
```

These are equates (not storage allocations) - they just give names to
addresses. The actual bytes live in zero page RAM, which is always there.

### Part 3 - The NEXT Macro

Define the `NEXT` macro as shown in the background section. Place it after
the zero-page equates and before the `CODE` segment.

### Part 4 - A Minimal Test Thread

The goal is not to run a real FORTH program yet - it is to have something you
can *trace* in the monitor to verify that `NEXT` is fetching and dispatching
correctly.

In the `CODE` segment, write a `main` that:

1. Initializes `IP` to point at `test_thread`
2. Executes `NEXT` to dispatch the first word

Then define two primitive words - just stubs that do nothing except invoke
`NEXT` again - and a thread that calls them:

```asm
; The test thread: a list of CFAs
test_thread:
    .word cfa_foo       ; pointer to foo's CFA
    .word cfa_bar       ; pointer to bar's CFA
    ; (no exit yet - the thread will run off the end for now)

; Primitive: FOO
; The CFA of a primitive points to its own code.
cfa_foo:
    .word code_foo      ; CFA cell: points to the machine code below
code_foo:
    ; ... do nothing for now ...
    NEXT

; Primitive: BAR
cfa_bar:
    .word code_bar
code_bar:
    ; ... do nothing for now ...
    NEXT
```

Notice the structure: `cfa_foo` is a 2-byte cell containing the address
`code_foo`. `NEXT` loads `W` with the address of `cfa_foo`, then reads
through `W` to load `WX` with `code_foo`, then `jmp (WX)` jumps to the
machine code. That is the two levels of indirection.

> **Question to think about**: Why does `cfa_foo` contain the address
> `code_foo` rather than just being the same address as `code_foo`? What
> would have to change if this were Direct-Threaded Code instead of
> Indirect-Threaded Code?

### Part 5 - Trace It in the Monitor

Build and run the program, then pause it with the monitor. (Use the emulator's
built-in monitor or set a breakpoint by replacing a byte with `BRK`.)

Using `D` to disassemble and `M` to dump memory, verify:

1. `IP` at `$24`-`$25` contains the address of `test_thread`
2. The first word of `test_thread` contains the address of `cfa_foo`
3. After the fetch phase of `NEXT`, `W` at `$22`-`$23` contains the address of
   `cfa_foo` and `IP` has advanced by 2
4. After the second dereference, `WX` at `$26`-`$27` contains the address of
   `code_foo`
5. The `jmp (WX)` lands at `code_foo`

---

## Questions to Think About

1. The `NEXT` macro ends with `jmp (WX)`. This is the 6502's indirect jump -
   it reads a 16-bit address from memory and jumps there. There is a famous
   6502 bug with `jmp (addr)` when `addr` ends in `$FF` (e.g. `jmp ($12FF)`).
   Look it up. Does it affect us? Why or why not?

2. Every primitive ends with `NEXT`. What does this mean for the 6502's
   hardware stack (RSP)? Compare this to how a language implemented with
   `JSR`/`RTS` would work. What are the implications for stack depth?

3. `NEXT` is a macro, not a subroutine. That means the code is duplicated
   at every call site. For a system with many primitives, what is the
   trade-off between using a macro versus a `JSR NEXT` subroutine? Which
   is better for a FORTH kernel and why?

4. In the test thread, what happens after `NEXT` dispatches `cfa_bar` and
   `code_bar` executes `NEXT` again? Where does `IP` point? What would you
   need to add to terminate the thread cleanly?

---

## Stretch Goals

- **DOCOL stub**: In ITC, colon definitions use a shared routine `DOCOL`
  that saves `IP` on the return stack and sets `IP` to the word's PFA.
  Sketch out (in comments or pseudocode) what `DOCOL` would look like in
  6502 assembly. What instructions would it need? This will be implemented
  for real in Lab 4.
- **Measure NEXT**: Count the number of 6502 cycles that your `NEXT` macro
  takes. Each instruction has a known cycle count (check the 6502 reference).
  How does this compare to a native `JSR`/`RTS` pair (which costs 12 cycles)?
- **Cleaner IP increment**: The `clc / adc #2 / bcc / inc` sequence for
  advancing IP is four instructions. Can you think of a way to structure the
  zero-page layout or register use to make this cheaper?
