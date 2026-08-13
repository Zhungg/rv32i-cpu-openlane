/* SPDX-License-Identifier: Apache-2.0 */
/* Startup code for RV32I SoC */

.section .text.init
.global _start
.type _start, @function

_start:
    /* Disable interrupts initially */
    csrw mie, zero

    /* Initialize stack pointer */
    la sp, _stack_top

    /* Initialize global pointer */
    .option push
    .option norelax
    la gp, __global_pointer$
    .option pop

    /* Copy .data from ROM (_sidata) to RAM (_sdata) */
    la a0, _sdata
    la a1, _edata
    la a2, _sidata
copy_data_loop:
    bge a0, a1, copy_data_done
    lw t0, 0(a2)
    sw t0, 0(a0)
    addi a0, a0, 4
    addi a2, a2, 4
    j copy_data_loop
copy_data_done:

    /* Clear .bss in RAM */
    la a0, _sbss
    la a1, _ebss
clear_bss_loop:
    bge a0, a1, clear_bss_done
    sw zero, 0(a0)
    addi a0, a0, 4
    j clear_bss_loop
clear_bss_done:

    /* Call C main */
    call main

    /* Trap if main exits */
exit_loop:
    wfi
    j exit_loop

.size _start, . - _start
