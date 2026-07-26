# AGENTS.md

## Ground rules

Agents should never issue `git` commands that alter the state of the local or remote repositories - no `git commit`, `git pull` or `git push`.
Informational commands like `git log` or `git diff` are fine.

## Debugging the RISC-V Forth kernel

Use GDB batch mode to inspect the running kernel directly rather than asking
the user to relay GDB output. The pattern is:

```bash
pkill -f "qemu-system-riscv32" 2>/dev/null; sleep 0.5
cd /Users/swisherd/git/dswisher/swish-forth/riscv
qemu-system-riscv32 -machine virt -nographic -bios none -kernel forth.elf -s -S &
sleep 1
riscv64-elf-gdb -q -batch -x /path/to/script.gdb forth.elf 2>&1
pkill -f "qemu-system-riscv32.*forth.elf" 2>/dev/null || true
```

Write the GDB commands to a temporary script file (e.g. under
`/var/folders/jq/mj5481cs6m75t8q9rgvh6wmc0000gq/T/opencode/`) and pass it
with `-x`. Use `-batch` so GDB runs non-interactively and exits cleanly.

Useful idioms in the script:

- `break halt_code` + `continue` — run to program completion
- `printf "val=0x%08x\n", $s0` — print register values
- `x/4xw $s3` — dump data stack
- `x/1xw &here_buf` — inspect HERE
- `x/Nxw (int*)&_end` — dump dictionary contents from the start of data space
- `info symbol 0xADDR` — resolve an address to a symbol name
- `stepi` in a loop — single-step through a word's execution

Always kill any leftover QEMU process before starting a new session, and use
`pkill` after the session ends to avoid port conflicts on `:1234`.

