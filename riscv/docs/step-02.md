# Step 2: Stack Initialization

## Goal

Write `_start` so that it sets up the data stack and return stack, then
exits cleanly. First runnable kernel code.

## Background

Before any Forth word can execute, `DSP` and `RSP` must point to valid
stack memory. We allocate both stacks as `.bss` buffers and initialize
the stack pointers to their top (high) addresses, since both stacks grow
downward.

On RISC-V, there is no hardware stack pointer for the Forth stacks — we
manage them entirely in software using `s2` (RSP) and `s3` (DSP).

## Stack Convention

Both stacks are **full-descending**: the pointer points to the last item
pushed, and grows toward lower addresses.

- **Push:** decrement pointer by 4, then store
- **Pop:** load from pointer, then increment by 4

## Files

- `forth.inc` — add stack size constants and buffer labels (update)
- `forth.s` — implement `_start` with stack setup and `exit` syscall (new)

## Verification

`make run` exits cleanly (no crash, exit code 0). Step through with
`make debug` and confirm `DSP` and `RSP` hold the expected addresses
after initialization.

## Next Step

[Step 3: NEXT macro and EXIT](step-03.md)
