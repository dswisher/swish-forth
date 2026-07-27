# Step 12: Core Word Set in Forth

## Goal

Implement the Forth-2012 core word set as Forth source loaded from blocks
at boot time. From this point forward, all development happens in the
editor with real Forth syntax.

## Background

The kernel starts by loading block 0 (`0 LOAD`), which serves as a
bootstrap: it loads additional blocks that define the remaining core
words, then hands off to the interactive loop (`QUIT`). At that point
the user is dropped into a Forth REPL with a growing standard word set.

### Dictionary shadowing

Because `FIND` walks the dictionary from `LATEST` backward, any Forth
word defined in a loaded block will **shadow** an assembly word of the
same name. This means the assembly kernel provides a fallback ("escape
hatch") and the Forth version takes over once loaded. Words that must
remain in assembly (because they touch registers or the return stack
in ways Forth code cannot express) are listed below.

## Bootstrap chain

```
_start
  → cold / boot_cfa: 0 LOAD
     → block 0: loads blocks 1..N, then QUIT
        → block 1: stack words
        → block 2: arithmetic
        → block 3: comparisons and logic
        → block 4: control flow (IF/THEN, BEGIN/AGAIN, etc.)
        → block 5: loops (DO/LOOP, I, J, LEAVE)
        → block 6: memory and variables
        → block 7: strings and output
        → block N: redefines QUIT with prompt and error messages
```

As each block is loaded, new words are appended to the dictionary.
By the time block N calls `QUIT`, the full core word set is available
at the interactive prompt.

## Suggested block layout

```
blocks/
  block-00.fth     # bootstrap: load blocks 1..N, then QUIT
  block-01.fth     # stack: 2DUP, 2DROP, 2SWAP, 2OVER, NIP, TUCK, ROT, -ROT
  block-02.fth     # arithmetic: ABS, MIN, MAX, MOD, /, */, UM/MOD, etc.
  block-03.fth     # comparisons & logic: =, <>, <, >, 0>, AND, OR, XOR, NOT
  block-04.fth     # control flow: IF/ELSE/THEN, BEGIN/AGAIN/UNTIL/WHILE/REPEAT
  block-05.fth     # loops: DO/LOOP, DO/+LOOP, I, J, LEAVE, UNLOOP
  block-06.fth     # memory: CELL+, CELLS, CHARS, ALLOT, FILL, MOVE, ALIGN, ALIGNED
  block-07.fth     # variables: CONSTANT, VARIABLE, VALUE, TO, CREATE/DOES>
  block-08.fth     # output: .S, U., .R, CR, SPACE, SPACES, DUMP
  block-09.fth     # strings: COUNT, ACCEPT, S", .", C", SEARCH, COMPARE
  block-10.fth     # tools: WORDS, SEE, ? (optional)
  block-11.fth     # redefined QUIT (prompt, ok/error reporting), ABORT, ABORT"
  block-12.fth     # interpreter: redefined INTERPRET (if desired)
```

### Block 0 template

```forth
( Bootstrap: load the core word set, then enter the REPL. )
1 LOAD  2 LOAD  3 LOAD  4 LOAD  5 LOAD
6 LOAD  7 LOAD  8 LOAD  9 LOAD 10 LOAD
11 LOAD
QUIT
```

Once `THRU` is available (DO/LOOP from block 5), the individual loads
can be replaced with `1 11 THRU`.

### Words that shadow assembly primitives

| Forth definition in block | Shadows assembly word |
|---|---|
| `QUIT` (block 11) | Assembly `QUIT` |
| `.` (block 8) | Assembly `DOT` |
| `TYPE` (block 9) | Assembly `TYPE` |
| `WORD` (optional) | Assembly `WORD` |
| `NUMBER` (optional) | Assembly `NUMBER` |
| `AND` (block 3) | Assembly `AND` |
| `OR` (block 3) | Assembly `OR` |

## Words that must remain in assembly

A few words are difficult or impossible to implement purely in Forth:

| Word | Reason |
|---|---|
| `UM*` | 32x32→64 multiply; needs 64-bit result |
| `UM/MOD` | 64÷32; needs double-length dividend |
| `DOCOL`, `EXIT`, `NEXT` | Threading model internals |
| `>R`, `R>`, `R@` | Direct return-stack manipulation |
| `@`, `!`, `C@`, `C!` | Memory access primitives |
| `KEY`, `EMIT` | Hardware I/O |
| `EXECUTE` | Dynamic CFA dispatch |
| `BRANCH`, `0BRANCH` | Control flow primitives |
| `LIT` | Inline literal |
| `(DO)`, `(LOOP)`, `(+LOOP)` | Loop runtime primitives (if Forth loops are supported) |

## Forth-2012 Reference

- [Core word set](https://forth-standard.org/standard/core)
- [Core extension word set](https://forth-standard.org/standard/core)
- [Block word set](https://forth-standard.org/standard/block)

## Files

- `blocks/block-NN.fth` — Forth source, one block per file (new and ongoing)
- `forth.s` — assembly kernel may get new primitives to support Forth words
- `forth.inc` — constants (may grow as new primitives are added)

## Verification

A growing test suite of Forth words exercised interactively. The
[forth-foundation-test suite](https://github.com/gerryjackson/forth2012-test-suite)
provides a standard test harness for Forth-2012 compliance.

As blocks are loaded, test each word manually at the prompt (e.g.
`5 3 MIN .` should print `3`). When enough control-flow words exist,
test files can be loaded via blocks.
