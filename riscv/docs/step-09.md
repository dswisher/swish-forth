# Step 9: Outer Interpreter

## Goal

Implement a minimal outer interpreter: a REPL that reads a word from
input, looks it up in the dictionary, and either executes it (interpret
mode) or compiles it (compile mode). Numbers are parsed and pushed as
literals. This is the first interactive Forth prompt.

## Background

The outer interpreter is the loop that drives everything visible to the
user. It can itself be written in Forth once enough primitives exist —
that is the goal here. The assembly pieces needed to support it are:

### Assembly primitives needed

| Word | Description |
|------|-------------|
| `WORD` | Read the next whitespace-delimited word from input into a buffer; push address and length |
| `FIND` | Search the dictionary for a word by name; push CFA or 0 |
| `NUMBER` | Parse a string as a number; push value and success flag |
| `EXECUTE` | Pop a CFA and execute that word |
| `INTERPRET` | The outer interpreter loop (can be written in Forth) |

### WORD

`WORD` reads characters from the input stream (using `KEY`), skipping
leading whitespace, collecting characters until the next whitespace, and
storing the result in a scratch buffer as a counted string (length byte
followed by characters).

Stack effect: `( -- addr len )`

### FIND

`FIND` walks the dictionary chain from `LATEST`, comparing names. Returns
the CFA if found, 0 if not.

Stack effect: `( addr len -- cfa | 0 )`

### NUMBER

`NUMBER` converts a counted string to an integer, respecting the current
`BASE`. Returns a success flag so the interpreter can report an error on
unknown words.

Stack effect: `( addr len -- n true | addr len false )`

### EXECUTE

`EXECUTE` pops an address (a CFA) and jumps to the code it points to,
as if NEXT had dispatched it.

Stack effect: `( cfa -- )`

### INTERPRET (written in Forth)

Once the above primitives exist, `INTERPRET` can be written as a Forth
word:

```forth
: INTERPRET
    BEGIN
        WORD FIND
        DUP IF
            STATE @ IF COMPILE, ELSE EXECUTE THEN
        ELSE
            DROP NUMBER
            STATE @ IF LIT, THEN
        THEN
    AGAIN ;
```

## Forth-2012 Reference

- [`WORD`](https://forth-standard.org/standard/core/WORD)
- [`FIND`](https://forth-standard.org/standard/core/FIND)
- [`EXECUTE`](https://forth-standard.org/standard/core/EXECUTE)
- [`NUMBER`](https://forth-standard.org/standard/core) (internal)
- [`BASE`](https://forth-standard.org/standard/core/BASE)

## Files

- `forth.s` — add `WORD`, `FIND`, `NUMBER`, `EXECUTE` (update)
- `forth.fs` — add `INTERPRET`, `QUIT` in Forth (new)

## Verification

Run the system and type simple expressions at the prompt:
- A number followed by Enter — should push silently
- `.` (dot) — should print the top of stack (implement `.` first)
- A colon definition — should compile and be callable

## Next Step

[Step 10: File I/O and INCLUDE-FILE](step-10.md)
