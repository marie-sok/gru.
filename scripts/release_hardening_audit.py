#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []
warnings: list[str] = []


def read(relative: str) -> str:
    path = ROOT / relative
    if not path.exists():
        failures.append(f"missing required file: {relative}")
        return ""
    return path.read_text(encoding="utf-8")


def require(relative: str, needle: str, label: str | None = None) -> None:
    text = read(relative)
    if needle not in text:
        failures.append(label or f"{relative}: missing {needle!r}")


def forbid(relative: str, needle: str, label: str | None = None) -> None:
    text = read(relative)
    if needle in text:
        failures.append(label or f"{relative}: forbidden {needle!r}")


def check_regex(relative: str, pattern: str, label: str) -> None:
    text = read(relative)
    if not re.search(pattern, text, flags=re.MULTILINE | re.DOTALL):
        failures.append(label)


SCHEME = "swiftui/GRU/gru..xcodeproj/xcshareddata/xcschemes/gru.xcscheme"
PROJECT = "swiftui/GRU/gru..xcodeproj/project.pbxproj"
APP = "swiftui/GRU/gru./Apps/gru_App.swift"
API = "swiftui/GRU/gru./Services/APIClient.swift"
SCREEN = "swiftui/GRU/gru./Security/GRUScreenProtection.swift"
MAIN = "swiftui/GRU/gru./Views/MainView.swift"
SETTINGS = "swiftui/GRU/gru./Views/GRUStableSettingsView.swift"
APP_TAB = "swiftui/GRU/gru./Models/AppTab.swift"
RADIO = "swiftui/GRU/gru./Services/GRURadioHandoffMonitor.swift"
VOICE = "swiftui/GRU/gru./Components/VoiceAudioRecorderView.swift"
VIDEO_NOTE = "swiftui/GRU/gru./Components/VideoNoteRecorderView.swift"
ENTITLEMENTS = "swiftui/GRU/gru./gru_.entitlements"

# Normal Xcode Run on a physical iPhone must use Release transport.
check_regex(
    SCHEME,
    r'<LaunchAction\s+buildConfiguration\s*=\s*"Release"',
    "shared Xcode scheme LaunchAction is not Release",
)

# Release must be explicitly pinned to the public GRU edge.
require(PROJECT, 'INFOPLIST_KEY_GRUProductionHTTPBaseURL = "https://gru-edge-v2.onrender.com";',
        "Release HTTP endpoint is not pinned to gru-edge-v2")
require(PROJECT, 'INFOPLIST_KEY_GRUProductionWebSocketURL = "wss://gru-edge-v2.onrender.com/ws";',
        "Release WebSocket endpoint is not pinned to gru-edge-v2")
require(PROJECT, "MARKETING_VERSION = 0.9.2;", "expected beta marketing version 0.9.2 is missing")

# Runtime language changes must not recreate the navigation root.
require(APP, "RootView()")
require(APP, ".environment(\n                \\.locale,", "runtime locale environment is missing")
forbid(APP, ".id(languageRaw)", "language switching would recreate RootView")
forbid(APP, "releaseTransportGate", "obsolete startup transport gate returned")
forbid(APP, "Не удалось открыть безопасное подключение GRU", "obsolete false-safe startup screen returned")

# Screen privacy: still-screenshot redaction uses one isolated secure compositor
# host. The secure field must be a non-responder with an empty keyboard host so
# the old keyboard/black-screen regression cannot silently return.
require(SCREEN, "private final class GRUNonResponderSecureField: UITextField",
        "isolated screenshot secure field is missing")
require(SCREEN, "override var canBecomeFirstResponder: Bool { false }",
        "secure screenshot host can become first responder")
require(SCREEN, "override func becomeFirstResponder() -> Bool",
        "secure screenshot host does not explicitly reject focus")
require(SCREEN, "secureField.isSecureTextEntry = true",
        "secure compositor is not enabled for still screenshot redaction")
require(SCREEN, "secureField.inputView = UIView(frame: .zero)",
        "secure screenshot host can still request a keyboard")
forbid(SCREEN, "let secureField = UITextField(",
       "raw secure UITextField constructor returned; use GRUNonResponderSecureField only")
require(SCREEN, "UIScreen.main.isCaptured", "screen-recording/mirroring redaction is missing")
require(SCREEN, "UIApplication.willResignActiveNotification", "app-switcher privacy shield is missing")
require(SCREEN, "UIApplication.didEnterBackgroundNotification", "background privacy shield is missing")
require(SCREEN, "UIApplication.userDidTakeScreenshotNotification", "screenshot detection is missing")
require(SCREEN, ".privacySensitive()", "SwiftUI privacySensitive marker is missing")

# Settings structure and tab surface.
require(MAIN, "GRUStableSettingsView()", "MainView is not using stable beta settings")
forbid(MAIN, "GRUE2EESecurityCenterView", "user-facing E2EE overlay/button returned")
forbid(SETTINGS, "Центр управления", "legacy control-center section returned")
forbid(SETTINGS, "GRUE2EESecurityCenterView", "E2EE center should remain internal")
forbid(APP_TAB, "case music", "Music tab returned")

# Cellular/Wi-Fi recovery must remain wired to production realtime.
require(APP, "GRURadioHandoffMonitor.shared.start()", "radio handoff monitor is not started")
require(APP, "GRUConnectivityCenter.shared.reconnectRealtime()", "foreground realtime recovery is missing")
require(RADIO, "path.usesInterfaceType(.cellular)", "cellular handoff detection is missing")
require(RADIO, "GRUConnectivityCenter.shared.reconnectRealtime()", "radio handoff does not reconnect realtime")

# Audio/video capture must keep blocking session work off the main queue.
require(VOICE, "DispatchQueue.global(qos: .userInitiated).async", "voice AVAudioSession activation is not off-main")
require(VIDEO_NOTE, 'label: "gru.video-note.capture-session"', "video-note capture serial queue is missing")
require(VIDEO_NOTE, "session.startRunning()", "video-note capture start is missing")

# Release config still has a direct-backend source fallback. It is not used while
# generated Info.plist keys above are present, but keep it visible as debt rather
# than silently treating it as a passing security property.
api_text = read(API)
if "gru-jiqi.onrender.com" in api_text:
    warnings.append(
        "APIClient still contains a direct-backend fallback; Release is currently protected by explicit edge Info.plist keys"
    )

# APNs is intentionally not claimed as complete until provisioning + backend token
# registration exist. Surface this as a release warning, not a fake green check.
entitlements_text = read(ENTITLEMENTS)
if "aps-environment" not in entitlements_text:
    warnings.append(
        "remote APNs push is not provisioned yet; current notification path is local/in-app only"
    )

print("GRU physical beta release-hardening audit")
for warning in warnings:
    print(f"WARN: {warning}")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}", file=sys.stderr)
    print(f"FAILED: {len(failures)} blocking check(s)", file=sys.stderr)
    sys.exit(1)

print(f"PASS: all blocking checks passed ({len(warnings)} non-blocking warning(s))")
