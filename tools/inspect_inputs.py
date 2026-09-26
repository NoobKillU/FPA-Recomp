from __future__ import annotations

import argparse
import hashlib
import struct
from pathlib import Path

PNG = b"\x89PNG\r\n\x1a\n"
OPTIONAL_FILE_FORMAT = 0x000003FF
OPTIONAL_IMPORTS = 0x000103FF
OPTIONAL_STATIC_LIBRARIES = 0x000200FF
OPTIONAL_ENTRY = 0x00010100
OPTIONAL_BASE = 0x00010201


def be16(data: bytes, offset: int) -> int:
    return struct.unpack_from(">H", data, offset)[0]


def be32(data: bytes, offset: int) -> int:
    return struct.unpack_from(">I", data, offset)[0]


def inspect_inner_pe(data: bytes, image_header_size: int, file_format_offset: int, security_offset: int) -> None:
    encryption, compression = be16(data, file_format_offset + 4), be16(data, file_format_offset + 6)
    if encryption != 0 or compression != 1:
        print("  Inner PE parse skipped; only an unencrypted XEX with basic compression is handled.")
        return
    info_size = be32(data, file_format_offset)
    if info_size < 16 or file_format_offset + info_size > len(data):
        print("  Inner PE parse skipped; malformed basic-compression descriptor.")
        return
    image_size = be32(data, security_offset + 4)
    image = bytearray()
    source = image_header_size
    for descriptor in range(file_format_offset + 8, file_format_offset + info_size, 8):
        raw_size, zero_size = struct.unpack_from(">II", data, descriptor)
        if raw_size == 0 and zero_size == 0:
            continue
        if source + raw_size > len(data) or len(image) + raw_size + zero_size > 128 * 1024 * 1024:
            print("  Inner PE parse skipped; block bounds exceed the supplied file or safety limit.")
            return
        image.extend(data[source:source + raw_size])
        source += raw_size
        image.extend(bytes(zero_size))
    if image[:2] != b"MZ" or len(image) < 0x40:
        print("  Basic-compressed image does not begin with a readable PE header.")
        return
    pe_offset = struct.unpack_from("<I", image, 0x3C)[0]
    if pe_offset + 24 > len(image) or image[pe_offset:pe_offset + 4] != b"PE\0\0":
        print("  Inner PE signature is missing or outside the reconstructed image.")
        return
    machine, section_count, _, _, _, optional_size, characteristics = struct.unpack_from("<HHIIIHH", image, pe_offset + 4)
    optional = pe_offset + 24
    if optional_size < 70 or optional + optional_size + section_count * 40 > len(image):
        print("  Inner PE section table is truncated.")
        return
    magic = struct.unpack_from("<H", image, optional)[0]
    entry_rva = struct.unpack_from("<I", image, optional + 16)[0]
    size_of_image = struct.unpack_from("<I", image, optional + 56)[0]
    subsystem = struct.unpack_from("<H", image, optional + 68)[0]
    machine_name = {0x01F2: "PowerPC big-endian", 0x014C: "x86", 0x8664: "x86-64"}.get(machine, "unknown")
    subsystem_name = {14: "Xbox", 2: "Windows GUI", 3: "Windows console"}.get(subsystem, "other/unknown")
    print(f"  Inner PE: machine 0x{machine:04X} ({machine_name}); optional magic 0x{magic:04X}; subsystem {subsystem} ({subsystem_name})")
    print(f"  PE sections {section_count}; entry RVA 0x{entry_rva:X}; PE SizeOfImage 0x{size_of_image:X}; COFF characteristics 0x{characteristics:04X}")
    print("  Reconstructed PE section map (in memory only):")
    for index in range(section_count):
        offset = optional + optional_size + index * 40
        name = bytes(image[offset:offset + 8]).split(b"\0", 1)[0].decode("ascii", errors="replace")
        virtual_size, rva, raw_size, raw_offset = struct.unpack_from("<IIII", image, offset + 8)
        flags = struct.unpack_from("<I", image, offset + 36)[0]
        print(f"    {name}: RVA 0x{rva:X}, virtual 0x{virtual_size:X}, raw 0x{raw_size:X} at 0x{raw_offset:X}, flags 0x{flags:08X}")


