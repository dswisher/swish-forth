# Lab 7: The Outer Interpreter

## Objectives

- Implement `EMIT` and `KEY` - the basic I/O primitives
- Implement `WORD` - reads one whitespace-delimited token from input
- Implement `NUMBER` - converts a string to a 16-bit integer
- Implement the outer interpreter loop `INTERPRET` - the FORTH prompt
- Boot into an interactive FORTH session

## Prerequisites

- Lab 6 complete - `LIT` and `FIND` working, full dictionary in place
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
    DUP 0= IF DROP ... THEN       handle end of input
    FIND        ( addr len -- cfa | 0 )   look up in dictionary
    IF          found: execute it
        EXECUTE
    ELSE        not found: try to parse as a number
        NUMBER
        IF      valid number: already on the stack
        ELSE    error: unknown word
            ERROR
        THEN
    END
AGAIN
```

In this lab you will implement the pieces that make this loop work, then wire
them together into a running interpreter.

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
    sta WX
    lda PSP+1,x     ; load CFA hi
    sta WX+1
    inx
    inx
    ldy #0
    lda (WX),y      ; read code address lo
    sta W
    iny
    lda (WX),y      ; read code address hi
    sta W+1
    jmp (W)
```

Notice this is essentially the second half of `NEXT` - it reads through the
CFA to get the code address and jumps to it. `W` is used here (not `WX`)
because if the word being executed is a colon definition, `DOCOL` will need
`WX` intact... actually, think carefully: what does `DOCOL` actually read?
Make sure you use the right register here.

### INTERPRET - Putting It Together

`INTERPRET` is a colon definition - the outer interpreter loop written in
FORTH itself (as a thread of CFAs). Because you now have `FIND`, `EXECUTE`,
`LIT`, and the stack primitives, you can write `INTERPRET` as a colon
definition in assembly (a hand-compiled FORTH word) rather than in machine
code.

The loop structure in pseudo-FORTH:

```forth
: INTERPRET
    BEGIN
        WORD
        DUP 0= IF DROP ... THEN
        FIND
        IF
            EXECUTE
        ELSE
            NUMBER
            IF DROP ELSE ERROR THEN
        THEN
    AGAIN ;
```

Implementing `BEGIN`/`AGAIN` and `IF`/`ELSE`/`THEN` requires branching
primitives (`BRANCH` and `0BRANCH`) which we have not yet built. For this
lab, implement `INTERPRET` as a machine-code subroutine rather than a pure
FORTH colon definition. This is a pragmatic shortcut that gets you to an
interactive prompt without needing the compiler infrastructure. The plan is:

1. Write `INTERPRET` as a simple assembly loop that calls the FORTH words
   (`WORD`, `FIND`, `EXECUTE`, `NUMBER`) via `JSR` to their code labels
   directly, rather than going through the inner interpreter
2. Once you have branching words in a later lab, you can rewrite `INTERPRET`
   as a proper colon definition

---

## The Assignment

Continue working in a new `lab-07/` directory. Copy your `forth.asm`,
`forth.cfg`, and `Makefile` from `lab-06/`.

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

1. If `IBUF` pointer is at or past the end of the buffer, refill: call
   `CHRIN` in a loop until `$0D` (carriage return), storing each character
   into `input_buf`. Reset the pointer to the start of the buffer. Optionally
   print a prompt (`OK `) before reading.
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

Wire everything together into an `INTERPRET` loop. Implement it as an
assembly subroutine (not a FORTH colon definition) that:

1. Prints a prompt (`OK `)
2. Calls `WORD` to read a token
3. Calls `FIND` to look it up
4. If found: calls `EXECUTE`
5. If not found: calls `NUMBER`; if that fails, prints `?` and the unknown
   word
6. Loops back to step 1

Change `main` to initialize the stacks and then call `INTERPRET` (via `JSR`
or by entering the inner interpreter with `INTERPRET` as the first thread
entry).

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

4. The `INTERPRET` loop calls FORTH words from assembly using `JSR`. This
   means the hardware stack is being used for both FORTH's return stack and
   for the `JSR` return addresses. Is there a conflict? What is the maximum
   nesting depth available?

5. When `INTERPRET` encounters an unknown word, it prints `?`. In a more
   complete FORTH, what else might you want to do on an error? What state
   might need to be reset?

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
