#!/usr/bin/env python3
"""
NEXO controller probe for macOS.

Reports HID gamepad/joystick devices without changing any settings.
Useful for distinguishing controller/connection-mode problems from the
known GZDoom Cocoa backend bug on macOS 26.
"""

from __future__ import annotations

import re
import subprocess
from pathlib import Path

KEYS = (
    "Product",
    "Manufacturer",
    "VendorID",
    "ProductID",
    "Transport",
    "PrimaryUsagePage",
    "PrimaryUsage",
)


def run(cmd: list[str]) -> str:
    try:
        p = subprocess.run(cmd, text=True, capture_output=True, check=False)
        return p.stdout + p.stderr
    except Exception as exc:
        return f"<failed: {exc}>"


def split_ioreg(text: str) -> list[str]:
    blocks: list[str] = []
    current: list[str] = []
    for line in text.splitlines():
        if line.startswith("+-o ") or line.startswith("  +-o "):
            if current:
                blocks.append("\n".join(current))
                current = []
        current.append(line)
    if current:
        blocks.append("\n".join(current))
    return blocks


def extract(block: str, key: str) -> str | None:
    # Handles both string and numeric ioreg values.
    m = re.search(rf'"{re.escape(key)}"\s*=\s*("[^"]*"|[^\n]+)', block)
    if not m:
        return None
    return m.group(1).strip().strip('"')


def main() -> int:
    print("[NEXO] macOS controller probe")
    print()

    raw = run(["ioreg", "-r", "-l", "-w", "0", "-c", "IOHIDDevice"])
    found = 0

    for block in split_ioreg(raw):
        values = {k: extract(block, k) for k in KEYS}
        product = (values.get("Product") or "").lower()
        manufacturer = (values.get("Manufacturer") or "").lower()
        usage = values.get("PrimaryUsage")

        usage_page = values.get("PrimaryUsagePage")
        standard_game_controller = (
            usage_page in {"1", "0x1"}
            and usage in {"4", "5", "0x4", "0x5"}
        )

        looks_like_controller = (
            standard_game_controller
            or "controller" in product
            or "gamepad" in product
            or "gamesir" in product
            or "gamesir" in manufacturer
        )

        if not looks_like_controller:
            continue

        found += 1
        print(f"DEVICE {found}")
        for key in KEYS:
            if values.get(key) is not None:
                print(f"  {key}: {values[key]}")
        print()

    if found == 0:
        print("No obvious IOHID game controller found.")
        print()

    print("[NEXO] hidutil list excerpt:")
    hid = run(["hidutil", "list"])
    lines = [
        line for line in hid.splitlines()
        if any(token in line.lower() for token in (
            "gamesir", "controller", "gamepad", "wireless", "joystick"
        ))
    ]
    if lines:
        print("\n".join(lines[:80]))
    else:
        print("(no matching lines)")

    print()
    print("[NEXO] Important:")
    print("GZDoom 4.14.2 Cocoa input is known broken on macOS 26.")
    print("A correct HID device here does NOT imply Cocoa GZDoom will map it correctly.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
