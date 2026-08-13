/* SPDX-License-Identifier: Apache-2.0 */
#ifndef TIMER_H
#define TIMER_H

#include <stdint.h>

void     timer_init(void);
uint64_t timer_get_ticks(void);
void     timer_delay_ticks(uint32_t ticks);

#endif /* TIMER_H */
