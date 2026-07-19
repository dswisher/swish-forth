# Lab 5: Primitive Words - Stack, Arithmetic, and Memory

## Objectives

- Implement the parameter stack using the X register as the stack pointer
- Write the core stack primitives: `DUP`, `DROP`, `SWAP`, `OVER`
- Write basic arithmetic primitives: `+`, `-`, `1+`, `1-`
- Write memory access primitives: `@` (fetch) and `!` (store)
- Replace the `FOO`/`BAR` stubs with real primitives and write a test thread
  that exercises them

## Prerequisites

- Lab 4 complete - `NEXT`, `DOCOL`, and `EXIT` all working
- Comfortable with the 6502 indexed addressing modes (`lda addr,x`)
- Understanding of what the parameter stack is for in FORTH

---

## Background

### The Parameter Stack

In FORTH, most words communicate through a shared **parameter stack** (also
called the data stack). Words pop their inputs off the stack and push their
results back on. For example, `+` pops two numbers, adds them, and pushes the
result.

We need a stack that:
- Holds 16-bit (2-byte) values
- Can grow and shrink rapidly
- Is fast to access

The 6502's X register makes a good stack pointer for this purpose. We will
dedicate a region of zero page or page 1 to the parameter stack and use X to
track the top.

### Stack Layout

We will place the parameter stack in zero page at `$C0`-`$FF` (64 bytes,
room for 32 cells), growing **downward**. Each entry is 2 bytes: lo byte at
the lower address, hi byte at the next address up. X points to the **lo byte
of the top of stack (TOS)**.

With the stack empty, X = `$FF`. After pushing one item, X decrements by 2
to `$FD`; TOS lo is at `$FD`, TOS hi at `$FE`. After pushing a second item,
X = `$FB`:

```
$FF   (X starts here; stack empty)
$FE   hi byte  \  first item pushed; TOS when one item on stack
$FD   lo byte  /  <- X = $FD with one item
$FC   hi byte  \  second item pushed; TOS when two items on stack
$FB   lo byte  /  <- X = $FB with two items; first item is now NOS
 ...
$C1   ]
$C0   ]  deeper stack items
```

Pushing a 16-bit value decrements X by 2, then stores lo and hi:

```asm
dex
dex
sta PSP+0,x     ; store lo byte  (at X)
tya             ; (value hi byte in Y here, by convention)
sta PSP+1,x     ; store hi byte  (at X+1)
```

Popping a 16-bit value loads lo and hi, then increments X by 2:

```asm
lda PSP+0,x     ; load lo byte
ldy PSP+1,x     ; load hi byte
inx
inx
```

We will define:

```asm
PSP = $00       ; base address; X is the offset, so PSP+0,x = $00+X = X
```

With `PSP = $00`, `lda PSP+0,x` assembles to `lda $00,x` - zero-page indexed
addressing, which is fast and compact.

> **Note on register conventions**: In this lab we use A for the low byte and
> Y for the high byte of a 16-bit value when moving data on and off the stack.
> This is a convention - not enforced by the hardware - but being consistent
> will make your primitives easier to read and less error-prone.

### Stack Initialization

In `main`, initialize X to `$FF` before entering the interpreter:

```asm
ldx #$FF        ; empty parameter stack
```

### Implementing DUP

`DUP` ( n -- n n ) duplicates the top of stack.

```asm
cfa_dup:
    .word code_dup
code_dup:
    lda PSP+0,x     ; load TOS lo
    ldy PSP+1,x     ; load TOS hi
    dex
    dex
    sta PSP+0,x     ; push copy lo
    tya
    sta PSP+1,x     ; push copy hi
    NEXT
```

Work through this carefully. After `dex / dex`, X has moved down by 2. We
then write the saved value into the new top-of-stack position. The original
value is still in place above it.

### Implementing DROP

`DROP` ( n -- ) discards the top of stack. This is simply advancing X.

```asm
cfa_drop:
    .word code_drop
code_drop:
    inx
    inx
    NEXT
```

### Implementing SWAP

`SWAP` ( a b -- b a ) exchanges the top two items.

This one is more work - you need to read both items, write them back in
reverse order. Think about which registers you have available.

### A Note on 16-bit Arithmetic

The 6502 has no native 16-bit add instruction. To add two 16-bit values you
add the low bytes (with `clc` / `adc`) and then add the high bytes with
`adc #0` to propagate the carry:

```asm
clc
lda a_lo
adc b_lo
sta result_lo
lda a_hi
adc b_hi        ; carry from the low-byte add is included here
sta result_hi
```

Subtraction uses `sec` / `sbc` in the same pattern:

```asm
sec
lda a_lo
sbc b_lo
sta result_lo
lda a_hi
sbc b_hi
sta result_hi
```

For `1+` and `1-`, adding or subtracting the constant 1 only affects the low
byte unless it carries or borrows into the high byte - but you still need to
handle the carry/borrow correctly.

---

## The Assignment

Continue working in a new `lab-05/` directory. Copy your `forth.asm`,
`forth.cfg`, and `Makefile` from `lab-04/` as a starting point.

### Part 1 - Parameter Stack Setup

1. Add the `PSP` equate near the top of `forth.asm` with the other zero-page
   labels:

   ```asm
   PSP = $00       ; parameter stack base (X register is the offset)
   ```

2. In `main`, initialize X to `$FF` before jumping to `NEXT`.

3. Remove the `FOO` and `BAR` stub words - they have served their purpose.

