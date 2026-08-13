// SPDX-License-Identifier: Apache-2.0
#ifndef RV32I_DMA_H
#define RV32I_DMA_H

#include <stdint.h>
#include <stdbool.h>
#include "soc_regs.h"

// DMA Control & Status bit definitions
#define DMA_CTRL_START    (1 << 0)
#define DMA_CTRL_BUSY     (1 << 1)
#define DMA_CTRL_DONE     (1 << 2)
#define DMA_CTRL_IRQ_EN   (1 << 3)
#define DMA_CTRL_ERR      (1 << 4)

void dma_start(uint32_t src_addr, uint32_t dst_addr, uint32_t byte_len);
bool dma_is_busy(void);
bool dma_is_done(void);
void dma_wait_done(void);
void dma_memcpy(void *dst, const void *src, uint32_t byte_len);

#endif // RV32I_DMA_H
