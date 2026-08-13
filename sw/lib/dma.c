// SPDX-License-Identifier: Apache-2.0
#include "dma.h"

void dma_start(uint32_t src_addr, uint32_t dst_addr, uint32_t byte_len) {
    DMA_SRC  = src_addr;
    DMA_DST  = dst_addr;
    DMA_LEN  = byte_len;
    DMA_CTRL = DMA_CTRL_START;
}

bool dma_is_busy(void) {
    return (DMA_CTRL & DMA_CTRL_BUSY) != 0;
}

bool dma_is_done(void) {
    return (DMA_CTRL & DMA_CTRL_DONE) != 0;
}

void dma_wait_done(void) {
    while (dma_is_busy()) {
        // Spin wait
    }
}

void dma_memcpy(void *dst, const void *src, uint32_t byte_len) {
    dma_start((uint32_t)src, (uint32_t)dst, byte_len);
    dma_wait_done();
}
