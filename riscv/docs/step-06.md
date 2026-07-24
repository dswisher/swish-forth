# Step 6: DOCOL and Hand-Threaded Test

## Goal

Implement `DOCOL`, the entry routine for all colon definitions. Then write
a complete hand-threaded colon definition and run it through the inner
interpreter. This is the "it's alive" moment — the full threading engine
working end-to-end.

## Background

### DOCOL

When the inner interpreter encounters a colon definition, it jumps to
`DOCOL` (via the code field). `DOCOL`'s job is to save the current `IP`
on the return stack and set `IP` to the parameter field of the current
word (i.e., the list of CFAs that make up the definition):

```
1. Push IP onto return stack     # *RSP = IP; RSP -= 4
2. IP = W + 4                    # W points to CFA; W+4 is the first cell
                                 # of the parameter field
3. NEXT
```

`EXIT` (from Step 3) is the matching operation — it pops `IP` from the
return stack to return to the caller.

### Hand-Threaded Test

A hand-threaded definition is one we write by hand as a list of addresses
in the `.rodata` section, rather than having the compiler generate it. For
example, a word that duplicates the top of stack and then exits:

```asm
.rodata
test_word_cfa:
    .word DOCOL_code    # code field: points to DOCOL
    .word DUP_cfa       # parameter field: call DUP
    .word EXIT_cfa      #   then EXIT
```

To run it, `_start` constructs a small calling thread in `.rodata` that
contains `test_word_cfa`, loads `IP` to point at that thread, and fires
`NEXT`. NEXT fetches `test_word_cfa` into `W`, loads `DOCOL_code` from
the code field, and jumps to `DOCOL`. This exercises the complete path:

```
NEXT -> DOCOL -> DUP -> EXIT -> back to calling thread
```

Pointing `IP` directly at the parameter field would bypass `DOCOL`
entirely and not test what we care about.

## Files

- `forth.s` — add `DOCOL`, hand-threaded test in `_start` (update)

## Verification

Use `make debug` to single-step through the entire execution of the
hand-threaded word. Confirm:
- `DOCOL` correctly saves and updates `IP`
- The parameter field words execute in order
- `EXIT` correctly restores `IP`
- The data stack has the expected contents throughout

## Next Step

[Step 7: EMIT and KEY](step-07.md)
