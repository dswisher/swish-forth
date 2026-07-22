# Lab 8: The Outer Interpreter

## Objectives

- Implement `EMIT` and `KEY` - the basic I/O primitives
- Implement `WORD` - reads one whitespace-delimited token from input
- Implement `NUMBER` - converts a string to a 16-bit integer
- Implement the outer interpreter loop `INTERPRET` - the FORTH prompt
- Boot into an interactive FORTH session

## Prerequisites

- Lab 7 complete - `BRANCH`, `0BRANCH`, and comparison primitives working
- Familiarity with the X16 KERNAL routines `CHROUT` and `CHRIN` from Lab 1
- Understanding of ASCII character codes

---

## Background

### The Outer Interpreter

The inner interpreter (`NEXT`, `DOCOL`, `EXIT`) executes compiled FORTH
threads. The **outer interpreter** is what makes FORTH interactive: it reads
a line of input, breaks it into words, looks each one up in the dictionary,
and either executes it or (if it is a number) pushes it onto the stack.

The classic FORTH outer interpreter loop is:

```
BEGIN
    WORD        ( -- addr len )   read next token from input
    DUP 0= IF DROP DROP AGAIN THEN
    OVER OVER   ( addr len addr len )   save a copy for NUMBER
    FIND DUP    ( addr len cfa cfa ) or ( addr len 0 0 )
    IF          found: execute it
        NIP NIP     ( cfa )   drop the saved addr len
        EXECUTE
    ELSE        not found: try to parse as a number
        DROP        ( addr len )   drop the zero from FIND
        NUMBER
        IF      valid number: n is already on the stack
        ELSE    error: unknown word - drop the zero, report error
            DROP
            ERROR
        THEN
    END
AGAIN
```

In this lab you will implement the pieces that make this loop work, then wire
them together into a running interpreter. Because `BRANCH` and `0BRANCH` are
now available from Lab 7, `INTERPRET` can be written as a proper hand-compiled
FORTH colon definition rather than an assembly subroutine.

### X16 I/O

The Commander X16 KERNAL provides two routines you already used in Lab 1:

- `CHROUT` (`$FFD2`) - output one character (A register = ASCII code)
- `CHRIN` (`$FFCF`) - input one character (returns ASCII code in A)

`CHRIN` on the X16 returns characters from the current input channel. In the
default keyboard input mode, it waits for the user to press a key and returns
the PETSCII code. Note that the X16 uses PETSCII, not ASCII - for printable
characters in the range `$20`-`$5F` they are identical, but be aware of this
distinction if you encounter unexpected behavior with lowercase letters.

### EMIT and KEY

`EMIT` ( c -- ) outputs one character. It pops the character code from the
stack and calls `CHROUT`:

```asm
code_emit:
    lda PSP+0,x     ; character in A (lo byte; hi byte is ignored)
    inx
    inx
    jsr CHROUT
    jmp NEXT
```

`KEY` ( -- c ) waits for a keypress and pushes the character code:

```asm
code_key:
    jsr CHRIN
    dex
    dex
    sta PSP+0,x
    lda #0
    sta PSP+1,x
    jmp NEXT
```

### Input Buffering and WORD

The X16 KERNAL's `CHRIN` in keyboard mode is **line-buffered**: it does not
return until the user presses Return, at which point it returns characters one
at a time on successive calls. This is convenient - it means `WORD` can call
`CHRIN` repeatedly to read a whole line into a buffer, then parse tokens from
that buffer.

`WORD` ( -- addr len ) reads the next whitespace-delimited token from the
input buffer. Its algorithm:

1. Skip leading spaces (ASCII `$20`)
2. Collect characters until the next space or end of line (ASCII `$0D` on
   the X16)
3. Return the address and length of the collected token

You will need an input buffer in memory. A reasonable size is 80 bytes. Place
it in the `BSS` segment (uninitialized data) or reserve space after your code.
You will also need a pointer into the buffer to track where parsing has
reached.

A suggested zero-page layout addition:

```asm
IBUF  = $2B     ; input buffer pointer (2 bytes: $2B-$2C)
```

