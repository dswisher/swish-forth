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

### Forth supporting words (written in Forth)

Before `INTERPRET` can be compiled, several control-flow and utility
words must be implemented in `forth.fs`. These are all compile-time words
that manipulate `HERE` and emit `BRANCH`/`0BRANCH` with computed offsets.
They can be written in Forth using only primitives already available.

#### `'` (tick)

`'` parses the next token and pushes its CFA. It is immediate — it
executes even in compile mode so that its result can be used by compiling
words like `IF`.

Stack effect: `( "<spaces>name" -- cfa )`

```forth
: '  PARSE-NAME FIND DUP 0= ABORT" ?" ;
```

`ABORT"` isn't available yet, so initially `?` can be omitted and an
unknown word will push 0 (detected by `IF` / `INTERPRET`).

#### `BL`

Push the ASCII code for space (32 = $20).

```forth
: BL  LIT 32 ;
```

#### `WORD` via `PARSE-NAME`

`WORD` parses a space-delimited token and returns it as a counted string
at `HERE`. At this stage a simpler wrapper around `PARSE-NAME` can suffice
if `FIND`/`NUMBER` accept `( c-addr u )` format directly.

#### Control-flow words

Each control-flow word computes an offset (in bytes) between a saved
position on the data stack and the current `HERE`, then compiles (or
backpatches) a `BRANCH` or `0BRANCH` instruction.

| Word | Stack (compile time) | Action |
|------|---------------------|--------|
| `BEGIN` | `( -- dest )` | Save `HERE` as loop entry point |
| `AGAIN` | `( dest -- )` | Compile `BRANCH` back to `dest` |
| `UNTIL` | `( dest -- )` | Compile `0BRANCH` back to `dest` |
| `IF` | `( -- orig )` | Compile `0BRANCH` placeholder, save address for backpatching |
| `THEN` | `( orig -- )` | Resolve `orig` to current `HERE` |
| `ELSE` | `( orig1 -- orig2 )` | Compile `BRANCH` placeholder, resolve `orig1` |
| `WHILE` | `( dest -- dest orig )` | Compile `0BRANCH` placeholder |
| `REPEAT` | `( dest orig -- )` | Compile `BRANCH` back to `dest`, resolve `orig` |

Implementations reference the CFA labels `BRANCH_cfa` and
`ZERO_BRANCH_cfa` via `'`:

```forth
: BEGIN   HERE @ ;
: AGAIN   ' BRANCH ,  HERE @  SWAP - , ;
: UNTIL   ' 0BRANCH ,  HERE @  SWAP - , ;
: IF      ' 0BRANCH ,  HERE @  LIT 0 , ;
: THEN    HERE @  OVER -  SWAP ! ;
: ELSE    ' BRANCH ,  HERE @  LIT 0 ,  SWAP  HERE @  SWAP -  SWAP ! ;
: WHILE   ' 0BRANCH ,  HERE @  LIT 0 ,  SWAP ;
: REPEAT  ' BRANCH ,  HERE @  OVER - ,  HERE @  SWAP -  SWAP ! ;
```

> **Note:** `' 0BRANCH` requires `0BRANCH` to be a Forth-visible name.
> The assembly primitive is `defword "0BRANCH", ZERO_BRANCH, ...`, so the
> name in the header is `0BRANCH` (not `ZERO_BRANCH`). `FIND` searches by
> that header name, so `' 0BRANCH` works correctly.

#### Ordering in `forth.fs`

These words depend on `FIND` (for `'`), so the layering is:

```
forth.s primitives:  FIND, NUMBER, EXECUTE, REFILL
forth.fs:            BL, ', IF, THEN, ELSE, BEGIN, AGAIN, UNTIL, ...
                     WHILE, REPEAT
                     WORD
                     . (DOT)        -- display top of stack
                     INTERPRET
                     QUIT
```

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
- `forth.fs` — add `BL`, `'`, `IF`, `THEN`, `ELSE`, `BEGIN`, `AGAIN`, `UNTIL`, `WHILE`, `REPEAT`, `WORD`, `.` (DOT), `INTERPRET`, `QUIT` in Forth (new)

## Verification

Run the system and type simple expressions at the prompt:

- A number followed by Enter — should push silently
- `.` (dot) — should print the top of stack (implement `.` first in `forth.fs`)
- A colon definition — should compile and be callable

## Next Step

[Step 11: BLOCK and LOAD](step-11.md)
