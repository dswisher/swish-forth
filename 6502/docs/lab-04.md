# Lab 4: Colon Definitions - DOCOL and EXIT

## Objectives

- Understand how colon definitions work in ITC FORTH
- Implement `DOCOL` - the routine that enters a colon definition
- Implement `EXIT` - the primitive that returns from a colon definition
- Write a test that calls one FORTH word from another, using the hardware
  stack as the return stack

## Prerequisites

- Lab 3 complete - `NEXT` working, comfortable with the ITC dispatch mechanism
- Understanding of the 6502 hardware stack (`PHA`, `PLA`, `JSR`, `RTS`)

---

## Background

### The Problem DOCOL Solves

In Lab 3, `NEXT` can dispatch primitive words - words whose CFA points
directly to machine code. But FORTH's power comes from defining new words
in terms of existing ones:

```forth
: GREET  CR ." HELLO" CR ;
```

`GREET` is a **colon definition** - its body is a list of CFAs, not machine
code. When `NEXT` dispatches `GREET`, it needs to:

1. Save the current `IP` (so we can return to where we were)
2. Set `IP` to point at `GREET`'s body (the list of CFAs)
3. Resume the inner interpreter - which is just falling into `NEXT` again

That save-and-redirect is `DOCOL`. Every colon definition has `DOCOL` as its
executor - the value stored in its CFA cell.

### The Return Stack

Where does `DOCOL` save `IP`? On FORTH's **return stack**. In our
implementation, the return stack is the 6502 hardware stack (`$0100`-`$01FF`),
managed by `S` (the stack pointer).

The 6502 hardware stack is byte-oriented and grows downward. Pushing a 16-bit
value requires two `PHA` instructions (high byte first, then low byte, so that
popping in reverse order reconstructs the value correctly):

```asm
; Push IP onto the return stack (high byte first)
lda IP+1
pha
lda IP
pha
```

Popping restores `IP` (low byte first, then high byte):

```asm
; Pop IP from the return stack
pla
sta IP
pla
sta IP+1
```

### What DOCOL Does

`DOCOL` is not a macro - it is a shared subroutine. Every colon definition's
CFA cell points to `DOCOL`. When `NEXT` dispatches a colon definition:

1. `NEXT` loads `W` with the address of the word's CFA
2. `NEXT` loads `WX` with the contents of the CFA cell, which is `DOCOL`
3. `jmp (WX)` jumps to `DOCOL`

At this point `W` still holds the address of the CFA. The word's Parameter
Field Address (PFA) - its body, the list of CFAs - is at `W + 2`. So `DOCOL`
needs to:

1. Push the current `IP` onto the return stack
2. Set `IP` to `W + 2` (the PFA)
3. Fall into `NEXT`

```asm
DOCOL:
    ; Push current IP onto the return stack
    lda IP+1
    pha
    lda IP
    pha
    ; Set IP to the PFA (W + 2)
    clc
    lda W
    adc #2
    sta IP
    lda W+1
    adc #0          ; carry from previous add
    sta IP+1
    ; Resume the inner interpreter
    NEXT
```

### What EXIT Does

`EXIT` is the FORTH word that corresponds to `;` (end of a colon definition).
Its job is the reverse of `DOCOL`: pop the saved `IP` off the return stack
and resume executing the calling thread.

`EXIT` is a primitive - its CFA points to its own machine code:

```asm
cfa_exit:
    .word code_exit
code_exit:
    ; Pop IP from the return stack
    pla
    sta IP
    pla
    sta IP+1
    NEXT
```

### Putting It Together

A colon definition in memory looks like this:

```
cfa_greet:
    .word DOCOL         ; CFA: executor is DOCOL
pfa_greet:              ; PFA: the body starts here
    .word cfa_cr        ; call CR
    .word cfa_exit      ; return to caller
```

When `NEXT` dispatches `greet`:
1. `W` = address of `cfa_greet`
2. `WX` = `DOCOL`
3. Jump to `DOCOL`
4. `DOCOL` pushes `IP`, sets `IP` to `pfa_greet`, calls `NEXT`
5. `NEXT` dispatches `cfa_cr` - executes CR
6. `NEXT` dispatches `cfa_exit` - `EXIT` pops `IP`, calls `NEXT`
7. Execution resumes where it left off before `greet` was called

