/* SPDX-License-Identifier: Apache-2.0 */
#include "soc_regs.h"
#include "uart.h"
#include "timer.h"

int main(void) {
    uart_init(16); // Fast simulation divider
    timer_init();

    uart_puts("\n========================================\n");
    uart_puts("  RV32I RISC-V SoC (Sky130A OpenLane 2) \n");
    uart_puts("  Hello, World from Baremetal C Program! \n");
    uart_puts("========================================\n");

    uint64_t ticks = timer_get_ticks();
    uart_puts("Timer Initial Ticks: ");
    uart_puthex((uint32_t)ticks);
    uart_puts("\n");

    uart_puts("Performing computation test...\n");
    volatile uint32_t sum = 0;
    for (uint32_t i = 1; i <= 100; i++) {
        sum += i;
    }
    uart_puts("Sum of 1..100 = ");
    uart_puthex(sum);
    uart_puts(" (Expected: 0x000013BA)\n");

    ticks = timer_get_ticks();
    uart_puts("Timer Post-Computation Ticks: ");
    uart_puthex((uint32_t)ticks);
    uart_puts("\n");

    uart_puts("SoC Baremetal C Test: SUCCESS!\n");

    return 0;
}
