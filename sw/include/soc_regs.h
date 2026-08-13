/* SPDX-License-Identifier: Apache-2.0 */
#ifndef SOC_REGS_H
#define SOC_REGS_H

#include <stdint.h>

#define REG32(addr) (*(volatile uint32_t *)(addr))

/* Memory Map */
#define ROM_BASE        0x00000000
#define RAM_BASE        0x20000000

/* UART Base & Registers */
#define UART_BASE       0x40000000
#define UART_DATA       REG32(UART_BASE + 0x00)
#define UART_STATUS     REG32(UART_BASE + 0x04)
#define UART_CTRL       REG32(UART_BASE + 0x08)
#define UART_DIV        REG32(UART_BASE + 0x0C)

#define UART_STATUS_TX_BUSY   (1 << 0)
#define UART_STATUS_RX_VALID  (1 << 1)

/* Timer Base & Registers */
#define TIMER_BASE      0x40001000
#define TIMER_MTIME_L   REG32(TIMER_BASE + 0x00)
#define TIMER_MTIME_H   REG32(TIMER_BASE + 0x04)
#define TIMER_CMP_L     REG32(TIMER_BASE + 0x08)
#define TIMER_CMP_H     REG32(TIMER_BASE + 0x0C)
#define TIMER_CTRL      REG32(TIMER_BASE + 0x10)

/* DMA Base & Registers */
#define DMA_BASE        0x40002000
#define DMA_SRC         REG32(DMA_BASE + 0x00)
#define DMA_DST         REG32(DMA_BASE + 0x04)
#define DMA_LEN         REG32(DMA_BASE + 0x08)
#define DMA_CTRL        REG32(DMA_BASE + 0x0C)

#endif /* SOC_REGS_H */
