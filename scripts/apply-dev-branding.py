#!/usr/bin/env python3
"""Rewrite the user-visible product name inside a development build.

The upstream localization tables hard-code the official product name in
``InfoPlist.strings`` and ``Localizable.strings``.  On a localized system those
values win over ``CFBundleDisplayName``: a build that only changes the
Info.plist still shows "无线麦 SayAll" in Finder, the Dock and the About panel.
This script edits the *built bundle* only, so the repository keeps tracking the
upstream resources while the development edition presents its own name.

Usage: apply-dev-branding.py <app-bundle> <display-name>
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# Keys whose value is the product name itself rather than prose that happens to
# mention it.  Only these are rewritten in non-Chinese localizations, because
# "SayAll" there is also the name of the virtual audio device.
NAME_KEYS = ("app.name", "menu.about")

ABOUT_PREFIX = {
    "zh-Hans": "关于",
    "en": "About ",
}


def rebrand_localizable(path: Path, name: str, language: str) -> int:
    text = path.read_text(encoding="utf-8")
    original = text

    if language == "zh-Hans":
        # The full Chinese product name is unambiguous: it is never the audio
        # device, which is called plain "SayAll".
        text = text.replace("无线麦 SayAll", name)

    prefix = ABOUT_PREFIX.get(language, "About ")
    for key in NAME_KEYS:
        value = f"{prefix}{name}" if key == "menu.about" else name
        text, count = re.subn(
            rf'^("{re.escape(key)}"\s*=\s*")[^"]*(";)',
            rf"\g<1>{value}\g<2>",
            text,
            flags=re.MULTILINE,
        )
        if count == 0:
            print(f"warning: {path}: key {key} not found", file=sys.stderr)

    if text != original:
        path.write_text(text, encoding="utf-8")
    return len(text)


def rebrand_info_plist_strings(path: Path, name: str, language: str) -> None:
    text = path.read_text(encoding="utf-8")
    if language == "zh-Hans":
        text = text.replace("无线麦 SayAll", name)
    else:
        text = re.sub(r"(?<![A-Za-z0-9_])SayAll(?![A-Za-z0-9_])", name, text)
    for key in ("CFBundleDisplayName", "CFBundleName"):
        text, count = re.subn(
            rf'("{key}"\s*=\s*")[^"]*(";)',
            rf"\g<1>{name}\g<2>",
            text,
        )
        if count == 0:
            print(f"warning: {path}: key {key} not found", file=sys.stderr)
    path.write_text(text, encoding="utf-8")


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    app = Path(sys.argv[1])
    name = sys.argv[2]
    resources = app / "Contents" / "Resources"
    if not resources.is_dir():
        print(f"not an app bundle: {app}", file=sys.stderr)
        return 1

    touched = 0
    for lproj in sorted(resources.glob("*.lproj")):
        language = lproj.stem
        info = lproj / "InfoPlist.strings"
        if info.is_file():
            rebrand_info_plist_strings(info, name, language)
            touched += 1
        localizable = lproj / "Localizable.strings"
        if localizable.is_file():
            rebrand_localizable(localizable, name, language)
            touched += 1

    if touched == 0:
        print(f"no localization tables found under {resources}", file=sys.stderr)
        return 1
    print(f"BRANDED {app} as {name!r} across {touched} localization files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
