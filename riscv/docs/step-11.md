# Step 11: BLOCK, EVALUATE, and LOAD

## Goal

Make Forth source files loadable into the running kernel without filesystem
syscalls. After this step, the kernel can load and execute Forth source
written on the host, enabling the escape from assembly — all subsequent
words are written in Forth.

## Background

Because the kernel runs bare-metal (no OS, no filesystem), `INCLUDE-FILE`
is not available. Instead, Forth source is assembled directly into
read-only memory as 1 KB blocks following the ANS Forth BLOCK word set.

A host-side script (`tools/mkblocks.py`) reads `.fth` source files and
emits an assembly file (`blocks.s`) with the contents padded to 1024 bytes
per block. `blocks.s` is assembled and linked alongside `forth.s`; the
resulting binary contains the source in a read-only region that the Forth
`BLOCK` word indexes by block number.

On the Raspberry Pi Pico 2 the same block data lives in flash. The kernel
is identical; only the linker script changes.

## Word definitions

### PREPARE-EVAL  ( c-addr u -- ) [assembly primitive]

Save the current outer-interpreter state (input buffer contents,
`source_len`, and `>IN`) to dedicated backup areas, copy the string at
`(c-addr, u)` into the input buffer, and set `source_len = u`, `>IN = 0`.
After this, `INTERPRET` will process the new string as Forth source.

### RESTORE-SOURCE  ( -- ) [assembly primitive]

Restore the outer-interpreter state from the backup areas, returning the
input buffer to the state it had before the most recent `PREPARE-EVAL`.

### EVALUATE  ( c-addr u -- )

Interpret the string at `c-addr` of length `u` as Forth source:

```forth
: EVALUATE  ( c-addr u -- )
    PREPARE-EVAL  INTERPRET  RESTORE-SOURCE ;
```

`EVALUATE` is a colon definition built on two assembly primitives.
`PREPARE-EVAL` saves the current outer-interpreter state and redirects the
input buffer to the given string.  `INTERPRET` does the actual
tokenisation and execution.  `RESTORE-SOURCE` puts the input buffer back
so the caller can resume normal interactive operation.

### BLOCK  ( u -- addr )

Return the address of block `u` in the read-only block region (provided by
`blocks.s`).  Each block is 1024 bytes.  Implemented as an assembly
primitive because `MUL` (needed for `1024 *`) is not yet available in the
kernel:

```asm
; BLOCK (u -- addr):  addr = block_base + u * 1024
lw      t0, 0(s3)            ; t0 = u
slli    t0, t0, 10           ; t0 = u << 10 = u * 1024
la      t1, block_base       ; t1 = base address of block region
add     t0, t0, t1           ; t0 = block_base + u*1024
sw      t0, 0(s3)            ; replace u with addr
NEXT
```

`block_base` is a symbol defined in `blocks.s` pointing to the start of
the block region in `.rodata`.  A minimal placeholder `blocks.s` (one
empty 1024-byte block) exists so the kernel builds without `.fth` sources.

### LOAD  ( u -- )

Interpret block `u` as Forth source:

```forth
: LOAD  ( u -- )
    BLOCK  1024  EVALUATE ;
```

### THRU  ( u1 u2 -- )

Convenience word to load a range of blocks:

```forth
: THRU  ( u1 u2 -- )
    1+ SWAP DO  I LOAD  LOOP ;
```

Note: `THRU` depends on `DO`/`LOOP`/`I`, which are part of the core word
set implemented in step 12.  `THRU` is defined in step 11 but will not
work until those words are available.

## `tools/mkblocks.py` script

Takes one or more `.fth` source files and emits an assembly file with the
block data:

```
usage: mkblocks.py [-o output.s] source1.fth [source2.fth ...]
```

Each 1024-byte block corresponds to one screen of Forth source (the
traditional Forth block editor unit). Lines are padded or truncated to fit.

## ANS Forth BLOCK word set

| Word | Stack | Description |
|------|-------|-------------|
| `BLOCK` | `( u -- addr )` | Address of block u |
| `LOAD` | `( u -- )` | Interpret block u |
| `THRU` | `( u1 u2 -- )` | Load blocks u1 through u2 |
| `LIST` | `( u -- )` | Display block u (optional, useful for debugging) |

## Forth-2012 Reference

- [`BLOCK`](https://forth-standard.org/standard/block/BLOCK)
- [`LOAD`](https://forth-standard.org/standard/block/LOAD)
- [`THRU`](https://forth-standard.org/standard/block/THRU)
- [`EVALUATE`](https://forth-standard.org/standard/core/EVALUATE)

## Files

- `tools/mkblocks.py` — host-side script to generate `blocks.s` (new)
- `blocks.s` — generated assembly containing block data (generated, not
  checked in); a minimal placeholder is provided so the kernel builds
- `forth.s` / `forth.fs` — add `PREPARE-EVAL`, `RESTORE-SOURCE`, `BLOCK`,
  `EVALUATE`, `LOAD`, `THRU` (update)
- `forth.inc` — increase `IN_BUF_SIZE` from 256 to 1024 to accommodate
  one full block (update)
- `Makefile` — add `blocks.s` to the source list (update)

## Verification

Create a small test file `test.fth` containing a colon definition. Generate
`blocks.s` with `mkblocks.py`, build, run, and `LOAD` block 0. Confirm the
defined word executes correctly.

## Next Step

[Step 12: Core Word Set in Forth](step-12.md)

