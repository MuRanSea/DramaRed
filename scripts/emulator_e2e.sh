#!/usr/bin/env bash
# DramaRed Android emulator E2E smoke (issue #3).
# Modes:
#   OHG (default): needs emulator outbound network
#   LOCAL: SMOKE_URL=http://127.0.0.1:8765/sample.mp4 + adb reverse (media_kit out画)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APK="${APK:-$ROOT/apps/android/build/app/outputs/flutter-apk/app-x86_64-debug.apk}"
PKG=com.dramared.app
QUERY="${SMOKE_QUERY:-短剧}"
SECONDS_OBS="${SMOKE_SECONDS:-20}"
SERIAL="${ANDROID_SERIAL:-emulator-5554}"
SMOKE_URL="${SMOKE_URL:-}"
LOG_DIR="${LOG_DIR:-$ROOT/docs/smoke-artifacts}"
mkdir -p "$LOG_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOGCAT_OUT="$LOG_DIR/logcat-$STAMP.txt"
SUMMARY_OUT="$LOG_DIR/summary-$STAMP.md"

adb -s "$SERIAL" wait-for-device
boot="$(adb -s "$SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
echo "device=$SERIAL boot_completed=$boot"

if [[ ! -f "$APK" ]]; then
  echo "missing APK: $APK" >&2
  exit 2
fi

adb -s "$SERIAL" install -r -t "$APK"

# Local file mode: push sample if SMOKE_URL empty and SMOKE_MODE=local (or file:// requested)
SAMPLE="$ROOT/docs/smoke-artifacts/sample.mp4"
if [[ "${SMOKE_MODE:-}" == "local" || "$SMOKE_URL" == file://* ]]; then
  if [[ -z "$SMOKE_URL" || "$SMOKE_URL" == file://* ]]; then
    SMOKE_URL="file:///data/local/tmp/sample.mp4"
  fi
  if [[ -f "$SAMPLE" ]]; then
    adb -s "$SERIAL" push "$SAMPLE" /data/local/tmp/sample.mp4 >/dev/null
  fi
fi
adb -s "$SERIAL" logcat -c || true
adb -s "$SERIAL" shell am force-stop "$PKG" || true

EXTRA_URL=()
if [[ -n "$SMOKE_URL" ]]; then
  EXTRA_URL=(--es smoke_url "$SMOKE_URL")
  # If using host reverse URL, ensure reverse is up (caller may already have set it)
  echo "smoke_url=$SMOKE_URL"
fi

adb -s "$SERIAL" shell am start -n "$PKG/.MainActivity" \
  --ez smoke_auto true \
  --es smoke_query "$QUERY" \
  --ei smoke_seconds "$SECONDS_OBS" \
  "${EXTRA_URL[@]+"${EXTRA_URL[@]}"}"

TIMEOUT=$((SECONDS_OBS + 120))
echo "watching logcat for ${TIMEOUT}s…"
: >"$LOGCAT_OUT"
adb -s "$SERIAL" logcat -v time >"$LOGCAT_OUT" &
LOG_PID=$!
RESULT=""
for ((i=0; i<TIMEOUT; i+=2)); do
  if grep -qE 'DramaRedSmoke.*(PASS|FAIL)' "$LOGCAT_OUT" 2>/dev/null; then
    if grep -q 'DramaRedSmoke.*PASS' "$LOGCAT_OUT"; then RESULT=PASS; else RESULT=FAIL; fi
    break
  fi
  sleep 2
done
kill "$LOG_PID" 2>/dev/null || true
wait "$LOG_PID" 2>/dev/null || true

SMOKE_LINES="$(grep 'DramaRedSmoke' "$LOGCAT_OUT" 2>/dev/null | tail -100 || true)"
{
  echo "# Emulator smoke $STAMP"
  echo
  echo "- serial: \`$SERIAL\`"
  echo "- query: \`$QUERY\`"
  echo "- smoke_url: \`${SMOKE_URL:-}\`"
  echo "- observe: ${SECONDS_OBS}s"
  echo "- result: **${RESULT:-TIMEOUT}**"
  echo "- apk: \`$APK\`"
  echo
  echo "## DramaRedSmoke lines"
  echo '```'
  echo "$SMOKE_LINES"
  echo '```'
} > "$SUMMARY_OUT"

echo "summary=$SUMMARY_OUT result=${RESULT:-TIMEOUT}"
echo "$SMOKE_LINES" | tail -40
[[ "${RESULT:-}" == "PASS" ]]
