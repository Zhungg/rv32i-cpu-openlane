/* SPDX-License-Identifier: Apache-2.0 */
/* Linker script for RV32I SoC */

OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 64K
    RAM (rwx) : ORIGIN = 0x20000000, LENGTH = 64K
}

SECTIONS
{
    /* Code in ROM */
    .text : {
        . = ALIGN(4);
        *(.text.init)
        *(.text .text.*)
        *(.rodata .rodata.*)
        . = ALIGN(4);
        _etext = .;
    } > ROM

    /* Initialized data placed in ROM, copied to RAM at boot */
    .data : AT(_etext) {
        . = ALIGN(4);
        _sdata = .;
        *(.data .data.*)
        *(.sdata .sdata.*)
        . = ALIGN(4);
        _edata = .;
    } > RAM

    _sidata = _etext;

    /* Uninitialized data in RAM */
    .bss : {
        . = ALIGN(4);
        _sbss = .;
        *(.bss .bss.*)
        *(.sbss .sbss.*)
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;
    } > RAM

    /* Stack at top of RAM */
    .stack (NOLOAD) : {
        . = ALIGN(16);
        _stack_bottom = .;
        . = . + 0x2000; /* 8KB Stack */
        . = ALIGN(16);
        _stack_top = .;
    } > RAM

    _end = .;
}
