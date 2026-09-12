#!/usr/bin/env python3
from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
APP = ROOT / "swiftui" / "GRU" / "gru."

KEY_RE = re.compile(r'^\s*"((?:\\.|[^"])*)"\s*=\s*"', re.MULTILINE)
CALL_RE = re.compile(
    r'GRUL10n\.(?:text|format)\(\s*"((?:\\.|[^"])*)"',
    re.MULTILINE,
)
CYRILLIC_RE = re.compile(r"[А-Яа-яЁё]")
STRING_RE = re.compile(r'"((?:\\.|[^"])*)"')


def parse_strings(path: pathlib.Path) -> set[str]:
    text = path.read_text(encoding="utf-8")
    return {bytes(k, "utf-8").decode("unicode_escape") if "\\" in k else k for k in KEY_RE.findall(text)}


def main() -> int:
    catalogs = {
        "en": parse_strings(APP / "en.lproj" / "Localizable.strings"),
        "ru": parse_strings(APP / "ru.lproj" / "Localizable.strings"),
    }

    referenced: dict[str, list[str]] = {}
    for path in APP.rglob("*.swift"):
        text = path.read_text(encoding="utf-8")
        for key in CALL_RE.findall(text):
            referenced.setdefault(key, []).append(str(path.relative_to(ROOT)))

    missing: list[str] = []
    for language, keys in catalogs.items():
        for key, locations in sorted(referenced.items()):
            if key not in keys:
                missing.append(
                    f"[{language}] missing {key!r} used by {', '.join(sorted(set(locations))[:3])}"
                )

    # Settings is release-critical: visible Cyrillic string literals must either
    # be localization keys or be explicitly exempt technical/user-input values.
    settings = APP / "Views" / "SettingsView.swift"
    settings_text = settings.read_text(encoding="utf-8")
    exemptions = {
        "Физический iPhone",  # debug-only environment label
    }
    uncatalogued_settings: set[str] = set()
    for literal in STRING_RE.findall(settings_text):
        if CYRILLIC_RE.search(literal) and literal not in exemptions:
            if literal not in catalogs["en"] or literal not in catalogs["ru"]:
                uncatalogued_settings.add(literal)

    if uncatalogued_settings:
        missing.extend(
            f"[settings] uncatalogued visible literal {value!r}"
            for value in sorted(uncatalogued_settings)
        )

    if missing:
        print("Localization audit FAILED:")
        for problem in missing:
            print(f" - {problem}")
        return 1

    print(
        "Localization audit OK: "
        f"{len(referenced)} runtime keys; en={len(catalogs['en'])}; ru={len(catalogs['ru'])}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
