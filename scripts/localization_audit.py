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


def unescape_strings_key(value: str) -> str:
    # Localizable.strings keys are UTF-8. Decode only the escapes that can
    # appear in a quoted key; unicode_escape would corrupt Cyrillic text.
    return value.replace(r'\"', '"').replace(r'\\', '\\')


def parse_strings(path: pathlib.Path) -> set[str]:
    text = path.read_text(encoding="utf-8")
    return {unescape_strings_key(k) for k in KEY_RE.findall(text)}


def main() -> int:
    english = parse_strings(APP / "en.lproj" / "Localizable.strings")
    russian = parse_strings(APP / "ru.lproj" / "Localizable.strings")

    referenced: dict[str, list[str]] = {}
    for path in APP.rglob("*.swift"):
        text = path.read_text(encoding="utf-8")
        for raw_key in CALL_RE.findall(text):
            key = unescape_strings_key(raw_key)
            referenced.setdefault(key, []).append(str(path.relative_to(ROOT)))

    missing: list[str] = []

    # Russian source keys are a valid RU fallback by design. English source
    # keys are likewise already English. The release blocker is a Cyrillic
    # runtime key with no explicit English translation.
    for key, locations in sorted(referenced.items()):
        if CYRILLIC_RE.search(key) and key not in english:
            missing.append(
                f"[en] missing {key!r} used by {', '.join(sorted(set(locations))[:3])}"
            )

    # Settings is release-critical. Catch visible Cyrillic literals even when a
    # future refactor forgets to wrap one in GRUL10n. Technical/debug-only values
    # can be exempted explicitly and therefore remain reviewable.
    settings = APP / "Views" / "SettingsView.swift"
    settings_text = settings.read_text(encoding="utf-8")
    exemptions = {
        "Физический iPhone",  # debug-only environment label
    }
    uncatalogued_settings: set[str] = set()
    for raw_literal in STRING_RE.findall(settings_text):
        literal = unescape_strings_key(raw_literal)
        if CYRILLIC_RE.search(literal) and literal not in exemptions:
            if literal not in english:
                uncatalogued_settings.add(literal)

    missing.extend(
        f"[settings/en] missing translation for visible literal {value!r}"
        for value in sorted(uncatalogued_settings)
    )

    if missing:
        print("Localization audit FAILED:")
        for problem in missing:
            print(f" - {problem}")
        return 1

    print(
        "Localization audit OK: "
        f"{len(referenced)} runtime keys; en={len(english)}; ru={len(russian)}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
