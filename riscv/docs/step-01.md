# Step 1: Register Definitions and Memory Layout

## Goal

Establish the foundational constants and register assignments that every
subsequent step depends on. No executable code yet — just a `.inc` file
that names things consistently.

## Background

### Threading Model: Indirect Threaded Code (ITC)

In ITC, every Forth word has a **code field** containing a pointer to a
machine-code routine. To execute a word, the inner interpreter (NEXT):

1. Loads the address in the code field into `W`
2. Jumps to the address that `W` points to

This extra level of indirection is what makes it "indirect" threaded. The
payoff is simplicity: every colon definition has the same code field
(`DOCOL`), and primitives just point directly to their own code.

### Register Assignments

| Register | Name | Role |
|----------|------|------|
| `s0` | `IP` | Instruction Pointer — address of the next word to execute |
| `s1` | `W` | Working register — address of the current word's code field |
| `s2` | `RSP` | Return Stack Pointer |
| `s3` | `DSP` | Data Stack Pointer |
| `s4` | `TMP` | Scratch register for use inside primitives |

The `s` (saved) registers are used so that if we ever call into C code,
these registers are preserved across the call.

### Memory Layout

```
High addresses
+------------------+  <- rsp_top (label in .bss)
|   Return Stack   |  grows downward, RSP points to top item
+------------------+  <- rsp_top - RSTACK_SIZE
|                  |
+------------------+  <- dsp_top (label in .bss)
|   Data Stack     |  grows downward, DSP points to top item
+------------------+  <- dsp_top - DSTACK_SIZE
|                  |
+------------------+
|   Dictionary     |  grows upward; HERE tracks next free byte
|                  |
+------------------+  <- _end (end of .bss, provided by linker)
|   .bss           |  uninitialized variables and buffers
+------------------+
|   .data          |  initialized variables
+------------------+
|   .text          |  assembly code
+------------------+
Low addresses
```

## Files

- `forth.inc` — register aliases and memory layout constants (new)

## Verification

Assemble `forth.s` (which will `.include "forth.inc"`) with no errors.

## Next Step

[Step 2: Stack Initialization](step-02.md)
