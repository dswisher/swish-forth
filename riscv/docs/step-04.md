# Step 4: Stack Primitives

## Goal

Implement `DUP`, `DROP`, `SWAP`, and `OVER` — the core data stack
manipulation words. These are the first words that can be meaningfully
tested in isolation.

## Background

All four words manipulate `DSP` (the data stack pointer). Recall the
stack convention: DSP points to the **top item**, stack grows downward.

| Word | Stack effect | Description |
|------|-------------|-------------|
| `DUP` | `( n -- n n )` | Duplicate top of stack |
| `DROP` | `( n -- )` | Discard top of stack |
| `SWAP` | `( a b -- b a )` | Swap top two items |
| `OVER` | `( a b -- a b a )` | Copy second item to top |

Each word ends with `NEXT`.

## Forth-2012 Reference

- [`DUP`](https://forth-standard.org/standard/core/DUP)
- [`DROP`](https://forth-standard.org/standard/core/DROP)
- [`SWAP`](https://forth-standard.org/standard/core/SWAP)
- [`OVER`](https://forth-standard.org/standard/core/OVER)

## Files

- `forth.s` — add `DUP`, `DROP`, `SWAP`, `OVER` (update)

## Verification

Write a small hand-threaded test sequence in `_start` that:
1. Pushes known values onto the data stack directly (bypassing `LIT`,
   since that comes in step 5)
2. Calls each word's code field directly
3. Inspects results with GDB

Step through with `make debug`, checking register values and memory after
each instruction.

## Next Step

[Step 5: LIT, BRANCH, 0BRANCH](step-05.md)
