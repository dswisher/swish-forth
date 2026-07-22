# Step 5: LIT, BRANCH, 0BRANCH

## Goal

Implement `LIT`, `BRANCH`, and `0BRANCH`. These are the words that make
hand-threaded colon definitions useful — without them you cannot encode
literals or control flow.

## Background

### LIT

`LIT` is an immediate word used by the compiler to push a literal value.
It is never typed by the user; the compiler emits it before each number
in a colon definition.

At runtime, `LIT` reads the next cell from the thread (the value that
follows it in the parameter field), pushes it onto the data stack, and
advances `IP` past it:

```
1. Push *IP onto data stack
2. IP += 4
3. NEXT
```

### BRANCH

`BRANCH` is an unconditional jump within a thread. The cell following it
in the thread is a **signed byte offset** from the address of that cell:

```
1. IP = IP + *IP     # offset is relative to the offset cell itself
3. NEXT
```

### 0BRANCH

`0BRANCH` is a conditional jump — it branches if the top of stack is zero
(false), otherwise falls through. It consumes the top of stack either way:

```
1. Pop n from data stack
2. If n == 0: IP = IP + *IP
   Else:      IP += 4
3. NEXT
```

These two words are sufficient to implement `IF/ELSE/THEN` and
`BEGIN/WHILE/REPEAT` at the Forth level later.

## Forth-2012 Reference

- [`BRANCH`](https://forth-standard.org/standard/core) — internal, not
  directly in the standard but universally present
- [`0BRANCH`](https://forth-standard.org/standard/core) — same

## Files

- `forth.s` — add `LIT`, `BRANCH`, `0BRANCH` (update)

## Verification

Construct a hand-threaded sequence that uses `LIT` to push values and
`0BRANCH` to conditionally skip a section. Verify with `make debug`.

## Next Step

[Step 6: DOCOL and Hand-Threaded Test](step-06.md)