---

## The Assignment

Continue working in a new `lab-04/` directory. Copy your `forth.asm`,
`forth.cfg`, and `Makefile` from `lab-03/` as a starting point - lab 4
builds directly on the `NEXT` macro and zero-page layout from lab 3.

### Part 1 - Implement DOCOL

Add `DOCOL` as a subroutine in the `CODE` segment. Place it near the top,
before the test thread, so it is easy to find.

### Part 2 - Implement EXIT

Add `EXIT` as a primitive, following the same CFA/code pattern as `FOO` and
`BAR` from lab 3.

### Part 3 - A Colon Definition Test

Replace the lab 3 test thread with one that demonstrates a colon definition
calling another colon definition. Here is a suggested structure:

- `INNER` is a colon definition that calls `FOO`, then `BAR`, then `EXIT`
- `OUTER` is a colon definition that calls `INNER`, then `EXIT`
- The test thread calls `OUTER`

```asm
; Test thread
test_thread:
    .word cfa_outer
    .word cfa_exit      ; terminate the top-level thread

; Colon definition: OUTER
cfa_outer:
    .word DOCOL
    .word cfa_inner
    .word cfa_exit

; Colon definition: INNER
cfa_inner:
    .word DOCOL
    .word cfa_foo
    .word cfa_bar
    .word cfa_exit
```

Keep `FOO` and `BAR` as nop-filled stubs from lab 3 - they are just
placeholders to give the thread something to execute.

> **Note**: The test thread itself is not a colon definition - `main` sets
> `IP` to point at it directly. It still needs a terminator. `cfa_exit` will
> pop a return address off the hardware stack that was never pushed, which
> will cause undefined behavior. For now, put a `brk` instruction somewhere
> after the thread so execution stops visibly if it runs off the end.

### Part 4 - Trace It

Using the emulator debugger, step through the execution and verify:

1. When `OUTER` is dispatched, `DOCOL` runs, the old `IP` is pushed onto
   the hardware stack, and `IP` is set to `OUTER`'s PFA
2. When `INNER` is dispatched from within `OUTER`, `DOCOL` runs again,
   pushing `IP` a second time - the stack grows
3. `FOO` and `BAR` execute (the nops) and `NEXT` advances `IP` each time
4. When `EXIT` runs inside `INNER`, `IP` is restored to the saved value
   pointing back into `OUTER`'s body
5. When `EXIT` runs inside `OUTER`, `IP` is restored to the test thread

At each `DOCOL` and `EXIT`, dump the hardware stack (`M 0100 01FF`) and
watch it grow and shrink.

---

## Questions to Think About

1. `DOCOL` ends with `NEXT`, not `RTS`. Why? What would happen if `DOCOL`
   used `JSR`/`RTS` to call the inner interpreter instead?

2. The return stack is the 6502 hardware stack, which is only 256 bytes deep.
   A return stack entry is 2 bytes. But `JSR` also uses the same stack,
   pushing 2 bytes per call. Does `DOCOL` use `JSR`? Does `NEXT`? What is
   the maximum nesting depth available to FORTH words?

3. `DOCOL` computes `W + 2` to find the PFA. This assumes the CFA is always
   exactly 2 bytes. Is that guaranteed in our implementation? What would
   break if the CFA were a different size?

4. `EXIT` pops `IP` and calls `NEXT`. What happens if `EXIT` is called when
   the return stack is empty? On the 6502, what does `PLA` do if the stack
   has wrapped around?

---

## Stretch Goals

- **Stack depth display**: After each `DOCOL` and `EXIT`, use the monitor's
  `R` command to read the `SP` register. Map out the stack depth at each
  point in the execution of the `OUTER` → `INNER` → `FOO` test. Does it
  match your expectation from question 2 above?
- **Nested colon definitions**: Add a third level - `OUTERMOST` calls
  `OUTER`. Trace the stack through three levels of nesting.
- **DOCOL without NEXT**: Rewrite `DOCOL` to jump directly into the middle
  of the `NEXT` macro's second dereference phase, rather than invoking the
  full `NEXT`. Is this possible? Is it worth it?
