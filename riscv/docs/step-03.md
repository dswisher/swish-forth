# Step 3: NEXT Macro and EXIT

## Goal

Implement the heart of the inner interpreter: the `NEXT` macro. Also
implement `EXIT`, the first real Forth primitive, which uses `NEXT`.

## Background

### NEXT

`NEXT` is not a Forth word — it is a macro that is expanded inline at the
end of every primitive. It advances `IP` to the next word and jumps to its
code. In ITC:

```
1. Load the cell at IP into W       # W = *IP (the CFA of the next word)
2. Advance IP by one cell           # IP += 4
3. Load the cell at W into a temp   # tmp = *W (the code field contents)
4. Jump to tmp                      # jump to the code
```

In RISC-V assembly:

```asm
.macro NEXT
    lw      W, 0(IP)        # W = *IP
    addi    IP, IP, 4       # IP += 4
    lw      TMP, 0(W)       # TMP = *W  (code field)
    jr      TMP             # jump to code
.endm
```

### EXIT

`EXIT` is the word that returns from a colon definition. It pops the saved
`IP` from the return stack and resumes execution there, then calls `NEXT`.

```
1. Pop old IP from return stack     # IP = *RSP; RSP += 4
2. NEXT
```

### Dictionary Entry Structure

Each word in the dictionary has this layout:

```
+------------------+
| Link field       |  4 bytes: pointer to previous word's header
+------------------+
| Name field       |  1 byte length + characters + padding to 4-byte align
+------------------+
| Code field (CFA) |  4 bytes: pointer to the code routine
+------------------+
| Parameter field  |  data or list of CFAs (for colon definitions)
+------------------+
```

The assembler macro `defword` will create this structure for each word.

## Files

- `forth.inc` — add `NEXT` macro and `defword` macro (update)
- `forth.s` — add `EXIT` word (update)

## Verification

Not directly runnable in isolation — `NEXT` and `EXIT` are exercised in
Step 6 when we run the first hand-threaded definition. However, review
the assembled output with `riscv64-linux-gnu-objdump -d forth` to confirm
the macro expands correctly.

## Next Step

[Step 4: Stack Primitives](step-04.md)
