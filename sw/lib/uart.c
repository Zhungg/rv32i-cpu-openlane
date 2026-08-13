/* SPDX-License-Identifier: Apache-2.0 */
#include "uart.h"
#include "soc_regs.h"

void uart_init(uint16_t divider) {
    UART_DIV = divider;
    UART_CTRL = 0x03; // Enable TX and RX
}

void uart_putc(char c) {
    while (UART_STATUS & UART_STATUS_TX_BUSY);
    UART_DATA = (uint32_t)(uint8_t)c;
}

void uart_puts(const char *str) {
    while (*str) {
        if (*str == '\n') {
            uart_putc('\r');
        }
        uart_putc(*str++);
    }
}

void uart_puthex(uint32_t val) {
    const char hex_chars[] = "0123456789ABCDEF";
    uart_puts("0x");
    for (int i = 7; i >= 0; i--) {
        uart_putc(hex_chars[(val >> (i * 4)) & 0xF]);
    }
}

int uart_has_rx(void) {
    return (UART_STATUS & UART_STATUS_RX_VALID) ? 1 : 0;
}

char uart_getc(void) {
    while (!uart_has_rx());
    return (char)(UART_DATA & 0xFF);
}
