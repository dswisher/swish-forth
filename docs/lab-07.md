# Lab 7: Branching and Comparison

## Objectives

- Implement `BRANCH` and `0BRANCH` - unconditional and conditional jumps
  within a thread
- Implement the comparison primitives: `=`, `<`, `>`, `0=`
- Understand how branch offsets work in a compiled FORTH thread
- Write a hand-compiled loop to verify branching works correctly

## Prerequisites

- Lab 6 complete - `LIT`, `FIND`, and the full dictionary in place
- Comfortable with how `IP` drives the inner interpreter

---

## Background

### Why Branching is Fundamental

Every non-trivial program needs conditional execution and loops. In a
conventional language these are syntax (`if`, `while`). In FORTH they are
words - specifically, words that manipulate `IP` directly to skip forward or
jump backward in the current thread.

Two primitives are sufficient to build all control structures:

- `BRANCH` - unconditional jump: always adjusts `IP` by a given offset
- `0BRANCH` - conditional jump: pops a flag; if zero, adjusts `IP`; if
  non-zero, falls through

All of FORTH's control structures (`IF`/`ELSE`/`THEN`, `BEGIN`/`AGAIN`,
`BEGIN`/`UNTIL`, `DO`/`LOOP`) compile down to these two primitives.

### Branch Offsets

`BRANCH` and `0BRANCH` are followed immediately in the thread by a 16-bit
**signed offset**. This offset is relative to the address of the cell
*after* the offset itself - i.e., relative to where `IP` will be pointing
after `NEXT` has advanced past the offset cell.

