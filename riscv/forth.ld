/* forth.ld - Linker script for swish-forth bare-metal RISC-V
 *
 * Targets the QEMU "virt" machine:
 *   - RAM starts at 0x80000000
 *   - _start is the entry point, placed at the base of RAM
 *
 * For a different platform (e.g. Raspberry Pi Pico 2), replace this file
 * with a platform-specific linker script. The Forth kernel source is
 * platform-independent.
 */

OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 128M
}

SECTIONS
{
    . = 0x80000000;

    .text   : { *(.text*)   } > RAM
    .rodata : { *(.rodata*) } > RAM

    /* .bss is zero-initialised; NOLOAD tells the linker not to include
     * it in the binary image — the kernel clears it at startup. */
    .bss (NOLOAD) : { *(.bss*) } > RAM

    /* _end marks the top of statically allocated memory.
     * The dictionary heap grows upward from here. */
    _end = .;
}
