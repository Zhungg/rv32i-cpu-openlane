# SPDX-License-Identifier: Apache-2.0
# RV32I Software Build Makefile

CROSS_COMPILE ?= riscv32-unknown-elf-
CC      := $(CROSS_COMPILE)gcc
OBJCOPY := $(CROSS_COMPILE)objcopy
OBJDUMP := $(CROSS_COMPILE)objdump

CFLAGS  := -march=rv32i -mabi=ilp32 -O2 -g -Wall -Wextra -ffreestanding -nostdlib -Iinclude
LDFLAGS := -T linker/link.ld -nostdlib -Wl,--gc-sections

SRCS    := startup/crt0.s lib/uart.c lib/timer.c examples/hello_world/main.c
OBJS    := $(SRCS:.c=.o)
OBJS    := $(OBJS:.s=.o)

TARGET  := build/hello_world

.PHONY: all clean hex

all: $(TARGET).elf $(TARGET).bin $(TARGET).hex $(TARGET).dump

$(TARGET).elf: $(OBJS) linker/link.ld
	@mkdir -p build
	$(CC) $(CFLAGS) $(LDFLAGS) $(OBJS) -o $@

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.s
	$(CC) $(CFLAGS) -c $< -o $@

$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

$(TARGET).dump: $(TARGET).elf
	$(OBJDUMP) -D $< > $@

$(TARGET).hex: $(TARGET).bin
	python3 tools/bin2hex.py $< $@

clean:
	rm -rf build startup/*.o lib/*.o examples/hello_world/*.o
