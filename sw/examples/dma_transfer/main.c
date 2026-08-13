// SPDX-License-Identifier: Apache-2.0
#include "uart.h"
#include "timer.h"
#include "dma.h"

#define TEST_WORDS 16
#define TEST_BYTES (TEST_WORDS * 4)

static uint32_t src_buffer[TEST_WORDS] __attribute__((aligned(4)));
static uint32_t dst_buffer[TEST_WORDS] __attribute__((aligned(4)));

int main(void) {
    uart_init(434); // 115200 @ 50MHz
    uart_puts("\n[SoC WB] Starting DMA Transfer Benchmark...\n");

    // Initialize source buffer with known pattern
    for (int i = 0; i < TEST_WORDS; i++) {
        src_buffer[i] = 0xA5A50000 + i;
        dst_buffer[i] = 0x00000000;
    }

    uart_puts("[SoC WB] Triggering DMA transfer (64 bytes)...\n");
    dma_memcpy(dst_buffer, src_buffer, TEST_BYTES);

    // Verify
    bool pass = true;
    for (int i = 0; i < TEST_WORDS; i++) {
        if (dst_buffer[i] != src_buffer[i]) {
            pass = false;
            break;
        }
    }

    if (pass) {
        uart_puts("[SoC WB] DMA Transfer Test: PASS!\n");
    } else {
        uart_puts("[SoC WB] DMA Transfer Test: FAILED!\n");
    }

    while (1) {
        // Halt
    }

    return 0;
}
