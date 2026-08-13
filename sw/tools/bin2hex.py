#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# Convert binary firmware to 32-bit hex words for Verilog $readmemh

import sys

def bin_to_hex(bin_path, hex_path, pad_to_words=1024):
    with open(bin_path, 'rb') as f:
        data = f.read()

    words = []
    for i in range(0, len(data), 4):
        chunk = data[i:i+4]
        if len(chunk) < 4:
            chunk = chunk.ljust(4, b'\x00')
        val = int.from_bytes(chunk, byteorder='little')
        words.append(f"{val:08x}")

    while len(words) < pad_to_words:
        words.append("00000013") # NOP

    with open(hex_path, 'w') as f:
        for w in words:
            f.write(f"{w}\n")

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: bin2hex.py <input.bin> <output.hex> [pad_words]")
        sys.exit(1)
    pad = int(sys.argv[3]) if len(sys.argv) > 3 else 1024
    bin_to_hex(sys.argv[1], sys.argv[2], pad)
