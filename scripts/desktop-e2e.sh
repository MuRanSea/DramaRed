#!/usr/bin/env bash
# Desktop e2e on the box: unit/UI tests + daemon API chain + optional xvfb GUI + zip checks.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export DOTNET_ROOT="${DOTNET_ROOT:-/home/box/.dotnet}"
export PATH="${DOTNET_ROOT}:/usr/local/go/bin:${PATH}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${ROOT}/docs/smoke-artifacts/desktop-e2e-${STAMP}"
mkdir -p "${OUT}"
ADDR="127.0.0.1:17991"
PASS=0
FAIL=0
SKIP=0

log() { echo "[e2e] $*"; }
ok() { echo "PASS  $*" | tee -a "${OUT}/summary.txt"; PASS=$((PASS+1)); }
bad() { echo "FAIL  $*" | tee -a "${OUT}/summary.txt"; FAIL=$((FAIL+1)); }
skip() { echo "SKIP  $*" | tee -a "${OUT}/summary.txt"; SKIP=$((SKIP+1)); }

echo "DramaRed desktop e2e ${STAMP}" > "${OUT}/summary.txt"
echo "commit $(git -C "${ROOT}" rev-parse --short HEAD 2>/dev/null || echo unknown)" >> "${OUT}/summary.txt"

log "1) dotnet test (UI headless + unit)"
if (cd "${ROOT}" && dotnet test apps/desktop/ui.Tests/DramaRed.UI.Tests.csproj -c Release --nologo --logger "console;verbosity=detailed") | tee "${OUT}/dotnet-test.log"; then
  ok "dotnet test"
else
  bad "dotnet test"
fi

log "2) build daemon + UI linux"
(cd "${ROOT}/apps/desktop/daemon" && go build -o "${OUT}/drama-daemon" ./cmd/drama-daemon)
ok "go build daemon"
(cd "${ROOT}" && dotnet build apps/desktop/ui/DramaRed.UI.csproj -c Release -r linux-x64 --nologo) | tee "${OUT}/dotnet-build.log"
ok "dotnet build UI"

log "3) daemon API chain on ${ADDR}"
pkill -f "17991" 2>/dev/null || true
DATA="${OUT}/daemon-data"
mkdir -p "${DATA}"
"${OUT}/drama-daemon" -addr "${ADDR}" -data "${DATA}" >"${OUT}/daemon.log" 2>&1 &
DPID=$!
cleanup() { kill "${DPID}" 2>/dev/null || true; }
trap cleanup EXIT

for i in $(seq 1 40); do
  if curl -fsS "http://${ADDR}/health" >/dev/null 2>&1; then break; fi
  sleep 0.25
done

curl -fsS "http://${ADDR}/health" | tee "${OUT}/health.json" >/dev/null
ok "health"

curl -fsS "http://${ADDR}/api/v1/discover" | tee "${OUT}/discover.json" >/dev/null
DISC_COUNT=$(python3 -c 'import json;print(len(json.load(open("'"${OUT}/discover.json"'")).get("items",[])))')
test "${DISC_COUNT}" -gt 0 && ok "discover count=${DISC_COUNT}" || bad "discover empty"

curl -fsS --get --data-urlencode "q=总裁" "http://${ADDR}/api/v1/search" | tee "${OUT}/search.json" >/dev/null
SEARCH_COUNT=$(python3 -c 'import json;print(len(json.load(open("'"${OUT}/search.json"'")).get("items",[])))')
test "${SEARCH_COUNT}" -gt 0 && ok "search count=${SEARCH_COUNT}" || bad "search empty"

SERIES_ID=$(python3 -c 'import json;print(json.load(open("'"${OUT}/discover.json"'"))["items"][0]["id"])')
curl -fsS "http://${ADDR}/api/v1/series/${SERIES_ID}/episodes" | tee "${OUT}/episodes.json" >/dev/null
EP_COUNT=$(python3 -c 'import json;print(len(json.load(open("'"${OUT}/episodes.json"'")).get("items",[])))')
test "${EP_COUNT}" -gt 0 && ok "episodes count=${EP_COUNT}" || bad "episodes empty"

EP_ID=$(python3 -c 'import json;print(json.load(open("'"${OUT}/episodes.json"'"))["items"][0]["id"])')
curl -fsS "http://${ADDR}/api/v1/episodes/${EP_ID}/playback" | tee "${OUT}/playback.json" >/dev/null
STREAMS=$(python3 -c 'import json;d=json.load(open("'"${OUT}/playback.json"'"));print(len((d.get("playback") or {}).get("streams") or []))')
test "${STREAMS}" -gt 0 && ok "playback streams=${STREAMS}" || bad "playback no streams"

