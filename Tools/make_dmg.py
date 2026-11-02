#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
把 Release 版 Random.app 打包成「拖进 Applications」式 DMG。

用法：
    python3 Tools/make_dmg.py                       # 自动找最新 Release 产物
    python3 Tools/make_dmg.py --app /Applications/Random.app
    python3 Tools/make_dmg.py --out /tmp/Random.dmg

产出：<项目根>/Random-<版本>.dmg（UDZO 压缩，只读，含 Applications 快捷方式 + 背景图与布局）

流程（标准 dmg 做法）：
    1. 造 staging 目录（app + Applications 软链 + 隐藏 .background 图）
    2. 先打成 UDRW 可写镜像
    3. 挂载 → 用 Finder（AppleScript）排好图标、贴上背景 → 卸载
    4. convert 成 UDZO 只读压缩镜像
第 3 步需要「控制 Finder」的权限；没权限也不影响使用（只是打开时是默认排布，照样能拖）。
"""

import argparse
import os
import plistlib
import shutil
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DERIVED = os.path.expanduser(
    "~/Library/Developer/Xcode/DerivedData/Random-fncxrdyvpwgwgwbxfyniszxiwmeq"
    "/Build/Products/Release/Random.app"
)

# 窗口（点坐标）与背景画布（@2x）
WIN_W, WIN_H = 660, 400
BG_W, BG_H = WIN_W * 2, WIN_H * 2
ICON_Y = 205
APP_X, APL_X = 170, 490

FONT_CANDIDATES = [
    "/System/Library/Fonts/Hiragino Sans GB.ttc",
    "/System/Library/Fonts/STHeiti Medium.ttc",
    "/System/Library/Fonts/Helvetica.ttc",
]


def load_font(size):
    for p in FONT_CANDIDATES:
        if not os.path.exists(p):
            continue
        try:
            return ImageFont.truetype(p, size)
        except Exception:
            continue
    return ImageFont.load_default()


def make_background(path, version):
    """浅色渐变 + 虚线箭头 + 说明文字（@2x）"""
    img = Image.new("RGB", (BG_W, BG_H), "#FFFFFF")
    d = ImageDraw.Draw(img)

    # 竖向渐变
    top, bottom = (247, 248, 250), (233, 236, 242)
    for y in range(BG_H):
        t = y / (BG_H - 1)
        d.line(
            [(0, y), (BG_W, y)],
            fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)),
        )

    # 虚线箭头：Random → Applications
    ax, bx, ay = 260, 400, ICON_Y
    color = (154, 163, 178)
    step, dash = 0, 14
    x = ax
    while x < bx - 26:
        d.line([(x * 2, ay * 2), ((x + dash) * 2, ay * 2)], fill=color, width=4)
        x += dash + 10
        step += 1
    # 箭头尖
    tip_x, half = bx, 13
    d.polygon(
        [
            (tip_x * 2, ay * 2),
            ((tip_x - 26) * 2, (ay - half) * 2),
            ((tip_x - 26) * 2, (ay + half) * 2),
        ],
        fill=color,
    )

    # 文字
    f_big = load_font(30)
    f_small = load_font(21)
    gray, light = (107, 114, 128), (154, 163, 178)

    def center(text, font, y, fill):
        w = d.textlength(text, font=font)
        d.text(((BG_W - w) / 2, y * 2), text, font=font, fill=fill)

    center("把 Random 拖进 Applications 即可安装", f_big, 320, gray)
    center(f"v{version} · macOS 14+ · 首次打开请先导入 .randomroster 名单",
           f_small, 358, light)

    img.save(path, "PNG")


def run(cmd, **kw):
    return subprocess.run(cmd, check=True, capture_output=True, text=True, **kw)


def app_version(app):
    plist = os.path.join(app, "Contents/Info.plist")
    with open(plist, "rb") as f:
        return plistlib.load(f).get("CFBundleShortVersionString", "?")


def build_stage(app, stage):
    os.makedirs(stage, exist_ok=True)
    dst = os.path.join(stage, "Random.app")
    if os.path.exists(dst):
        shutil.rmtree(dst)
    shutil.copytree(app, dst, symlinks=True)

    link = os.path.join(stage, "Applications")
    if os.path.islink(link) or os.path.exists(link):
        os.remove(link)
    os.symlink("/Applications", link)

    bg_dir = os.path.join(stage, ".background")
    os.makedirs(bg_dir, exist_ok=True)
    return os.path.join(bg_dir, "background.png")


DMGBUILD = "/Users/joyren/.workbuddy/binaries/python/envs/default/bin/dmgbuild"

SETTINGS = """\
# -*- coding: utf-8 -*-
# dmgbuild 配置（由 Tools/make_dmg.py 生成）
import os

