#!/usr/bin/env python3
"""Live desktop feature review under Xvfb :99."""
from __future__ import annotations
import json, os, subprocess, time, signal
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/smoke-artifacts/feature-review-20261106/desktop"
UI = ROOT / "apps/desktop/ui/bin/Release/net10.0/linux-x64/DramaRed.UI"
DISPLAY = os.environ.get("FEATURE_DISPLAY", ":99")
NOTES = []

def sh(cmd, check=True, **kw):
    env = os.environ.copy()
    env["DISPLAY"] = DISPLAY
    env.setdefault("LIBGL_ALWAYS_SOFTWARE", "1")
    return subprocess.run(cmd, check=check, env=env, text=True, capture_output=True, **kw)

def shot(name, settle=1.5):
    time.sleep(settle)
    path = OUT / f"{name}.png"
    r = sh(["ffmpeg","-y","-f","x11grab","-video_size","1800x900","-i",f"{DISPLAY}.0",
            "-frames:v","1","-update","1",str(path)], check=False)
    if r.returncode != 0 or not path.exists() or path.stat().st_size < 1000:
        raise RuntimeError(f"shot failed {name}: {(r.stderr or '')[-400:]}")
    print(f"SHOT {name} {path.stat().st_size}")
    return path

def note(feature, verdict, detail, shots):
    NOTES.append({"feature": feature, "verdict": verdict, "detail": detail, "shots": shots})
    print(f"NOTE [{verdict}] {feature}: {detail}")

def xdo(*args, check=False):
    return sh(["xdotool", *args], check=check)

def win_id():
    for _ in range(60):
        r = sh(["xdotool","search","--name","DramaRed"], check=False)
        ids = [x for x in (r.stdout or "").split() if x.isdigit()]
        if ids:
            return ids[-1]
        time.sleep(0.5)
    raise TimeoutError("DramaRed window not found")

def click(x, y, pause=0.4):
    xdo("mousemove", "--sync", str(x), str(y))
    time.sleep(0.05)
    xdo("click", "1")
    time.sleep(pause)
    print(f"CLICK {x},{y}")

def key(*keys):
    xdo("key", *keys)

def type_text(s):
    # ascii only
    sh(["xdotool","type","--delay","40",s], check=False)

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    subprocess.run(["pkill","-f","DramaRed.UI"], check=False)
    time.sleep(1)
    if sh(["xdpyinfo"], check=False).returncode != 0:
        raise RuntimeError(f"DISPLAY {DISPLAY} not ready")

    log = open(OUT / "ui-review.log", "w")
    env = os.environ.copy()
    env["DISPLAY"] = DISPLAY
    env["LIBGL_ALWAYS_SOFTWARE"] = "1"
    env["AVALONIA_GLOBAL_SCALE_FACTOR"] = "1"
    proc = subprocess.Popen([str(UI)], cwd=str(ROOT), env=env, stdout=log, stderr=subprocess.STDOUT)
    print("UI pid", proc.pid)
    try:
        wid = win_id()
        print("wid", wid)
        xdo("windowmove", wid, "0", "0")
        xdo("windowsize", wid, "1800", "900")
        xdo("windowraise", wid)
        time.sleep(10)  # discover + heic covers
        shot("R01-home-covers", 2)

        # theater
        click(100, 148)
        time.sleep(1.5)
        shot("R02-theater", 1)

        # search via top bar
        click(100, 188)  # nav 搜索 page first
        time.sleep(0.8)
        click(720, 38)   # top search box
        key("ctrl+a")
        key("BackSpace")
        type_text("zongcai")
        time.sleep(0.2)
        click(1020, 38)  # 搜索 button
        time.sleep(8)
        shot("R03-search-results", 1)

        # go home and open first poster (card center)
        click(100, 108)
        time.sleep(2)
        click(260, 300)
        time.sleep(14)
        shot("R04-player", 1)

        # 下一集 — right side controls; try keyboard PageDown / Down
        key("Down")
        time.sleep(7)
        shot("R04-player-next", 1)

        # leave to history — must hide mpv
        click(100, 268)
        time.sleep(2.5)
        shot("R05-history-no-mpv-overlay", 1)

        click(100, 308)
        time.sleep(1.5)
        shot("R06-favorites", 1)

        click(100, 348)
        time.sleep(1.5)
        shot("R07-settings", 1)

        click(100, 108)
        time.sleep(2)
        shot("R08-home-after-leave-player", 1)

        # offline-ish: just capture chrome hide button area already in shots
        shot("R09-chrome-hide-continue", 0.3)

        note("首页封面(HEIC)", "REVIEW", "R01", ["R01-home-covers.png"])
        note("剧场", "REVIEW", "R02", ["R02-theater.png"])
        note("搜索", "REVIEW", "R03", ["R03-search-results.png"])
        note("播放切集", "REVIEW", "R04", ["R04-player.png","R04-player-next.png"])
        note("离开播放藏mpv", "REVIEW", "R05/R08", ["R05-history-no-mpv-overlay.png","R08-home-after-leave-player.png"])
        note("收藏历史", "REVIEW", "R05/R06", ["R05-history-no-mpv-overlay.png","R06-favorites.png"])
        note("设置/定时/后台听", "REVIEW", "R07/R09", ["R07-settings.png","R09-chrome-hide-continue.png"])
        (OUT/"notes-desktop.json").write_text(json.dumps(NOTES, ensure_ascii=False, indent=2), encoding="utf-8")
        print(json.dumps(NOTES, ensure_ascii=False, indent=2))
    finally:
        proc.send_signal(signal.SIGTERM)
        try: proc.wait(timeout=5)
        except Exception: proc.kill()
        log.close()

if __name__ == "__main__":
    main()