def inspect_xex(path: Path) -> None:
    data = path.read_bytes()
    print(f"XEX: {path.name} ({len(data):,} bytes), SHA-256 {hashlib.sha256(data).hexdigest().upper()}")
    if data[:4] != b"XEX2":
        print("  Not an XEX2 image; XEX2 metadata parsing skipped.")
        return
    header_size, security_offset, optional_count = be32(data, 8), be32(data, 16), be32(data, 20)
    print(f"  Header size 0x{header_size:X}; optional headers {optional_count}")
    optional: dict[int, int] = {}
    for index in range(optional_count):
        key, value = struct.unpack_from(">II", data, 24 + index * 8)
        optional[key] = value
    for key, label in ((OPTIONAL_ENTRY, "entry point"), (OPTIONAL_BASE, "image base")):
        if key in optional:
            print(f"  {label}: 0x{optional[key]:08X}")

    fmt_offset = optional.get(OPTIONAL_FILE_FORMAT)
    if fmt_offset is not None and fmt_offset + 8 <= len(data):
        encryption, compression = be16(data, fmt_offset + 4), be16(data, fmt_offset + 6)
        enc_name = {0: "none", 1: "normal"}.get(encryption, "unknown")
        comp_name = {0: "none", 1: "basic", 2: "normal", 3: "delta"}.get(compression, "unknown")
        print(f"  File format metadata: encryption={enc_name} ({encryption}), compression={comp_name} ({compression})")
        inspect_inner_pe(data, header_size, fmt_offset, security_offset)

    import_offset = optional.get(OPTIONAL_IMPORTS)
    if import_offset is not None and import_offset + 12 <= len(data):
        table_size, name_bytes, library_count = struct.unpack_from(">III", data, import_offset)
        names_start = import_offset + 12
        names = data[names_start:names_start + name_bytes].split(b"\0")
        cursor = names_start + name_bytes
        table_end = import_offset + table_size
        print(f"  Import table: offset 0x{import_offset:X}, size 0x{table_size:X}, library-name bytes {name_bytes}, libraries {library_count}")
        for library_index in range(library_count):
            if cursor + 40 > table_end:
                print("  Import record header is truncated.")
                break
            record_size = be32(data, cursor)
            library_id, version, minimum = struct.unpack_from(">III", data, cursor + 24)
            name_index, import_words = struct.unpack_from(">HH", data, cursor + 36)
            expected_size = 40 + import_words * 4
            name = names[name_index].decode("ascii", errors="replace") if name_index < len(names) else f"<bad name index {name_index}>"
            print(f"  [{library_index}] {name}: {import_words} import-table words; record 0x{record_size:X} (expected 0x{expected_size:X}); id 0x{library_id:08X}; version 0x{version:08X}; minimum 0x{minimum:08X}")
            if record_size != expected_size or record_size < 40 or cursor + record_size > table_end:
                print("  Record length is inconsistent; stopped before reading further.")
                break
            cursor += record_size
        else:
            print(f"  Parsed through 0x{cursor:X}; declared table ends at 0x{table_end:X}.")

    static_offset = optional.get(OPTIONAL_STATIC_LIBRARIES)
    if static_offset is not None and static_offset + 4 <= len(data):
        block_size = be32(data, static_offset)
        count = (block_size - 4) // 16 if block_size >= 4 else 0
        print(f"  Statically linked libraries ({count}):")
        for index in range(count):
            offset = static_offset + 4 + index * 16
            if offset + 16 > min(len(data), static_offset + block_size):
                print("    truncated library list")
                break
            name = data[offset:offset + 8].split(b"\0", 1)[0].decode("ascii", errors="replace")
            major, minor, build, qfe = be16(data, offset + 8), be16(data, offset + 10), be16(data, offset + 12), data[offset + 15]
            print(f"    {name} {major}.{minor}.{build}.{qfe}")


def inspect_kcap(path: Path) -> None:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        header = stream.read(32)
        stream.seek(0)
        while block := stream.read(8 * 1024 * 1024):
            digest.update(block)
    size = path.stat().st_size
    print(f"KCAP: {path.name} ({size:,} bytes), SHA-256 {digest.hexdigest().upper()}")
    print(f"  First 32 bytes: {header.hex(' ').upper()}")
    if len(header) < 12 or header[:4] != b"KCAP":
        print("  KCAP signature not present; archive parsing skipped.")
        return
    field_a, field_b = be32(header, 4), be32(header, 8)
    print(f"  KCAP signature; big-endian header words at +0x04/+0x08: {field_a} / {field_b}")
    offsets: list[int] = []
    overlap = b""
    with path.open("rb") as stream:
        base = 0
        while block := stream.read(8 * 1024 * 1024):
            sample = overlap + block
            sample_base = base - len(overlap)
            pos = 0
            while True:
                found = sample.find(PNG, pos)
                if found < 0:
                    break
                offset = sample_base + found
                offsets.append(offset)
                pos = found + 1
            overlap = sample[-(len(PNG) - 1):]
            base += len(block)
    valid_pngs = 0
    first_png_end = None
    first_dimensions = None
    with path.open("rb") as stream:
        for offset in offsets:
            cursor = offset + len(PNG)
            dimensions = None
            for _ in range(10000):
                stream.seek(cursor)
                chunk_header = stream.read(8)
                if len(chunk_header) != 8:
                    break
                chunk_size = be32(chunk_header, 0)
                chunk_type = chunk_header[4:8]
                if cursor + 12 + chunk_size > size:
                    break
                if chunk_type == b"IHDR" and chunk_size == 13:
                    dimensions = struct.unpack(">II", stream.read(8))
                cursor += 12 + chunk_size
                if chunk_type == b"IEND":
                    valid_pngs += 1
                    if first_png_end is None:
                        first_png_end = cursor
                        first_dimensions = dimensions
                    break
    print(f"  PNG signatures: {len(offsets)}; structurally complete through IEND: {valid_pngs}")
    if offsets:
        print("  First PNG offsets: " + ", ".join(f"0x{x:X}" for x in offsets[:12]))
    if first_png_end is not None:
        print(f"  First PNG: dimensions {first_dimensions[0]}x{first_dimensions[1]}, ends at 0x{first_png_end:X}")
        if len(offsets) > 1:
            print(f"  Gap from first PNG end to second PNG signature: 0x{offsets[1] - first_png_end:X} bytes")
    print("  PNG regions and signature offsets do not establish the archive's complete resource count or file boundaries.")


def main() -> None:
    parser = argparse.ArgumentParser(description="Read-only metadata inventory for a user-supplied Xbox 360 title folder.")
    parser.add_argument("game_dir", type=Path, help="Game folder or a single XEX file")
    root = parser.parse_args().game_dir
    xex = root if root.is_file() else root / "default.xex"
    pak = root / "Media" / "Data360" / "Data360.pak" if root.is_dir() else None
    if xex.is_file():
        inspect_xex(xex)
    else:
        print("default.xex not found")
    if pak is not None and pak.is_file():
        inspect_kcap(pak)
    else:
        print("Media/Data360/Data360.pak not found")


if __name__ == "__main__":
    main()
