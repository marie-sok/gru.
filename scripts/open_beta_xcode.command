#!/bin/bash
set -euo pipefail

GRU_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GRU_PROJECT="$GRU_ROOT/swiftui/GRU/gru..xcodeproj"
GRU_API="$GRU_ROOT/swiftui/GRU/gru./Services/APIClient.swift"

[[ "$(uname -s)" == Darwin ]] || { echo "Этот запуск предназначен для macOS с Xcode."; exit 1; }
[[ -d "$GRU_PROJECT" && -f "$GRU_API" ]] || { echo "Не найден полный iOS-проект."; exit 1; }

GRU_IP="$(ipconfig getifaddr en0 2>/dev/null || true)"
if [[ -z "$GRU_IP" ]]; then
  GRU_IP="$(ipconfig getifaddr en1 2>/dev/null || true)"
fi
if [[ "$GRU_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  grep -q 'private static let physicalDeviceHost = ' "$GRU_API" || { echo "Формат настройки сервера изменился."; exit 1; }
  GRU_LAN_IP="$GRU_IP" perl -pi -e 's/private static let physicalDeviceHost = "[^"]*"/private static let physicalDeviceHost = "$ENV{GRU_LAN_IP}"/' "$GRU_API"
  echo "Адрес Mac для iPhone: $GRU_IP:8081"
else
  echo "LAN-адрес не найден. Для этой сборки используй Simulator."
fi

echo "Проверка локального backend:"
if ! curl --fail --silent --show-error --max-time 5 http://127.0.0.1:8081/health; then
  echo ""
  echo "Backend недоступен: запусти свой сервер на порту 8081. Без него вход не пройдёт."
fi
echo ""
echo "Открываю: $GRU_PROJECT"
open -a Xcode "$GRU_PROJECT"
echo "Выбери схему gru, iPhone или Simulator и нажми Command + R."
echo "Темы: Настройки → Темы → Живой фон. Для проверки есть кнопка На весь экран."