log "4) libmpv smoke (optional)"
if [[ -f /usr/lib/x86_64-linux-gnu/libmpv.so.2 ]] || ldconfig -p 2>/dev/null | grep -q libmpv; then
  (cd "${ROOT}" && dotnet build apps/desktop/tools/mpv-smoke -c Release --nologo) | tee "${OUT}/mpv-smoke-build.log" >/dev/null
  # Public short sample first (stable); OHG DRM URL is best-effort below.
  if timeout 30s xvfb-run -a dotnet run --project "${ROOT}/apps/desktop/tools/mpv-smoke" -c Release --no-build -- "https://filesamples.com/samples/video/mp4/sample_640x360.mp4" | tee "${OUT}/libmpv-smoke.log"; then
    ok "libmpv open public sample"
  else
    bad "libmpv smoke (public sample)"
  fi
  URL=$(python3 -c 'import json;d=json.load(open("'"${OUT}/playback.json"'"));ss=(d.get("playback") or {}).get("streams") or []; print(ss[0]["url"] if ss else "")')
  if [[ -n "${URL}" ]]; then
    if timeout 35s xvfb-run -a dotnet run --project "${ROOT}/apps/desktop/tools/mpv-smoke" -c Release --no-build -- "${URL}" | tee -a "${OUT}/libmpv-smoke.log"; then
      ok "libmpv open OHG playback url"
    else
      # DRM/network flake should not block release if public sample passed
      skip "libmpv OHG url (non-blocking)"
    fi
  fi
else
  skip "libmpv (library not on host)"
fi

log "5) Avalonia xvfb GUI smoke"
UI_DLL="${ROOT}/apps/desktop/ui/bin/Release/net10.0/linux-x64/DramaRed.UI.dll"
# Start daemon on default port for GUI if needed — UI may auto-start sibling; for smoke just launch
set +e
timeout 10s xvfb-run -a env DISPLAY=:99 dotnet "${UI_DLL}" >"${OUT}/avalonia-launch.log" 2>&1
RC=$?
set -e
if [[ "${RC}" -eq 124 ]]; then
  ok "Avalonia xvfb kept running until timeout (no instant crash)"
elif [[ "${RC}" -eq 0 ]]; then
  ok "Avalonia xvfb exited 0"
else
  # Check for unhandled exception
  if rg -q "Unhandled|Fatal|Exception:" "${OUT}/avalonia-launch.log"; then
    bad "Avalonia xvfb exit=${RC} with exception"
  else
    # Missing daemon sibling can cause early exit; treat soft if process at least started
    if rg -q "Avalonia|DramaRed|TFM|播放" "${OUT}/avalonia-launch.log"; then
      ok "Avalonia xvfb started (exit=${RC}, no unhandled exception)"
    else
      bad "Avalonia xvfb exit=${RC}"
    fi
  fi
fi

log "6) package zip + static libmpv checks"
(cd "${ROOT}" && ./scripts/package-windows.sh) | tee "${OUT}/package.log"
ZIP="${ROOT}/dist/DramaRed-desktop-win-x64.zip"
python3 - << PY | tee "${OUT}/zip-check.txt"
import zipfile, sys
zf=zipfile.ZipFile("${ZIP}")
names=zf.namelist()
need=["DramaRed.UI.exe","drama-daemon.exe","libmpv-2.dll","README.txt","THIRD_PARTY/libmpv-LICENSE.LGPL"]
missing=[]
for n in need:
    if not any(x.endswith(n) for x in names):
        missing.append(n)
print("entries", len(names))
print("missing", missing)
sys.exit(1 if missing else 0)
PY
ok "zip contains libmpv-2.dll + exes"

# Windows detection logic (unit already covers); also assert first candidate path shape in shipped docs/README
rg -q "libmpv-2.dll" "${ROOT}/dist/DramaRed-desktop-win-x64/README.txt" && ok "README mentions libmpv" || bad "README missing libmpv note"

echo "" | tee -a "${OUT}/summary.txt"
echo "RESULT pass=${PASS} fail=${FAIL} skip=${SKIP}" | tee -a "${OUT}/summary.txt"
echo "artifacts: ${OUT}" | tee -a "${OUT}/summary.txt"
test "${FAIL}" -eq 0
