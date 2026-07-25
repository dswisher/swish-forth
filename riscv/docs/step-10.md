# Step 10: Outer Interpreter

## Goal

Implement a minimal outer interpreter: a REPL that reads a word from
input, looks it up in the dictionary, and either executes it (interpret
mode) or compiles it (compile mode). Numbers are parsed and pushed as
literals. This is the first interactive Forth prompt.

## Background

The outer interpreter is the loop that drives everything visible to the
user. It can itself be written in Forth once enough primitives exist —
that is the goal here. `WORD` already exists from step 8; the remaining
assembly pieces are:

### Assembly primitives needed

| Word | Description |
|------|-------------|
| `FIND` | Search the dictionary for a word by name; return CFA and flags, or 0 |
| `NUMBER` | Parse a string as a number; push value and success flag |
| `EXECUTE` | Pop a CFA and execute that word |
| `REFILL` | Read a line from input into the input buffer, reset `>IN` |

### `FIND`

`FIND` walks the dictionary chain from `LATEST`, comparing the counted
string against each entry's name field. Returns the CFA and a found/not-found
flag if found, or the original string and 0 if not found.

Stack effect: `( addr -- cfa 1 | cfa -1 | addr 0 )`

The sign of the flag distinguishes immediate words (1) from normal words
(-1), matching the Forth-2012 definition.

Forth-2012 reference: [`FIND`](https://forth-standard.org/standard/core/FIND)

### `NUMBER`

`NUMBER` converts a counted string to an integer, respecting the current
`BASE`. Returns a success flag so the interpreter can report an error on
unknown words.

Stack effect: `( addr len -- n true | addr len false )`

### `EXECUTE`

`EXECUTE` pops an address (a CFA) and jumps to the code it points to,
as if `NEXT` had dispatched it.

Stack effect: `( cfa -- )`

Forth-2012 reference: [`EXECUTE`](https://forth-standard.org/standard/core/EXECUTE)

### `REFILL`

`REFILL` reads one line from the input source (via `KEY`), stores it in
the input buffer, sets `SOURCE` to reflect the new contents, and resets
`>IN` to 0. Returns a flag: true if input was available, false at end of
input.

Stack effect: `( -- flag )`

Forth-2012 reference: [`REFILL`](https://forth-standard.org/standard/core/REFILL)

### `INTERPRET` (written in Forth)

Once the above primitives exist, `INTERPRET` can be written as a Forth
word:

```forth
: INTERPRET
    BEGIN
        BL WORD DUP C@ WHILE
        FIND
        DUP IF
            STATE @ 0= OVER 0< OR IF
                EXECUTE
            ELSE
                ,
            THEN
            DROP
        ELSE
            DROP NUMBER DROP
            STATE @ IF
                LIT , ,
            THEN
        THEN
    REPEAT
    DROP ;
```

### `QUIT` (written in Forth)

`QUIT` is the top-level loop: it calls `REFILL` and `INTERPRET` forever.

```forth
: QUIT
    BEGIN
        REFILL DROP
        INTERPRET
    AGAIN ;
```

## Files

- `forth.s` — add `FIND`, `NUMBER`, `EXECUTE`, `REFILL` (update)
- `forth.fs` — add `INTERPRET`, `QUIT` in Forth (new)

## Verification

Run the system and type simple expressions at the prompt:

- A number followed by Enter — should push silently
- `.` (dot) — should print the top of stack (implement `.` first in `forth.fs`)
- A colon definition — should compile and be callable

## Next Step

[Step 11: BLOCK and LOAD](step-11.md)
