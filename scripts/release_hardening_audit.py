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
ROOT_VIEW = "swiftui/GRU/gru./Views/RootView.swift"
CHAT_VIEW = "swiftui/GRU/gru./Views/ChatView.swift"
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

# Authentication UX: no custom lock screen/button. Persisted sessions and real
# background returns use the system device-owner flow (Face ID/Touch ID/Optic ID
# with device passcode fallback). Only an actual background transition may arm
# a foreground re-auth; LocalAuthentication's inactive/active transitions must
# never retrigger themselves.
require(ROOT_VIEW, "func authenticateForAppAccess() async -> Bool",
        "system app-unlock function is missing")
require(ROOT_VIEW, ".deviceOwnerAuthentication",
        "system authentication must allow biometrics or device passcode")
require(ROOT_VIEW, "needsUnlockAfterBackground = true",
        "real background transition does not arm re-authentication")
require(ROOT_VIEW, "needsUnlockAfterBackground = false",
        "foreground authentication flag is not consumed/reset")
require(ROOT_VIEW, "returnToLoginAfterUnlockFailure()",
        "failed/cancelled system authentication does not return to login")
forbid(ROOT_VIEW, "biometricLockOverlay",
       "custom biometric lock overlay returned")
forbid(ROOT_VIEW, 'Text(GRUL10n.text("Разблокировать"))',
       "custom unlock button returned")
forbid(ROOT_VIEW, "isBiometricLocked",
       "legacy biometric lock-state machine returned")

# Screen privacy.
#
# Root protection uses only public recording/lifecycle signals. Still-screenshot
# replacement is allowed exclusively inside authenticated ChatView. GRU mirrors
# Telegram-iOS' layer-level secure-rendering guard: temporarily substitute the
# protected CALayer into UITextField's TextLayoutCanvasView, toggle secureTextEntry,
# then restore the original canvas layer. RootView/auth must never use this path.
require(SCREEN, "UIScreen.main.isCaptured", "screen-recording/mirroring redaction is missing")
require(SCREEN, "UIApplication.willResignActiveNotification", "app-switcher privacy shield is missing")
require(SCREEN, "UIApplication.didEnterBackgroundNotification", "background privacy shield is missing")
require(SCREEN, "UIApplication.userDidTakeScreenshotNotification", "screenshot detection is missing")
require(SCREEN, ".privacySensitive()", "SwiftUI privacySensitive marker is missing")
require(SCREEN, "GRUTelegramLayerScreenshotGuard",
        "Telegram-style chat screenshot layer guard is missing")
require(SCREEN, "GRUChatSecureCaptureContainer",
        "chat-scoped secure compositor is missing")
require(SCREEN, 'secureView.setValue(layer, forKey: "layer")',
        "Telegram-style protected layer substitution is missing")
require(SCREEN, "textField.isSecureTextEntry = true",
        "Telegram-style secureTextEntry toggle is missing")
require(SCREEN, "GRUPrivacyCaptureScene",
        "GRU privacy replacement scene is missing")
require(CHAT_VIEW, "GRUChatCaptureProtection",
        "ChatView is not wrapped by chat-scoped screenshot protection")
forbid(ROOT_VIEW, "GRUChatCaptureProtection",
       "chat screenshot compositor leaked into RootView/auth lifecycle")
forbid(APP, "GRUChatCaptureProtection",
       "chat screenshot compositor leaked into app root")
forbid(SCREEN, "GRUSecureCaptureContainer",
       "legacy root-level secure capture container returned")
forbid(SCREEN, "GRUNonResponderSecureField",
       "legacy root-level secure field returned")

screen_text = read(SCREEN)
if "struct GRUScreenProtectionView" in screen_text:
    root_section = screen_text.split("struct GRUScreenProtectionView", 1)[1]
    if "GRUChatSecureCaptureContainer" in root_section:
        failures.append("root GRUScreenProtectionView must not use the chat secure compositor")
    if "GRUTelegramLayerScreenshotGuard" in root_section:
        failures.append("Telegram-style screenshot guard leaked into root/auth protection")

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
