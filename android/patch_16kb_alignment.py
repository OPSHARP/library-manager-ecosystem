import struct
import sys
import os

NEW_ALIGNMENT = 0x4000

def patch_elf(filepath):
    with open(filepath, 'r+b') as f:
        magic = f.read(4)
        if magic != b'\x7fELF':
            return False

        f.seek(4)
        ei_class = struct.unpack('B', f.read(1))[0]
        is_64bit = ei_class == 2

        if is_64bit:
            f.seek(32)
            phoff = struct.unpack('<Q', f.read(8))[0]
            f.seek(54)
            phentsize = struct.unpack('<H', f.read(2))[0]
            f.seek(56)
            phnum = struct.unpack('<H', f.read(2))[0]
            align_off = 48
            align_fmt = '<Q'
            align_size = 8
        else:
            f.seek(28)
            phoff = struct.unpack('<I', f.read(4))[0]
            f.seek(42)
            phentsize = struct.unpack('<H', f.read(2))[0]
            f.seek(44)
            phnum = struct.unpack('<H', f.read(2))[0]
            align_off = 24
            align_fmt = '<I'
            align_size = 4

        patched = False
        for i in range(phnum):
            ph_addr = phoff + i * phentsize
            f.seek(ph_addr)
            p_type = struct.unpack('<I', f.read(4))[0]
            if p_type in (1, 6):
                f.seek(ph_addr + align_off)
                current = struct.unpack(align_fmt, f.read(align_size))[0]
                if current < NEW_ALIGNMENT:
                    f.seek(ph_addr + align_off)
                    f.write(struct.pack(align_fmt, NEW_ALIGNMENT))
                    patched = True
                    print(f"  Patched segment alignment: {current:#x} -> {NEW_ALIGNMENT:#x}")
        return patched


if __name__ == '__main__':
    count = 0
    for path in sys.argv[1:]:
        if os.path.isfile(path):
            if patch_elf(path):
                count += 1
    print(f"Patched {count} file(s)")
    if count == 0:
        sys.exit(1)