And a buffer in memory:

```asm
.segment "BSS"
input_buf:  .res 80     ; input line buffer
ibuf_end:               ; one past the end
```

`WORD` refills the buffer (calls `CHRIN` in a loop until `$0D`) whenever the
pointer has reached the end. Between calls, it advances the pointer through
the buffer, skipping spaces and collecting the next token into a separate
**word buffer** (another small region of memory), returning a pointer to that.

### NUMBER

`NUMBER` ( addr len -- n flag ) attempts to convert a string to a 16-bit
unsigned integer in the current base (we will use base 10 for now). It returns
the number and a flag: non-zero on success, zero on failure.

The algorithm for base-10 conversion:

```
result = 0
for each character c in the string:
    if c < '0' or c > '9': return 0 (failure)
    result = result * 10 + (c - '0')
return result, -1 (success)
```

Multiplying a 16-bit value by 10 on the 6502 requires some work since there
is no multiply instruction. The standard trick is:

```
n * 10 = (n * 8) + (n * 2) = (n << 3) + (n << 1)
```

Shifting left is done with `ASL` (arithmetic shift left), which doubles the
value. Shifting left 3 times multiplies by 8.

### EXECUTE

`EXECUTE` ( cfa -- ) takes a CFA address from the stack and jumps to the code
it points to - effectively dispatching a word that was found by `FIND` at run
time rather than compiled into a thread.

```asm
code_execute:
    lda PSP+0,x     ; load CFA lo
    sta W
    lda PSP+1,x     ; load CFA hi
    sta W+1
    inx
    inx
    ldy #0
    lda (W),y       ; read code address lo
    sta WX
    iny
    lda (W),y       ; read code address hi
    sta WX+1
    jmp (WX)
```

Notice this is essentially the second half of `NEXT` - it reads through the
CFA to get the code address and jumps to it. It is important to use the same
register convention as `NEXT`: the CFA goes in `W` and the code address goes
in `WX`. `DOCOL` relies on `W` holding the CFA so it can compute the PFA as
`W + 2`. If you put the CFA in `WX` instead, primitives will work fine (they
ignore `W`), but any colon definition dispatched through `EXECUTE` will
crash immediately as `DOCOL` computes a garbage `IP`.
Make sure you use the right register here.

### INTERPRET - Putting It Together

`INTERPRET` is the outer interpreter loop written as a hand-compiled FORTH
colon definition. Now that `BRANCH`, `0BRANCH`, and the comparison primitives
are available from Lab 7, the full loop structure can be expressed directly
as a thread of CFAs:

```forth
: INTERPRET
    BEGIN
        WORD
        DUP 0= IF DROP DROP AGAIN THEN
        OVER OVER FIND DUP
        IF
            NIP NIP
            EXECUTE
        ELSE
            DROP
            NUMBER
            IF ELSE DROP ERROR THEN
        THEN
    AGAIN ;
```

You will hand-compile this into an assembly thread using `.word` directives,
with `BRANCH` and `0BRANCH` followed by their inline offsets. Lab 9 will
introduce the compiler that automates this process - for now, computing and
encoding the branch offsets by hand is a valuable exercise in understanding
how control flow works at the thread level.

---

## The Assignment

Continue working in a new `lab-08/` directory. Copy your `forth.asm`,
`forth.cfg`, and `Makefile` from `lab-07/`.

### Part 1 - EMIT and KEY

Add `EMIT` and `KEY` as primitives with dictionary entries. Test them with a
simple thread that pushes the ASCII code for `!` and calls `EMIT`, then calls
`KEY` and `EMIT` to echo a keypress back to the screen.

Note that `CHROUT` and `CHRIN` use `JSR`/`RTS`. This is fine inside a
primitive - `JSR` pushes to the hardware stack, but `RTS` pops it before you
call `NEXT`, so the stack is balanced.

### Part 2 - Input Buffer and WORD

Add the input buffer and `IBUF` pointer to the zero-page layout. Implement
`WORD` as a primitive. Its job:

