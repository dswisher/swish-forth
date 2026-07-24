# Step 10: BLOCK and LOAD

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

### BLOCK  ( u -- addr )

Return the address of block `u` in the read-only block region. No transfer
from disk — the data is already in memory.

```forth
: BLOCK  ( u -- addr )
    1024 *  block_base + ;
```

`block_base` is a constant assembled into `blocks.s` pointing to the start
of the block region.

### LOAD  ( u -- )

Interpret block `u` as Forth source.

```forth
: LOAD  ( u -- )
    BLOCK  1024  EVALUATE ;
```

`EVALUATE` is the standard word that interprets a string as Forth source.
It is implemented in a later step.

### THRU  ( u1 u2 -- )

Convenience word to load a range of blocks.

```forth
: THRU  ( u1 u2 -- )
    1+ SWAP DO  I LOAD  LOOP ;
```

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

## Files

- `tools/mkblocks.py` — host-side script to generate `blocks.s` (new)
- `blocks.s` — generated assembly containing block data (generated, not checked in)
- `forth.s` / `forth.fs` — add `BLOCK`, `LOAD`, `THRU` (update)
- `Makefile` — add rule to run `mkblocks.py` and assemble `blocks.s` (update)

## Verification

Create a small test file `test.fth` containing a colon definition. Generate
`blocks.s` with `mkblocks.py`, build, run, and `LOAD` block 0. Confirm the
defined word executes correctly.

## Next Step

[Step 11: Core Word Set in Forth](step-11.md)