application = defines.get("app")
appname = os.path.basename(application)

files = [application]
symlinks = {"Applications": "/Applications"}

background = defines.get("bg")
window_rect = ((200, 120), (200 + {W}, 120 + {H}))
icon_size = 128
text_size = 13
icon_locations = {
    appname: ({AX}, {AY}),
    "Applications": ({PX}, {AY}),
}
default_view = "icon-view"
show_icon_preview = False
show_item_info = False
arrange_by = None
format = "UDZO"
""".replace("{W}", str(WIN_W)).replace("{H}", str(WIN_H)) \
   .replace("{AX}", str(APP_X)).replace("{PX}", str(APL_X)) \
   .replace("{AY}", str(ICON_Y))


def build_with_dmgbuild(app, bg, volume, out):
    """用 dmgbuild 打带布局的 dmg（直接写 .DS_Store，不需要 Finder 权限）"""
    if not os.path.exists(DMGBUILD):
        return False
    tmp = tempfile.mkdtemp(prefix="dmgbuild-")
    try:
        s = os.path.join(tmp, "settings.py")
        with open(s, "w", encoding="utf-8") as f:
            f.write(SETTINGS)
        run([DMGBUILD, "-s", s, "-D", f"app={app}", "-D", f"bg={bg}",
             volume, out])
        return True
    except Exception as e:
        print(f"  ⚠️ dmgbuild 失败，回退到无布局打包：{e}")
        return False
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def build_plain(app, stage_app_dir, volume, out):
    """回退方案：hdiutil 直接打 UDZO（图标排布交给 Finder 默认）"""
    rw = os.path.join(os.path.dirname(stage_app_dir), "rw.dmg")
    run(["hdiutil", "create", "-volname", volume, "-srcfolder", stage_app_dir,
         "-fs", "HFS+", "-format", "UDRW", "-ov", rw])
    run(["sync"])
    if os.path.exists(out):
        os.remove(out)
    run(["hdiutil", "convert", rw, "-format", "UDZO",
         "-imagekey", "zlib-level=9", "-o", out])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--app", default=DERIVED, help="要打包的 .app 路径")
    ap.add_argument("--out", default=None, help="输出 dmg 路径")
    args = ap.parse_args()

    app = args.app
    if not os.path.exists(app):
        sys.exit(f"找不到 app：{app}")
    ver = app_version(app)
    volume = f"Random {ver}"
    out = args.out or os.path.join(os.path.dirname(ROOT), f"Random-{ver}.dmg")

    tmp = tempfile.mkdtemp(prefix="random-dmg-")
    try:
        stage = os.path.join(tmp, "stage")
        print(f"📦 打包 {app}（v{ver}）")
        bg = build_stage(app, stage)
        make_background(bg, ver)
        print("  ✅ staging 就绪（Random.app + Applications + 背景图）")

        if os.path.exists(out):
            os.remove(out)
        if build_with_dmgbuild(app, bg, volume, out):
            print("  ✅ 图标排布 + 背景已写入镜像")
        else:
            build_plain(app, stage, volume, out)
            print("  ✅ 已打包（无自定义排布）")

        run(["hdiutil", "verify", out])
        print("  ✅ 校验通过")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
        subprocess.run(["hdiutil", "detach", f"/Volumes/{volume}", "-force"],
                       capture_output=True)

    size = os.path.getsize(out) / 1024 / 1024
    print(f"\n🎉 完成：{out}（{size:.1f} MB，卷名「{volume}」）")


if __name__ == "__main__":
    main()
