#!/usr/bin/env python3
import sys

def bin2hex(bin_path, hex_path):
    with open(bin_path, 'rb') as f:
        data = f.read()

    # Pad to multiple of 4 bytes
    while len(data) % 4 != 0:
        data += b'\x00'

    with open(hex_path, 'w') as f:
        for i in range(0, len(data), 4):
            word = data[i:i+4]
            # 32-bit little endian word formatted as 8 hex digits
            val = int.from_bytes(word, byteorder='little')
            f.write(f"{val:08x}\n")

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <input.bin> <output.hex>")
        sys.exit(1)
    bin2hex(sys.argv[1], sys.argv[2])
