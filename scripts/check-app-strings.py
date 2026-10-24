#!/usr/bin/env python3
"""Verify every L("...") key in Kumusta/ is a literal with format placeholders.

Kumusta ships in English only; the English text is the key. Interpolating
(`\\(...)`) inside a key would bypass placeholders and break plural/format rules.

Usage: python3 scripts/check-app-strings.py
Exits non-zero on keys built with interpolation.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "Kumusta/Resources/AppStrings.xcstrings"
LITERAL = r'"((?:[^"\\\n]|\\.)*)"'
CALL = re.compile(r'\bL\(\s*' + LITERAL)
PLURAL = re.compile(r'\bL\(\s*one:\s*' + LITERAL + r'\s*,\s*other:\s*' + LITERAL)


def unescape(text):
    text = re.sub(r'\\u\{([0-9a-fA-F]+)\}', lambda m: chr(int(m.group(1), 16)), text)
    return text.replace('\\"', '"').replace("\\n", "\n").replace("\\t", "\t").replace("\\\\", "\\")


def main():
    catalog = json.loads(CATALOG.read_text())["strings"]
    interpolated, used = [], set()
    for path in sorted((ROOT / "Kumusta").rglob("*.swift")):
        source = path.read_text()
        keys = [m.group(1) for m in CALL.finditer(source)]
        for m in PLURAL.finditer(source):
            keys += [m.group(1), m.group(2)]
        for raw in keys:
            if "\\(" in raw:
                interpolated.append(f"{path.relative_to(ROOT)}: {raw}")
                continue
            used.add(unescape(raw))
    unused = sorted(set(catalog) - used)
    if interpolated:
        print(f"Interpolated keys ({len(interpolated)}):\n  " + "\n  ".join(interpolated))
    print(f"{len(used)} keys used, {len(catalog)} in catalog, {len(unused)} unused")
    sys.exit(1 if interpolated else 0)


if __name__ == "__main__":
    main()