For example, an unconditional backward jump to loop back 10 bytes would have
an offset of `-10` (stored as a 16-bit two's complement value). A forward
skip of 4 bytes has an offset of `4`.

`BRANCH` pseudocode:

```
BRANCH:
    IP = IP + 2 + memory[IP]    ; skip past offset cell, then apply offset
    NEXT
```

`0BRANCH` pseudocode:

```
0BRANCH:
    flag = pop()
    if flag == 0:
        IP = IP + 2 + memory[IP]
    else:
        IP = IP + 2             ; skip past the offset cell
    NEXT
```

### Computing Offsets by Hand

When hand-compiling a thread, you need to calculate each branch offset
manually. The process:

1. Lay out the thread on paper, noting the address (or relative position)
   of each cell
2. The offset is: `target_address - (offset_cell_address + 2)`
   - `+2` because IP advances past the offset cell before the offset is added
3. For a backward jump, the result is negative - store it as a 16-bit
     two's complement value using ca65's `.word` directive, which handles
     negative values correctly

Example - a simple `BEGIN`/`AGAIN` loop (infinite):

```asm
pfa_loop:
    .word cfa_dup               ; position 0
    .word cfa_branch            ; position 2
    .word (pfa_loop - (* + 2)) & $FFFF    ; position 4: offset back to position 0
```

The expression `pfa_loop - (* + 2)` lets ca65 compute the offset for you:
`*` is the current address (the offset cell itself), so `* + 2` is where
IP will be after reading the offset, and `pfa_loop` is the target. The
result is a negative number assembled as a 16-bit word.

This is the key insight: you can use ca65 arithmetic expressions to compute
branch offsets symbolically rather than counting bytes by hand.

### Comparison Primitives

The comparison words pop two values (or one, for `0=`), compare them, and
push a **flag**: `-1` (all bits set, `$FFFF`) for true, `0` for false. FORTH
uses `-1` rather than `1` for true because it makes bitwise operations on
flags work correctly (`AND`, `OR`, `NOT`).

| Word | Stack effect    | Description                   |
|------|-----------------|-------------------------------|
| `=`  | ( a b -- flag ) | True if a equals b            |
| `<`  | ( a b -- flag ) | True if a less than b (signed)|
| `>`  | ( a b -- flag ) | True if a greater than b      |
| `0=` | ( n -- flag )   | True if n equals zero         |

On the 6502, after `CMP`, the flags tell you the relationship between A and
the operand. For a 16-bit comparison you compare high bytes first; only if
they are equal do you need to compare low bytes. Think carefully about the
signed vs unsigned distinction for `<` and `>` - the 6502's overflow flag (V)
is involved in signed comparisons.

> **Simplification**: For this lab, implement `<` and `>` as **unsigned**
> comparisons. Signed comparison requires the overflow flag and is more
> complex. Most of the uses of `<` and `>` in the outer interpreter and
> control structures work correctly with unsigned values for typical FORTH
> programs. You can revisit this later.

---

## The Assignment

Continue working in a new `lab-07/` directory. Copy your `forth.asm`,
`forth.cfg`, and `Makefile` from `lab-06/`.

### Part 1 - BRANCH and 0BRANCH

Implement `BRANCH` and `0BRANCH` as primitives with dictionary entries.

For `BRANCH`, the code must:
1. Read the 16-bit signed offset from `memory[IP]`
2. Add it to `IP`
3. Call `NEXT`

For `0BRANCH`:
1. Pop the flag from the stack
2. If zero: read the offset and add it to `IP`
3. If non-zero: advance `IP` by 2 (skip the offset cell)
4. Call `NEXT`

Adding a signed 16-bit offset to `IP` is the same 16-bit addition you
implemented for `+` in Lab 5, applied to `IP` instead of stack values.

### Part 2 - Comparison Primitives

Implement `=`, `<`, `>`, and `0=`. Each should push `$FFFF` for true and
`$0000` for false.

For `=`: subtract the two values (using the same technique as `-`) and check
if the result is zero.

For `0=`: OR the lo and hi bytes of TOS and check if the result is zero.

For `<` and `>`: use unsigned comparison via `CMP`. After comparing the high
bytes, branch on the carry and zero flags to determine the result.

### Part 3 - Test with a Hand-Compiled Loop

Write a hand-compiled colon definition that uses branching to implement a
simple counted loop. For example, a word that counts down from 3 to 0,
calling `DUP` on each iteration (so you can see values accumulating on the
stack):

```forth
: COUNT-DOWN
    BEGIN
        1-
        DUP 0= IF EXIT THEN
    AGAIN ;
```

Hand-compile this into assembly using `.word` directives and the ca65 offset
expression technique from the background section. Step through it in the
debugger to verify the branches land at the correct addresses.

### Part 4 - Add to the Dictionary

Add dictionary entries for all new words: `BRANCH`, `0BRANCH`, `=`, `<`,
`>`, `0=`. Update `LATEST` to point to the most recently defined word.

---

## Questions to Think About

1. `BRANCH` adds the offset to `IP`. The offset is relative to the cell
   after the offset itself. Why this convention rather than relative to the
   `BRANCH` cell itself? What would change in the offset calculations?

2. `0BRANCH` uses `$0000` as false and anything else as true. What happens
   if a program pushes `1` instead of `$FFFF` as a true flag and uses it
   with `0BRANCH`? Does it work correctly?

3. The comparison words push `$FFFF` for true. Why is `-1` a better choice
   than `1`? Think about what happens when you AND two true flags together.

4. `0=` ( n -- flag ) is sometimes called `NOT` in older FORTH
   implementations. Why is `0=` a better name? When would `NOT` be
   misleading?

5. Could `>` be implemented in terms of `<` and other stack words, without
   its own machine code? What would that look like?

---

## Stretch Goals

- **Signed comparison**: Implement signed versions of `<` and `>` using the
  6502 overflow flag. The condition for signed less-than after `CMP` is:
  `N XOR V = 1`. How does this translate to branch instructions?
- **MIN and MAX**: Implement `MIN` ( a b -- min ) and `MAX` ( a b -- max )
  using `<` and the stack primitives. These can be written as hand-compiled
  colon definitions.
- **NEGATE and NOT**: Implement `NEGATE` ( n -- -n ) using two's complement,
  and `NOT` ( n -- ~n ) using bitwise inversion. These are useful building
  blocks and simple to implement.
- **U< and U>**: Add explicitly-named unsigned comparison words. Having both
  signed and unsigned variants with clear names (`<` for signed, `U<` for
  unsigned) is the ANS FORTH convention.
