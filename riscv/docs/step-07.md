# Step 7: EMIT and KEY

## Goal

Implement `EMIT` (output one character) and `KEY` (input one character).
These are the I/O primitives everything else depends on. First visible
output from the Forth kernel itself.

## Background

Both words are thin wrappers around platform UART routines. No buffering,
no formatting — just raw character I/O. The platform driver provides
`platform_putc` and `platform_getc`; `EMIT` and `KEY` call them directly.

### EMIT

`EMIT` pops a character code from the data stack and writes it to the
output device.

Stack effect: `( char -- )`

```asm
defword "EMIT", EMIT, ZBRANCH_header
    lw      a0, 0(s3)       # a0 = char
    addi    s3, s3, 4       # pop DSP
    call    platform_putc
    NEXT
```

### KEY

`KEY` reads one character from the input device and pushes it onto the
data stack. Blocks until a character is available.

Stack effect: `( -- char )`

```asm
defword "KEY", KEY, EMIT_header
    call    platform_getc
    addi    s3, s3, -4      # push DSP
    sw      a0, 0(s3)       # *DSP = char
    NEXT
```

### Platform driver interface

| Symbol | Description |
|--------|-------------|
| `platform_putc` | Transmit char in `a0`; clobbers `t0`, `t1` |
| `platform_getc` | Receive char into `a0`, blocking; clobbers `t0`, `t1` |

For the QEMU `virt` machine these are simple NS16550A UART poll loops.
See `platform/qemu-virt.s` for the implementation and
[docs/bare-metal.md](bare-metal.md) for the hardware details.

## Forth-2012 Reference

- [`EMIT`](https://forth-standard.org/standard/core/EMIT)
- [`KEY`](https://forth-standard.org/standard/core/KEY)

## Files

- `platform/qemu-virt.s` — `platform_putc`, `platform_getc`, `EMIT`, `KEY`

## Verification

The test harness in `forth.s` pushes the ASCII code for `!` (33) with `LIT`
and calls `EMIT`. Running `make run` should print `!` and exit cleanly.

For `KEY`: add a hand-threaded sequence calling `KEY` then `EMIT` to echo a
character back. In the two-window debug setup (`make qemu-wait` /
`make gdb-attach`), type a character in the QEMU terminal after the `read`
unblocks.

## Next Step

[Step 8: Dictionary Structure, : and ;](step-08.md)
