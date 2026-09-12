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
DICT_KEY_RE = re.compile(r'^\s*"((?:\\.|[^"])*)"\s*:', re.MULTILINE)
CYRILLIC_RE = re.compile(r"[А-Яа-яЁё]")
STRING_RE = re.compile(r'"((?:\\.|[^"])*)"')

# These views are retained only for migration/reference. MainView renders
# GRUStableSettingsView in the physical beta, so stale legacy strings must not
# block the release while still-unused screens remain in the source tree.
LEGACY_SWIFT_FILES = {
    "Views/BetaSettingsView.swift",
    "Views/SettingsView.swift",
    "Views/GRUReleaseSettingsView.swift",
}


def unescape_strings_key(value: str) -> str:
    return value.replace(r'\"', '"').replace(r'\\', '\\')


def parse_strings(path: pathlib.Path) -> set[str]:
    text = path.read_text(encoding="utf-8")
    return {unescape_strings_key(k) for k in KEY_RE.findall(text)}


def english_fallback_keys() -> set[str]:
    path = APP / "Services" / "GRULanguage.swift"
    text = path.read_text(encoding="utf-8")
    marker = "case .english:"
    start = text.find(marker)
    if start < 0:
        return set()
    english_block = text[start:]
    return {unescape_strings_key(k) for k in DICT_KEY_RE.findall(english_block)}


def main() -> int:
    english_catalog = parse_strings(APP / "en.lproj" / "Localizable.strings")
    russian_catalog = parse_strings(APP / "ru.lproj" / "Localizable.strings")
    english_runtime_keys = english_catalog | english_fallback_keys()

    referenced: dict[str, list[str]] = {}
    for path in APP.rglob("*.swift"):
        relative_app_path = path.relative_to(APP).as_posix()
        if relative_app_path in LEGACY_SWIFT_FILES:
            continue

        text = path.read_text(encoding="utf-8")
        for raw_key in CALL_RE.findall(text):
            key = unescape_strings_key(raw_key)
            referenced.setdefault(key, []).append(str(path.relative_to(ROOT)))

    missing: list[str] = []
    for key, locations in sorted(referenced.items()):
        if CYRILLIC_RE.search(key) and key not in english_runtime_keys:
            missing.append(
                f"[en] missing {key!r} used by {', '.join(sorted(set(locations))[:3])}"
            )

    # The settings view that is actually rendered by MainView is release-critical.
    # Every visible Cyrillic literal there must have an English runtime mapping.
    settings = APP / "Views" / "GRUStableSettingsView.swift"
    settings_text = settings.read_text(encoding="utf-8")
    exemptions = {
        "Физический iPhone",  # debug-only environment label
    }
    uncatalogued_settings: set[str] = set()
    for raw_literal in STRING_RE.findall(settings_text):
        literal = unescape_strings_key(raw_literal)
        if CYRILLIC_RE.search(literal) and literal not in exemptions:
            if literal not in english_runtime_keys:
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
        f"{len(referenced)} runtime keys; "
        f"en catalog={len(english_catalog)}; "
        f"en fallback={len(english_fallback_keys())}; "
        f"ru catalog={len(russian_catalog)}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
