/* SPDX-License-Identifier: Apache-2.0 */
#include "timer.h"
#include "soc_regs.h"

void timer_init(void) {
    TIMER_CTRL = 0x01; // Enable timer
}

uint64_t timer_get_ticks(void) {
    uint32_t high, low, high2;
    do {
        high = TIMER_MTIME_H;
        low  = TIMER_MTIME_L;
        high2 = TIMER_MTIME_H;
    } while (high != high2);
    return (((uint64_t)high) << 32) | low;
}

void timer_delay_ticks(uint32_t ticks) {
    uint64_t start = timer_get_ticks();
    while ((timer_get_ticks() - start) < (uint64_t)ticks);
}
