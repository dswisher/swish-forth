# Step 11: Core Word Set in Forth

## Goal

Implement the Forth-2012 core word set as Forth source files loaded from
disk. From this point forward, all development happens in Neovim with
real Forth syntax.

## Background

With `INCLUDE-FILE` working, the remaining standard words can be written
in Forth and loaded at startup. The kernel's `_start` will eventually
just set up the stacks, load a bootstrap file, and enter the interpreter.

### Suggested file organisation

```
riscv/
  forth.s          # assembly kernel
  forth.fs         # bootstrap: loads the files below in order
  core/
    stack.fs       # 2DUP, 2DROP, 2SWAP, 2OVER, NIP, TUCK, ROT, -ROT
    arithmetic.fs  # ABS, MIN, MAX, MOD, /
    logic.fs       # AND, OR, XOR, NOT, LSHIFT, RSHIFT
    comparison.fs  # =, <>, <, >, <=, >=, 0=, 0<, 0>
    control.fs     # IF/ELSE/THEN, BEGIN/AGAIN, BEGIN/WHILE/REPEAT
    loops.fs       # DO/LOOP, DO/+LOOP, LEAVE, I, J
    memory.fs      # CELL+, CELLS, CHAR+, CHARS, ALLOT, FILL, MOVE
    variables.fs   # VARIABLE, CONSTANT, VALUE, TO
    strings.fs     # COUNT, TYPE, S", ." 
    output.fs      # . (dot), .S, U., CR, SPACE, SPACES
    input.fs       # ACCEPT, REFILL
    tools.fs       # WORDS, SEE (optional)
```

### Words that may still need assembly

A few words are difficult or impossible to implement purely in Forth:

| Word | Reason |
|------|--------|
| `UM*` | 32x32→64 multiply; needs 64-bit result |
| `UM/MOD` | 64÷32; needs double-length dividend |
| `FM/MOD` | Floored division variant |
| `SM/REM` | Symmetric division variant |
| `THROW`/`CATCH` | Requires saving/restoring the full machine state |

## Forth-2012 Reference

- [Core word set](https://forth-standard.org/standard/core)
- [Core extension word set](https://forth-standard.org/standard/core)
- [File access word set](https://forth-standard.org/standard/file)

## Files

- `forth.fs` — top-level bootstrap, loads core/ files (update)
- `core/*.fs` — standard word set implemented in Forth (new)

## Verification

A growing test suite of Forth words exercised interactively and
eventually via loaded test files. The [forth-foundation-test
suite](https://github.com/gerryjackson/forth2012-test-suite) provides
a standard test harness for Forth-2012 compliance.
