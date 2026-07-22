# Step 10: File I/O and INCLUDE-FILE

## Goal

Implement file I/O primitives and `INCLUDE-FILE`. After this step, Forth
source files edited in Neovim on the host can be loaded directly into the
running kernel. This is the escape from assembly — all subsequent words
are written in Forth.

## Background

### Linux File Syscalls

| Syscall | Number | Purpose |
|---------|--------|---------|
| `openat` | 56 | Open a file, returns file descriptor |
| `read` | 63 | Read bytes from a file descriptor |
| `close` | 57 | Close a file descriptor |

### Assembly primitives needed

| Word | Stack effect | Description |
|------|-------------|-------------|
| `OPEN-FILE` | `( addr len fam -- fd ior )` | Open a file by name |
| `READ-FILE` | `( addr len fd -- u ior )` | Read bytes from a file |
| `CLOSE-FILE` | `( fd -- ior )` | Close a file |

`ior` is an I/O result code: 0 means success, non-zero is an error code
(the negated Linux errno).

`fam` is the file access method: `R/O` (read-only) is all we need for
loading source files.

### INCLUDE-FILE (written in Forth)

`INCLUDE-FILE` takes a file-id (file descriptor) on the stack, redirects
the input source to that file, and runs the interpreter until EOF. It is
the Forth-2012 standard word for loading source files.

```forth
: INCLUDE-FILE  ( fileid -- )
    ... redirect input, run INTERPRET until EOF, restore input ... ;
```

### INCLUDED (written in Forth)

A convenience wrapper that takes a filename string and calls `OPEN-FILE`
then `INCLUDE-FILE`:

```forth
: INCLUDED  ( addr len -- )
    R/O OPEN-FILE THROW
    INCLUDE-FILE ;
```

## Forth-2012 Reference

- [`INCLUDE-FILE`](https://forth-standard.org/standard/file/INCLUDE-FILE)
- [`INCLUDED`](https://forth-standard.org/standard/file/INCLUDED)
- [`OPEN-FILE`](https://forth-standard.org/standard/file/OPEN-FILE)
- [`READ-FILE`](https://forth-standard.org/standard/file/READ-FILE)
- [`CLOSE-FILE`](https://forth-standard.org/standard/file/CLOSE-FILE)
- [`R/O`](https://forth-standard.org/standard/file/RO)

## Files

- `forth.s` — add `OPEN-FILE`, `READ-FILE`, `CLOSE-FILE`, `R/O` (update)
- `forth.fs` — add `INCLUDE-FILE`, `INCLUDED` in Forth (update)

## Verification

Create a small test file `test.fs` containing a colon definition. Load it
with `INCLUDED` and call the defined word. Confirm it executes correctly.

## Next Step

[Step 11: Core Word Set in Forth](step-11.md)