### Part 2 - Stack Primitives

Implement the following primitives. Place them in a clearly labeled section
of `forth.asm`. Each follows the same CFA/code pattern established in
previous labs.

| Word   | Stack effect  | Description                        |
|--------|---------------|------------------------------------|
| `DUP`  | ( n -- n n )  | Duplicate top of stack             |
| `DROP` | ( n -- )      | Discard top of stack               |
| `SWAP` | ( a b -- b a )| Exchange top two items             |
| `OVER` | ( a b -- a b a ) | Copy second item to top         |

The background section gives you `DUP` and `DROP`. `SWAP` and `OVER` are
yours to work out.

### Part 3 - Arithmetic Primitives

Implement:

| Word  | Stack effect    | Description                  |
|-------|-----------------|------------------------------|
| `+`   | ( a b -- a+b )  | 16-bit addition              |
| `-`   | ( a b -- a-b )  | 16-bit subtraction           |
| `1+`  | ( n -- n+1 )    | Increment by 1               |
| `1-`  | ( n -- n-1 )    | Decrement by 1               |

For `+` and `-`, pop both operands, compute the result, and push it. For `1+`
and `1-`, operate on TOS in place (read, compute, write back) without a full
pop/push cycle if you can avoid it.

> **Note on labels**: `+` and `-` are not valid ca65 label characters. Use
> `word_plus`, `word_minus`, `cfa_plus`, `cfa_minus`, etc.

### Part 4 - Memory Primitives

Implement:

| Word | Stack effect      | Description                         |
|------|-------------------|-------------------------------------|
| `@`  | ( addr -- n )     | Fetch 16-bit value from address     |
| `!`  | ( n addr -- )     | Store 16-bit value to address       |

For `@`: pop an address, read 2 bytes from that address, push the value.
Use `lda (zp),y` with Y=0 and Y=1 - but `lda (zp),y` requires the address
to be in zero page. You will need to temporarily store the address in a
zero-page location to use indirect addressing.

For `!`: pop an address and a value, write the value to that address.
Same zero-page constraint applies.

Think about which zero-page locations are safe to use as scratch here. You
have `W` and `WX` available between word dispatches - but are they safe to
overwrite inside a primitive?

### Part 5 - Test Thread

Replace the old test thread with one that exercises your new primitives.
Since `LIT` (the primitive that pushes inline literals from the thread) is not
implemented yet, pre-load the stack with known values directly in `main` before
entering the interpreter.

For example, to pre-load the stack with 3 and 5 (5 on top):

```asm
main:
    ldx #$FF            ; empty parameter stack

    ; push 3
    dex
    dex
    lda #3
    sta PSP+0,x
    lda #0
    sta PSP+1,x

    ; push 5
    dex
    dex
    lda #5
    sta PSP+0,x
    lda #0
    sta PSP+1,x

    ; set IP and enter the interpreter
    lda #<test_thread
    sta IP
    lda #>test_thread
    sta IP+1
    NEXT
```

Then write a test thread that operates on those values:

```asm
test_thread:
    ; (normally we'd use cfa_lit to push values here, but LIT isn't implemented yet)
    .word cfa_plus      ; add 3 + 5 -> 8
    .word cfa_dup       ; dup -> 8 8
    .word cfa_drop      ; drop -> 8
    .word cfa_exit
```

### Part 6 - Verify in the Debugger

Step through the test thread and verify:

1. After `+`, the stack contains a single value equal to the sum
2. After `DUP`, the stack has two identical values
3. After `SWAP`, the top two values are exchanged
4. After `@`, the value read from memory matches what you expect
5. After `!`, the memory location contains the value you stored

---

## Questions to Think About

1. `OVER` copies the *second* item to the top. In terms of the X register and
   the `PSP` base address, what offset do you need to read the second item?
   Write out the addresses for a two-item stack and confirm your offset is
   correct.

2. For the `@` primitive, you need a zero-page scratch location to hold the
   address before you can use `lda (zp),y`. Could you use `W` for this?
   What condition must be true for that to be safe?

3. The `!` primitive pops two items: the address and the value. In what order
   are they on the stack? (The convention is `( n addr -- )` - which is on
   top?) Does the order matter for your implementation?

4. `1+` can be implemented as a full pop-compute-push, or it can modify TOS
   in place. What are the tradeoffs? For a 16-bit `1+` in place, what is the
   trickiest part?

5. The parameter stack is currently in zero page. What would happen if a FORTH
   program pushed more values than fit in the allocated region? How could you
   detect this? (This is a preview of stack overflow checking, which a robust
   FORTH kernel implements.)

---

## Stretch Goals

- **NEGATE and negate-based subtraction**: Implement `NEGATE` ( n -- -n )
  using two's complement. Then implement `-` in terms of `NEGATE` and `+`.
  Is the resulting `-` correct for all 16-bit inputs?
- **AND, OR, XOR**: Implement the bitwise primitives. These are simple
  byte-by-byte operations on the lo and hi halves.
- **Stack depth tracking**: Add a word `DEPTH` ( -- n ) that returns the
  current number of items on the parameter stack. To implement this you need
  to know the initial (empty) value of X and compute the difference.
- **LIT**: Implement the `LIT` primitive, which reads the next cell from the
  thread (using `IP`) and pushes it onto the parameter stack. This is the
  mechanism FORTH uses to embed literal numbers in compiled words. With `LIT`
  working, you can eliminate the manual stack setup in `main`.
