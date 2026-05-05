#!/usr/bin/env python3
"""Local sprite asset pipeline for Lulo Clippy.

No network calls, no external Python packages. Supports the current RGBA PNG sheet
contract and writes deterministic, zlib-optimized PNGs.
"""
from __future__ import annotations

import argparse
import json
import math
import os
import struct
import subprocess
import sys
import zlib
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

PNG_SIG = b"\x89PNG\r\n\x1a\n"
ROOT = Path(__file__).resolve().parents[1]
DEFAULT_META = ROOT / "Resources" / "Sprites" / "lulo-sprite-sheet.json"
DEFAULT_SHEET = ROOT / "Resources" / "Sprites" / "lulo-sprite-sheet.png"
DEFAULT_FRAMES_DIR = ROOT / "Resources" / "Sprites" / "Frames"
DEFAULT_ICON_PNG = ROOT / "Resources" / "AppIcon" / "LuloAppIcon.png"
DEFAULT_ICONSET = ROOT / "Resources" / "AppIcon" / "LuloAppIcon.iconset"
DEFAULT_ICNS = ROOT / "Resources" / "AppIcon" / "LuloAppIcon.icns"


@dataclass
class ImageRGBA:
    width: int
    height: int
    pixels: bytearray  # RGBA bytes, row-major

    def row(self, y: int) -> memoryview:
        start = y * self.width * 4
        return memoryview(self.pixels)[start:start + self.width * 4]


def read_chunks(path: Path) -> Iterable[tuple[bytes, bytes]]:
    data = path.read_bytes()
    if not data.startswith(PNG_SIG):
        raise ValueError(f"{path} is not a PNG")
    pos = len(PNG_SIG)
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        ctype = data[pos + 4:pos + 8]
        chunk = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        yield ctype, chunk
        if ctype == b"IEND":
            break


