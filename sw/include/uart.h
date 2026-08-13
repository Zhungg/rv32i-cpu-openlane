/* SPDX-License-Identifier: Apache-2.0 */
#ifndef UART_H
#define UART_H

#include <stdint.h>

void uart_init(uint16_t divider);
void uart_putc(char c);
void uart_puts(const char *str);
void uart_puthex(uint32_t val);
char uart_getc(void);
int  uart_has_rx(void);

#endif /* UART_H */
