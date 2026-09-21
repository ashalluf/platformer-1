#!/usr/bin/env python3
"""Tile PNG captures into one contact sheet.

    tools/contact_sheet.py out.png cols shot1.png shot2.png ...

Pure standard library on purpose: this container has no Pillow and the whole
point of the tool is to be available the moment a capture lands. It reads
8-bit non-interlaced PNGs (which is all Godot's viewport grab writes),
box-averages each one down to a common cell, and re-encodes the grid.

Why it exists: an art director looks at a lineup, not at one frame at a time.
Twenty separate screenshots are twenty separate opinions; one sheet is a
judgement about whether the game holds together.
"""
import sys
import zlib
import struct

FILTER_NONE, FILTER_SUB, FILTER_UP, FILTER_AVG, FILTER_PAETH = range(5)


def _paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    return b if pb <= pc else c


def read_png(path):
    """-> (width, height, rows) where each row is a bytearray of RGB triples."""
    with open(path, "rb") as fh:
        data = fh.read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("%s is not a PNG" % path)
    pos = 8
    idat = bytearray()
    width = height = depth = colour = 0
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos:pos + 4])
        kind = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            width, height, depth, colour, _, _, interlace = struct.unpack(">IIBBBBB", body)
            if depth != 8 or interlace != 0 or colour not in (2, 6):
                raise ValueError("%s: need 8-bit RGB/RGBA, non-interlaced" % path)
        elif kind == b"IDAT":
            idat += body
        elif kind == b"IEND":
            break

    channels = 3 if colour == 2 else 4
    raw = zlib.decompress(bytes(idat))
    stride = width * channels
    rows = []
    prev = bytearray(stride)
    at = 0
    for _ in range(height):
        ft = raw[at]
        line = bytearray(raw[at + 1:at + 1 + stride])
        at += 1 + stride
        if ft == FILTER_SUB:
            for i in range(channels, stride):
                line[i] = (line[i] + line[i - channels]) & 0xFF
        elif ft == FILTER_UP:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xFF
        elif ft == FILTER_AVG:
            for i in range(stride):
                left = line[i - channels] if i >= channels else 0
                line[i] = (line[i] + ((left + prev[i]) >> 1)) & 0xFF
        elif ft == FILTER_PAETH:
            for i in range(stride):
                left = line[i - channels] if i >= channels else 0
                up_left = prev[i - channels] if i >= channels else 0
                line[i] = (line[i] + _paeth(left, prev[i], up_left)) & 0xFF
        elif ft != FILTER_NONE:
            raise ValueError("%s: unknown filter %d" % (path, ft))
        prev = line
        if channels == 4:
            rgb = bytearray(width * 3)
            for x in range(width):
                rgb[x * 3:x * 3 + 3] = line[x * 4:x * 4 + 3]
            rows.append(rgb)
        else:
            rows.append(line)
    return width, height, rows


def resize(width, height, rows, out_w, out_h):
    """Box-average resample. Averaging rather than dropping pixels matters: a
    nearest-neighbour shrink of a rendered frame aliases fine detail into noise
    and makes a clean image look dirty, which is the one thing a review sheet
    must not do."""
    out = []
    for oy in range(out_h):
        y0 = oy * height // out_h
        y1 = max(y0 + 1, (oy + 1) * height // out_h)
        line = bytearray(out_w * 3)
        for ox in range(out_w):
            x0 = ox * width // out_w
            x1 = max(x0 + 1, (ox + 1) * width // out_w)
            r = g = b = n = 0
            for yy in range(y0, y1):
                src = rows[yy]
                for xx in range(x0, x1):
                    i = xx * 3
                    r += src[i]
                    g += src[i + 1]
                    b += src[i + 2]
                    n += 1
            line[ox * 3] = r // n
            line[ox * 3 + 1] = g // n
            line[ox * 3 + 2] = b // n
        out.append(line)
    return out


def write_png(path, width, height, rows):
    raw = bytearray()
    for line in rows:
        raw.append(FILTER_NONE)
        raw += line
    body = zlib.compress(bytes(raw), 6)

    def chunk(kind, payload):
        return (struct.pack(">I", len(payload)) + kind + payload
                + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF))

    with open(path, "wb") as fh:
        fh.write(b"\x89PNG\r\n\x1a\n")
        fh.write(chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)))
        fh.write(chunk(b"IDAT", body))
        fh.write(chunk(b"IEND", b""))


def main(argv):
    if len(argv) < 4:
        print(__doc__)
        return 2
    out_path, cols = argv[1], int(argv[2])
    sources = argv[3:]
    cell_w = 640
    gap = 6
    bg = (18, 18, 20)

    cells = []
    for p in sources:
        w, h, rows = read_png(p)
        cell_h = max(1, round(cell_w * h / w))
        cells.append(resize(w, h, rows, cell_w, cell_h))
    cell_h = max(len(c) for c in cells)

    rows_n = (len(cells) + cols - 1) // cols
    sheet_w = cols * cell_w + (cols + 1) * gap
    sheet_h = rows_n * cell_h + (rows_n + 1) * gap
    sheet = [bytearray(bytes(bg) * sheet_w) for _ in range(sheet_h)]

    for i, cell in enumerate(cells):
        cx = gap + (i % cols) * (cell_w + gap)
        cy = gap + (i // cols) * (cell_h + gap)
        for y, line in enumerate(cell):
            sheet[cy + y][cx * 3:cx * 3 + len(line)] = line

    write_png(out_path, sheet_w, sheet_h, sheet)
    print("contact sheet: %s (%dx%d, %d frames)" % (out_path, sheet_w, sheet_h, len(cells)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