def paeth(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa = abs(p - a)
    pb = abs(p - b)
    pc = abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def load_png_rgba(path: Path) -> ImageRGBA:
    width = height = bit_depth = color_type = None
    idat = bytearray()
    for ctype, chunk in read_chunks(path):
        if ctype == b"IHDR":
            width, height, bit_depth, color_type, _comp, _filter, interlace = struct.unpack(">IIBBBBB", chunk)
            if bit_depth != 8 or color_type != 6 or interlace != 0:
                raise ValueError(f"only non-interlaced 8-bit RGBA PNGs are supported; got bitDepth={bit_depth}, colorType={color_type}, interlace={interlace}")
        elif ctype == b"IDAT":
            idat.extend(chunk)
    if width is None or height is None:
        raise ValueError("missing PNG IHDR")

    raw = zlib.decompress(bytes(idat))
    stride = width * 4
    out = bytearray(height * stride)
    src = 0
    prev = bytearray(stride)
    for y in range(height):
        filter_type = raw[src]
        src += 1
        scan = bytearray(raw[src:src + stride])
        src += stride
        recon = bytearray(stride)
        for i, val in enumerate(scan):
            left = recon[i - 4] if i >= 4 else 0
            up = prev[i]
            up_left = prev[i - 4] if i >= 4 else 0
            if filter_type == 0:
                recon[i] = val
            elif filter_type == 1:
                recon[i] = (val + left) & 0xFF
            elif filter_type == 2:
                recon[i] = (val + up) & 0xFF
            elif filter_type == 3:
                recon[i] = (val + ((left + up) >> 1)) & 0xFF
            elif filter_type == 4:
                recon[i] = (val + paeth(left, up, up_left)) & 0xFF
            else:
                raise ValueError(f"unsupported PNG filter: {filter_type}")
        out[y * stride:(y + 1) * stride] = recon
        prev = recon
    return ImageRGBA(width, height, out)


def png_chunk(ctype: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + ctype + data + struct.pack(">I", zlib.crc32(ctype + data) & 0xFFFFFFFF)


def write_png_rgba(path: Path, image: ImageRGBA, level: int = 9) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    stride = image.width * 4
    # Filter 0 is intentionally simple and deterministic. zlib level 9 still
    # produces compact assets and avoids external optimizer dependencies.
    raw = bytearray()
    for y in range(image.height):
        raw.append(0)
        raw.extend(image.pixels[y * stride:(y + 1) * stride])
    ihdr = struct.pack(">IIBBBBB", image.width, image.height, 8, 6, 0, 0, 0)
    compressed = zlib.compress(bytes(raw), level)
    data = PNG_SIG + png_chunk(b"IHDR", ihdr) + png_chunk(b"IDAT", compressed) + png_chunk(b"IEND", b"")
    path.write_bytes(data)


def crop(image: ImageRGBA, x: int, y: int, w: int, h: int) -> ImageRGBA:
    out = bytearray(w * h * 4)
    for row in range(h):
        src0 = ((y + row) * image.width + x) * 4
        src1 = src0 + w * 4
        dst0 = row * w * 4
        out[dst0:dst0 + w * 4] = image.pixels[src0:src1]
    return ImageRGBA(w, h, out)


def paste(dest: ImageRGBA, src: ImageRGBA, x: int, y: int) -> None:
    for row in range(src.height):
        dst0 = ((y + row) * dest.width + x) * 4
        src0 = row * src.width * 4
        dest.pixels[dst0:dst0 + src.width * 4] = src.pixels[src0:src0 + src.width * 4]


def nearest_resize(src: ImageRGBA, width: int, height: int) -> ImageRGBA:
    out = bytearray(width * height * 4)
    for y in range(height):
        sy = min(src.height - 1, int(y * src.height / height))
        for x in range(width):
            sx = min(src.width - 1, int(x * src.width / width))
            out[(y * width + x) * 4:(y * width + x + 1) * 4] = src.pixels[(sy * src.width + sx) * 4:(sy * src.width + sx + 1) * 4]
    return ImageRGBA(width, height, out)


def load_meta(path: Path) -> dict:
    return json.loads(path.read_text())


def iter_pixels(image: ImageRGBA):
    p = image.pixels
    for i in range(0, len(p), 4):
        yield p[i], p[i + 1], p[i + 2], p[i + 3]


def inspect(sheet_path: Path, meta_path: Path) -> dict:
    image = load_png_rgba(sheet_path)
    meta = load_meta(meta_path)
    cols = int(meta["columns"])
    rows = int(meta["rows"])
    if image.width % cols or image.height % rows:
        raise SystemExit(f"sheet size {image.width}x{image.height} is not divisible by {cols}x{rows}")
    cell_w = image.width // cols
    cell_h = image.height // rows
    alpha = [0] * 256
    nontransparent = 0
    transparent = 0
    edge_opaque = 0
    frame_reports = []
    for _, _, _, a in iter_pixels(image):
        alpha[a] += 1
        if a == 0:
            transparent += 1
        else:
            nontransparent += 1
    for idx in range(cols * rows):
        x = (idx % cols) * cell_w
        y = (idx // cols) * cell_h
        frame = crop(image, x, y, cell_w, cell_h)
        bbox = None
        opaque = 0
        semi = 0
        edge = 0
        for fy in range(cell_h):
            for fx in range(cell_w):
                a = frame.pixels[(fy * cell_w + fx) * 4 + 3]
                if a:
                    opaque += 1
                    if a < 255:
                        semi += 1
                    if fx in (0, cell_w - 1) or fy in (0, cell_h - 1):
                        edge += 1
                    if bbox is None:
                        bbox = [fx, fy, fx, fy]
                    else:
                        bbox[0] = min(bbox[0], fx)
                        bbox[1] = min(bbox[1], fy)
                        bbox[2] = max(bbox[2], fx)
                        bbox[3] = max(bbox[3], fy)
        edge_opaque += edge
        coverage = opaque / (cell_w * cell_h)
        frame_reports.append({
            "frame": idx,
            "coverage": round(coverage, 4),
            "semiTransparentPixels": semi,
            "opaquePixelsOnEdge": edge,
            "contentBBox": bbox,
        })
    return {
        "sheet": str(sheet_path.relative_to(ROOT)),
        "size": [image.width, image.height],
        "grid": [cols, rows],
        "frameSize": [cell_w, cell_h],
        "hasAlpha": nontransparent > 0 and transparent > 0,
        "transparentPixels": transparent,
        "nonTransparentPixels": nontransparent,
        "semiTransparentPixels": sum(alpha[1:255]),
        "opaquePixelsOnSheetEdge": edge_opaque,
        "alphaHistogramSummary": {
            "0": alpha[0],
            "1-254": sum(alpha[1:255]),
            "255": alpha[255],
        },
        "frames": frame_reports,
    }


def slice_frames(sheet_path: Path, meta_path: Path, frames_dir: Path) -> None:
    image = load_png_rgba(sheet_path)
    meta = load_meta(meta_path)
    cols = int(meta["columns"])
    rows = int(meta["rows"])
    cell_w = image.width // cols
    cell_h = image.height // rows
    frames_dir.mkdir(parents=True, exist_ok=True)
    for idx in range(cols * rows):
        frame = crop(image, (idx % cols) * cell_w, (idx // cols) * cell_h, cell_w, cell_h)
        write_png_rgba(frames_dir / f"lulo-{idx:02d}.png", frame)
    print(f"wrote {cols * rows} frames to {frames_dir.relative_to(ROOT)}")


def make_icon(sheet_path: Path, meta_path: Path, frame_index: int, icon_png: Path, iconset_dir: Path, icns_path: Path) -> None:
    image = load_png_rgba(sheet_path)
    meta = load_meta(meta_path)
    cols = int(meta["columns"])
    rows = int(meta["rows"])
    cell_w = image.width // cols
    cell_h = image.height // rows
    frame_index = max(0, min(frame_index, cols * rows - 1))
    frame = crop(image, (frame_index % cols) * cell_w, (frame_index // cols) * cell_h, cell_w, cell_h)
    icon = nearest_resize(frame, 1024, 1024)
    icon_png.parent.mkdir(parents=True, exist_ok=True)
    write_png_rgba(icon_png, icon)

    iconset_dir.mkdir(parents=True, exist_ok=True)
    sizes = [(16, ""), (16, "@2x"), (32, ""), (32, "@2x"), (128, ""), (128, "@2x"), (256, ""), (256, "@2x"), (512, ""), (512, "@2x")]
    for points, scale in sizes:
        pixels = points * (2 if scale == "@2x" else 1)
        name = f"icon_{points}x{points}{scale}.png"
        write_png_rgba(iconset_dir / name, nearest_resize(icon, pixels, pixels))

    iconutil = subprocess.run(["/usr/bin/which", "iconutil"], capture_output=True, text=True)
    if iconutil.returncode == 0:
        subprocess.run(["iconutil", "-c", "icns", str(iconset_dir), "-o", str(icns_path)], check=True)
        print(f"wrote {icon_png.relative_to(ROOT)} and {icns_path.relative_to(ROOT)} from frame {frame_index}")
    else:
        print(f"wrote {icon_png.relative_to(ROOT)} and iconset from frame {frame_index}; iconutil not found, skipped .icns")


def chroma_key(input_path: Path, output_path: Path, key: str, tolerance: int, feather: int) -> None:
    image = load_png_rgba(input_path)
    key = key.lstrip("#")
    if len(key) != 6:
        raise SystemExit("--key must be RRGGBB or #RRGGBB")
    kr, kg, kb = int(key[0:2], 16), int(key[2:4], 16), int(key[4:6], 16)
    tol = max(0, tolerance)
    feather = max(0, feather)
    maxdist = math.sqrt(3 * 255 * 255)
    for i in range(0, len(image.pixels), 4):
        r, g, b = image.pixels[i], image.pixels[i + 1], image.pixels[i + 2]
        dist = math.sqrt((r - kr) ** 2 + (g - kg) ** 2 + (b - kb) ** 2)
        if dist <= tol:
            image.pixels[i + 3] = 0
        elif feather and dist <= tol + feather:
            image.pixels[i + 3] = int(255 * ((dist - tol) / feather))
    write_png_rgba(output_path, image)
    print(f"wrote chroma-keyed PNG to {output_path.relative_to(ROOT)}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Inspect, slice, chroma-key, and package Lulo sprite assets locally.")
    parser.add_argument("--sheet", type=Path, default=DEFAULT_SHEET)
    parser.add_argument("--meta", type=Path, default=DEFAULT_META)
    sub = parser.add_subparsers(dest="cmd", required=True)

    sub.add_parser("inspect")

    p_slice = sub.add_parser("slice")
    p_slice.add_argument("--frames-dir", type=Path, default=DEFAULT_FRAMES_DIR)

    p_icon = sub.add_parser("icon")
    p_icon.add_argument("--frame", type=int, default=4, help="frame index to use for the icon; frame 4 is a friendly wave")
    p_icon.add_argument("--png", type=Path, default=DEFAULT_ICON_PNG)
    p_icon.add_argument("--iconset", type=Path, default=DEFAULT_ICONSET)
    p_icon.add_argument("--icns", type=Path, default=DEFAULT_ICNS)

    p_key = sub.add_parser("chroma-key")
    p_key.add_argument("input", type=Path)
    p_key.add_argument("output", type=Path)
    p_key.add_argument("--key", default="00ff00")
    p_key.add_argument("--tolerance", type=int, default=42)
    p_key.add_argument("--feather", type=int, default=24)

    p_all = sub.add_parser("all")
    p_all.add_argument("--frames-dir", type=Path, default=DEFAULT_FRAMES_DIR)
    p_all.add_argument("--icon-frame", type=int, default=4)

    args = parser.parse_args()
    if args.cmd == "inspect":
        print(json.dumps(inspect(args.sheet, args.meta), indent=2))
    elif args.cmd == "slice":
        slice_frames(args.sheet, args.meta, args.frames_dir)
    elif args.cmd == "icon":
        make_icon(args.sheet, args.meta, args.frame, args.png, args.iconset, args.icns)
    elif args.cmd == "chroma-key":
        chroma_key(args.input, args.output, args.key, args.tolerance, args.feather)
    elif args.cmd == "all":
        print(json.dumps(inspect(args.sheet, args.meta), indent=2))
        slice_frames(args.sheet, args.meta, args.frames_dir)
        make_icon(args.sheet, args.meta, args.icon_frame, DEFAULT_ICON_PNG, DEFAULT_ICONSET, DEFAULT_ICNS)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
