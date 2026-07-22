# Step 7: EMIT and KEY

## Goal

Implement `EMIT` (output one character) and `KEY` (input one character).
These are the I/O primitives everything else depends on. First visible
output from the Forth kernel itself.

## Background

Both words are thin wrappers around Linux syscalls. No buffering, no
formatting — just raw character I/O.

### EMIT

`EMIT` pops a character code from the data stack and writes it to stdout.

Stack effect: `( char -- )`

```
syscall: write(fd=1, buf=&char, len=1)
  a7 = 64    # SYS_write
  a0 = 1     # stdout
  a1 = addr of char (we'll use a scratch buffer in .bss)
  a2 = 1
  ecall
```

### KEY

`KEY` reads one character from stdin and pushes its code onto the data
stack. Blocks until a character is available.

Stack effect: `( -- char )`

```
syscall: read(fd=0, buf=&char, len=1)
  a7 = 63    # SYS_read
  a0 = 0     # stdin
  a1 = addr of scratch buffer
  a2 = 1
  ecall
```

### Syscall Register Convention (RISC-V Linux)

| Register | Role |
|----------|------|
| `a7` | Syscall number |
| `a0` | Arg 1 / return value |
| `a1` | Arg 2 |
| `a2` | Arg 3 |
| `ecall` | Invoke the syscall |

Note: `a0`–`a6` are caller-saved, so they can be used freely inside
primitives without conflicting with the Forth registers (`s0`–`s4`).

## Forth-2012 Reference

- [`EMIT`](https://forth-standard.org/standard/core/EMIT)
- [`KEY`](https://forth-standard.org/standard/core/KEY)

## Files

- `forth.s` — add `EMIT`, `KEY`, scratch char buffer in `.bss` (update)

## Verification

Write a hand-threaded sequence that uses `LIT` to push the ASCII code for
`'!'` and calls `EMIT`. Running `make run` should print `!` to the
terminal. Also test `KEY` followed by `EMIT` to echo a character back.

## Next Step

[Step 8: Dictionary Structure, : and ;](step-08.md)