1. If the current character (`memory[IBUF]`) is `$0D` (carriage return),
   refill: call `CHRIN` in a loop until `$0D`, storing each character into
   `input_buf` (including the `$0D` as the terminator). Reset `IBUF` to the
   start of the buffer. Optionally print a prompt (`OK `) before reading.
2. Skip characters equal to `$20` (space), advancing the pointer.
3. Collect characters (not space, not `$0D`) into a separate `word_buf`,
   advancing both pointers.
4. Push the address of `word_buf` and the length of the collected token.

Test `WORD` by writing a thread that calls `WORD` and then uses `EMIT` in a
loop to print back what was read. (You will need a simple loop primitive or
just unroll it for testing.)

### Part 3 - NUMBER

Implement `NUMBER` as a primitive. For now, only handle unsigned decimal
integers (digits `0`-`9`). Return a success/failure flag as described in the
background section.

Test with known strings: push the address and length of `"42"` and call
`NUMBER`; verify the stack contains `42` and a non-zero flag.

### Part 4 - EXECUTE

Implement `EXECUTE` as a primitive. Review the background section carefully
regarding which register (`W` vs `WX`) to use, and why.

Test by using `FIND` to look up a known word, then passing the result to
`EXECUTE`. Verify the word runs correctly.

### Part 5 - INTERPRET

Wire everything together into a hand-compiled `INTERPRET` colon definition.
Using `.word` directives, encode the loop described in the background section.
You will need to manually compute the branch offsets for `BRANCH` and
`0BRANCH` - each branch instruction is followed by a signed 16-bit offset
that is added to `IP` at run time.

Change `main` to initialize the stacks and enter the inner interpreter with
`INTERPRET` as the first word in the test thread.

At this point you should have a working interactive FORTH prompt. Try typing
`DUP`, `DROP`, and arithmetic expressions to verify they execute correctly.

---

## Questions to Think About

1. `WORD` skips leading spaces. What happens if the user types only spaces and
   hits Return? What should `WORD` do - return a zero-length token, or keep
   waiting for input?

2. `NUMBER` currently only handles unsigned decimal. How would you extend it
   to handle negative numbers (a leading `-`)? How would you handle hex input
   (a leading `$` or `0x`)?

3. `EXECUTE` is similar to the dispatch in `NEXT`. Could you implement
   `EXECUTE` as a colon definition that uses other primitives, or does it
   need to be a primitive itself? Why?

4. When hand-compiling `INTERPRET`, you must calculate branch offsets
   manually. The offset in `0BRANCH` is relative to the cell *after* the
   offset itself. Draw out the thread on paper and verify each offset before
   assembling.

5. When `INTERPRET` encounters an unknown word, it prints `?`. In a more
   complete FORTH, what else might you want to do on an error? What state
   might need to be reset?

6. Right now there is no stack underflow protection. If you type `DROP`
   repeatedly, the parameter stack pointer will walk past its initial position
   and start reading garbage. What would it take to detect this? Consider:
   where would you store the "empty stack" sentinel, which primitives would
   need to check it, and what should happen when underflow is detected? Is
   there a way to provide *some* protection without modifying every primitive?

---

## Stretch Goals

- **Base variable**: Add a `BASE` variable (a 2-byte cell in memory) that
  `NUMBER` uses instead of hardcoded 10. Implement `DECIMAL` and `HEX` as
  words that store 10 or 16 into `BASE`. Then extend `NUMBER` to handle hex
  digits `A`-`F`.
- **. (dot)**: Implement `.` ( n -- ) which pops a number and prints it in
  the current base. This requires a division routine (or repeated subtraction)
  to extract digits. Once you have `.`, you can use FORTH interactively to
  check arithmetic results without the debugger.
- **CR and SPACE**: Implement `CR` ( -- ) which emits a carriage return and
  line feed, and `SPACE` ( -- ) which emits a space. These are trivial with
  `EMIT` but useful enough to deserve dictionary entries.
- **ECHO**: After reading a line in `WORD`, echo it back with a newline before
  processing. This makes the interpreter feel more responsive and is standard
  behavior on many FORTH systems.
