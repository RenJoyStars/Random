#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Random 课堂抽号器 · 图标生成器
------------------------------------------------------------
按 Big Sur 之后的 macOS 图标网格绘制（1024 画布 / 824 圆角方块 / 内缩 100），
全部程序化生成，改参数即可重出全套尺寸。

用法：
    python3 Tools/make-icon.py                # 出两种方案到 build/icon/
    python3 Tools/make-icon.py --variant b    # 只出方案 B
    python3 Tools/make-icon.py --install      # 定稿写入 Assets.xcassets
"""

import os
import sys
import math
import argparse
from PIL import Image, ImageDraw, ImageFilter

# ---------------------------------------------------------------- 基本参数
MASTER = 1024          # 母版边长
SS = 3                 # 超采样倍数（3072 下采样，边缘更干净）
N = MASTER * SS
INSET = 100            # macOS 图标网格：四周留白
CORNER = 186           # 圆角半径

# 配色预设：背景三档亮度，越往后越亮
BG_PRESETS = {
    # 1.0 原版（现用）：对角渐变的亮蓝，五个白点
    "v10":  ((70, 127, 252), (48, 98, 236),  (26, 69, 220)),
    # 3.0 深色系：底部压到近黑，骰子像浮在夜色里
    "v30":  ((56, 70, 143),  (30, 39, 87),   (11, 15, 36)),
    # 3.1 试过的中间调：整体抬亮，Dock 里偏"发飘"，已退回 v30
    "mid":  ((74, 122, 232), (44, 82, 194),  (26, 44, 122)),
    # 3.1 试过的亮调
    "light":((96, 146, 246), (58, 100, 212), (32, 56, 148)),
}
C_TOP    = (56, 70, 143)
C_MID    = (30, 39, 87)
C_BOTTOM = (11, 15, 36)
C_GLOW   = (10, 132, 255)    # #0A84FF 界面强调色
C_WHITE  = (242, 247, 255)   # 骰点白
C_NAVY   = (20, 28, 66)      # 玻璃骰子上的点数


# ---------------------------------------------------------------- 工具函数
def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def gradient(size, stops, angle_deg=135.0):
    """生成对角线性渐变。低分辨率算完再放大（渐变本身平滑，放大无损失）。"""
    lo = 256
    img = Image.new("RGB", (lo, lo))
    px = img.load()
    rad = math.radians(angle_deg)
    dx, dy = math.cos(rad), math.sin(rad)
    # 投影范围归一化
    vals = [x * dx + y * dy for x in (0, lo) for y in (0, lo)]
    vmin, vmax = min(vals), max(vals)
    stops = sorted(stops, key=lambda s: s[0])
    for y in range(lo):
        for x in range(lo):
            v = (x * dx + y * dy - vmin) / (vmax - vmin)
            for i in range(len(stops) - 1):
                p0, c0 = stops[i]
                p1, c1 = stops[i + 1]
                if p0 <= v <= p1 or i == len(stops) - 2:
                    t = 0 if p1 == p0 else max(0.0, min(1.0, (v - p0) / (p1 - p0)))
                    px[x, y] = lerp(c0, c1, t)
                    break
    return img.resize((size, size), Image.BICUBIC)


def radial_alpha(size, center, radius, inner=255, outer=0, gamma=1.0, steps=160):
    """径向遮罩：中心 inner → 半径外 outer。""" 
    img = Image.new("L", (size, size), outer)
    d = ImageDraw.Draw(img)
    cx, cy = center
    for i in range(steps, 0, -1):
        t = i / steps
        r = radius * t
        a = int(outer + (inner - outer) * ((1.0 - t) ** gamma))
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=a)
    return img


def squircle_mask(size, inset, corner):
    """圆角方块遮罩（超采样绘制，收边干净）。"""
    m = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(m)
    r = corner
    d.rounded_rectangle([inset, inset, size - inset, size - inset], radius=r, fill=255)
    return m


def compose(base, layer, mask):
    """把 layer 按 mask 贴到 base 上。"""
    return Image.composite(layer, base, mask)


def shadow_from(mask, blur, offset, opacity):
    """由遮罩生成投影图层（RGBA）。"""
    s = mask.filter(ImageFilter.GaussianBlur(blur))
    if offset != (0, 0):
        s = ImageChops_offset(s, offset)
    rgba = Image.new("RGBA", mask.size, (0, 0, 0, 0))
    black = Image.new("RGBA", mask.size, (0, 0, 0, int(255 * opacity)))
    rgba.paste(black, (0, 0), s)
    return rgba


def ImageChops_offset(img, dx, dy):
    from PIL import ImageChops
    return ImageChops.offset(img, dx, dy)


# ---------------------------------------------------------------- 骰子几何
def die_points(cx, cy, tile, angle_deg, spread, radius):
    """返回 (骰子方块多边形, 五个点的中心坐标)。"""
    a = math.radians(angle_deg)
    ca, sa = math.cos(a), math.sin(a)

    def rot(px, py):
        return (cx + px * ca - py * sa, cy + px * sa + py * ca)

    half = tile / 2.0
    poly = [rot(-half, -half), rot(half, -half), rot(half, half), rot(-half, half)]
    offs = [(-spread, -spread), (spread, -spread), (0, 0), (-spread, spread), (spread, spread)]
    pips = [rot(ox, oy) for ox, oy in offs]
    return poly, pips


_PIP_CACHE = {}


def flat_glass_pip(size=512, edge="clean"):
    """平底白玻璃珠（Liquid Glass 语言）。

    中心是**平的**：纯白、没有渐变、没有高光点 —— 只要中心出现一点点径向渐变
    或一颗小高光，整颗就变成"眼球 / 塑料球"，不是玻璃片。

    玻璃感全部集中在边缘一圈：
      · 内侧一圈淡蓝折射环 —— 底板的蓝被玻璃"吸"进来一点，显出厚度；
      · 紧贴外缘一道亮白 —— 玻璃边界的镜面反光；
      · 最外缘逐渐透明 —— 让边缘和底板化在一起，而不是贴上去的圆。

    尺寸和位置按 1.0 的构图：五点铺得很开，边距只留两成。
    """
    S = size
    R = S / 2.0 - 1.0
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    px = img.load()

    EDGE = 0.855            # 只有外侧 14.5% 是玻璃带
    WHITE = (255, 255, 255)
    if edge == "clean":
        # 纯白 + alpha：不给边缘上色，让"透过去"的蓝自己形成玻璃感。
        # 曲线是一条 W：白心 1.0 → 中段 0.5（透出底板）→ 最外沿回到 0.95（边界反光）。
        for y in range(S):
            for x in range(S):
                u = (x - S / 2.0 + 0.5) / R
                v = (y - S / 2.0 + 0.5) / R
                d = math.hypot(u, v)
                if d > 1.0 + 2.0 / R:
                    continue
                a = (1.0 - d) * R + 0.5
                if a <= 0:
                    continue
                a = min(1.0, a)
                dd = min(d, 1.0)
                if dd <= 0.86:
                    px[x, y] = (255, 255, 255, int(a * 255 + 0.5))
                else:
                    t = (dd - 0.86) / 0.14
                    if t < 0.72:
                        k = t / 0.72
                        aa = 1.0 - 0.52 * (k ** 0.85)
                        # 透蓝时颜色稍微压冷，免得半透明白在蓝上发灰
                        col = lerp((255, 255, 255), (238, 246, 255), k * 0.6)
                    else:
                        k = (t - 0.72) / 0.28
                        aa = 0.48 + 0.48 * (k ** 0.55)
                        col = lerp((238, 246, 255), (255, 255, 255), k)
                    px[x, y] = (int(col[0]), int(col[1]), int(col[2]), int(a * aa * 255 + 0.5))
        return img

    if edge == "strong":
        # 强折射：暗环更深、亮边更锐 —— 更像一块有厚度的玻璃片
        TINT = (146, 190, 250)
        TINT_AMT, HI_POS, HI_SIG, HI_AMP, ALPHA_DROP = 0.92, 0.94, 0.105, 1.45, 0.58
    else:
        TINT = (176, 210, 255)  # 折射进来的蓝
        TINT_AMT, HI_POS, HI_SIG, HI_AMP, ALPHA_DROP = 0.82, 0.90, 0.14, 1.25, 0.52

    for y in range(S):
        for x in range(S):
            u = (x - S / 2.0 + 0.5) / R
            v = (y - S / 2.0 + 0.5) / R
            d = math.hypot(u, v)
            if d > 1.0 + 2.0 / R:
                continue
            a = (1.0 - d) * R + 0.5
            if a <= 0:
                continue
            a = min(1.0, a)
            dd = min(d, 1.0)

            c = WHITE
            if dd > EDGE:
                t = (dd - EDGE) / (1.0 - EDGE)      # 0 = 玻璃带内沿, 1 = 最外缘

                # 折射环：中段最浓，把底板的蓝吸进来
                tint_amt = math.exp(-(((t - 0.34) / 0.30) ** 2)) * TINT_AMT
                c = lerp(WHITE, TINT, min(1.0, tint_amt))

                # 边缘镜面反光：紧贴外沿的一圈亮白
                hi = math.exp(-(((t - HI_POS) / HI_SIG) ** 2)) * HI_AMP
                c = lerp(c, WHITE, min(1.0, hi))

                # 最外缘化进底板
                a *= 1.0 - ALPHA_DROP * max(0.0, (t - 0.48) / 0.52) ** 1.3

            px[x, y] = (int(round(c[0])), int(round(c[1])), int(round(c[2])),
                        int(a * 255 + 0.5))
    return img


def glass_pip_sprite(size=512, mode="dark"):
    """一颗玻璃骰点的贴图（RGBA，边缘抗锯齿）。

    玻璃珠的立体感靠四层光，缺一层就变成"贴上去的深色圆点"：
      1. 主体：中心透光偏亮 → 边缘压暗；
      2. 菲涅尔暗环：距边缘 30% 起渐暗，模拟玻璃折射把光"折"出去；
      3. 左上锐点高光 + 一层宽柔高光（玻璃表面的镜面反射）；
      4. 右下折射亮斑：光穿过玻璃打到白色骰面上又反上来。
    最后再叠一道极细的外圈亮边，这是玻璃和塑料最容易区分的地方。
    """
    key = (size, mode)
    if key in _PIP_CACHE:
        return _PIP_CACHE[key]

    S = size
    R = S / 2.0 - 1.0
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    px = img.load()

    if mode == "light":
        # 亮蓝底上的白玻璃珠：主体是白的，但中心透出一点蓝（玻璃才"透"），
        # 边缘压一圈更深的蓝做折射暗环 —— 这一圈是"玻璃"和"白色圆点"的分水岭。
        C_DEEP = (16, 62, 186)      # 边缘：折射压深
        C_MIDC = (150, 192, 255)    # 中段：透出的蓝
        C_LIFT = (232, 243, 255)    # 中心：几乎白
        C_COOL = (255, 255, 255)    # 高光：纯白
    else:
        C_DEEP = (7, 11, 30)        # 边缘：近黑，偏靛
        C_MIDC = (32, 45, 90)       # 中段
        C_LIFT = (104, 130, 200)    # 中心透光
        C_COOL = (212, 232, 255)    # 冷高光

    for y in range(S):
        for x in range(S):
            u = (x - S / 2.0 + 0.5) / R
            v = (y - S / 2.0 + 0.5) / R
            d = math.hypot(u, v)
            if d > 1.0 + 2.0 / R:
                continue
            a = (1.0 - d) * R + 0.5
            if a <= 0:
                continue
            a = min(1.0, a)
            dd = min(d, 1.0)

            # 1) 主体：中心透光，向边缘沉下去
            t = (1.0 - dd) ** 2.1
            c = lerp(C_DEEP, C_LIFT, t)
            c = lerp(c, C_MIDC, (1.0 - dd) ** 0.55 * 0.42)

            # 2) 菲涅尔暗环
            #    亮底上收窄到外侧 20%（宽了会像描了一圈黑边），但压得更实。
            rim_start = 0.80 if mode == "light" else 0.70
            rim = max(0.0, (dd - rim_start) / (1.0 - rim_start)) ** 1.5
            c = lerp(c, C_DEEP, rim * (0.70 if mode == "light" else 0.60))

            # 3a) 宽柔高光（左上）
            sheen = math.exp(-(((u + 0.30) ** 2 + (v + 0.35) ** 2) / (2 * 0.30 ** 2))) * 0.62
            c = lerp(c, C_COOL, min(1.0, sheen))

            # 3b) 锐点高光
            glint = math.exp(-(((u + 0.28) ** 2 + (v + 0.31) ** 2) / (2 * 0.078 ** 2)))
            c = lerp(c, (255, 255, 255), min(1.0, glint))

            # 4) 右下折射亮斑
            bounce = math.exp(-(((u - 0.19) ** 2 + (v - 0.45) ** 2) / (2 * 0.16 ** 2))) * 0.30
            c = lerp(c, (166, 202, 255), bounce)

            # 5) 外圈菲涅尔亮边
            ring = math.exp(-(((dd - 0.935) / 0.040) ** 2)) * 0.26
            c = lerp(c, (198, 222, 255), ring)

            px[x, y] = c + (int(a * 255 + 0.5),)

    _PIP_CACHE[key] = img
    return img


def _die_layer(tile, pip_r, spread, face_hi, face_lo, pip_in, pip_out, radius_ratio=0.17):
    """在正立的 N×N 图层上画一颗骰子（不旋转），返回 RGBA 图层。"""
    L = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    cx = cy = N / 2.0
    half = tile / 2.0
    rad = tile * radius_ratio
    box = [cx - half, cy - half, cx + half, cy + half]

    # 厚度：往下错 3.2% 的暗面，制造"有实体"的侧面
    thick = int(tile * 0.032)
    ImageDraw.Draw(L).rounded_rectangle(
        [box[0], box[1] + thick, box[2], box[3] + thick],
        radius=rad, fill=(84, 99, 155, 205))

    # 正面：竖向渐变 + 圆角遮罩
    mask = Image.new("L", (N, N), 0)
    ImageDraw.Draw(mask).rounded_rectangle(box, radius=rad, fill=255)
    face = gradient(N, [(0.0, face_hi), (0.46, (240, 246, 255)), (1.0, face_lo)],
                    angle_deg=97.0).convert("RGBA")
    face.putalpha(mask)
    L.alpha_composite(face)

    # 底边内侧的暗带：玻璃厚度感
    inner = Image.new("L", (N, N), 0)
    idr = ImageDraw.Draw(inner)
    idr.rounded_rectangle([box[0], box[1] + tile * 0.30, box[2], box[3] + tile * 0.35],
                          radius=rad, fill=170)
    inner = inner.filter(ImageFilter.GaussianBlur(tile * 0.075))
    inner = Image.composite(inner, Image.new("L", (N, N), 0), mask)
    L.paste(Image.new("RGBA", (N, N), (74, 96, 156, 255)), (0, 0),
            inner.point(lambda v: int(v * 0.40)))

    # 骰点位置（经典五点）
    offs = [(-spread, -spread), (spread, -spread), (0, 0), (-spread, spread), (spread, spread)]
    pips = [(cx + ox, cy + oy) for ox, oy in offs]

    # 接触阴影：极淡，只给玻璃珠一点"压住骰面"的重量，不能画成投影，
    # 否则会变回"钻进去的孔"。
    dsh = Image.new("L", (N, N), 0)
    dsd = ImageDraw.Draw(dsh)
    for (x, y) in pips:
        dsd.ellipse([x - pip_r * 1.08, y - pip_r * 0.98 + pip_r * 0.10,
                     x + pip_r * 1.08, y + pip_r * 1.08 + pip_r * 0.10], fill=255)
    dsh = dsh.filter(ImageFilter.GaussianBlur(pip_r * 0.22))
    dsh = Image.composite(dsh, Image.new("L", (N, N), 0), mask)
    L.paste(Image.new("RGBA", (N, N), (44, 62, 118, 255)), (0, 0),
            dsh.point(lambda v: int(v * 0.26)))

    # 骰点本体：玻璃珠贴图按半径缩放后贴上去
    sprite = glass_pip_sprite(512)
    for (x, y) in pips:
        s = int(round(pip_r * 2)) + 2
        bead = sprite.resize((s, s), Image.LANCZOS)
        L.alpha_composite(bead, (int(round(x - s / 2.0)), int(round(y - s / 2.0))))

    # 边缘高光：只描上、左两条边（光从左上来）
    rim = Image.new("L", (N, N), 0)
    rd = ImageDraw.Draw(rim)
    rd.arc([box[0], box[1], box[2], box[3]], 178, 272, fill=255, width=int(tile * 0.007))
    rim = rim.filter(ImageFilter.GaussianBlur(tile * 0.006))
    rim = Image.composite(rim, Image.new("L", (N, N), 0), mask)
    L.paste(Image.new("RGBA", (N, N), (255, 255, 255, 255)), (0, 0),
            rim.point(lambda v: int(v * 0.62)))
    return L


def draw_die(canvas, variant, edge="clean"):
    """variant a：极简骰点；variant b：倾斜玻璃骰子。"""
    if variant == "a":
        """1.0 的构图：亮蓝底 + 五点，点做大（边距只留两成）。
        3.1 只改一处 —— 白点换成玻璃珠。"""
        cx = cy = N / 2.0
        spread, radius = 171 * SS, 71 * SS
        offs = [(-spread, -spread), (spread, -spread), (0, 0), (-spread, spread), (spread, spread)]
        pips = [(cx + ox, cy + oy) for ox, oy in offs]

        # 珠子底下的柔影：给它一点"压在底板上"的重量。
        # 没有这层，玻璃珠看着像贴纸；有了这层，才像嵌在蓝玻璃里的珠子。
        sh = Image.new("L", (N, N), 0)
        sd = ImageDraw.Draw(sh)
        for (x, y) in pips:
            sd.ellipse([x - radius * 1.02, y - radius * 0.90 + radius * 0.14,
                        x + radius * 1.02, y + radius * 1.10 + radius * 0.14], fill=255)
        sh = sh.filter(ImageFilter.GaussianBlur(radius * 0.30))
        canvas.paste(Image.new("RGBA", (N, N), (18, 56, 168, 255)), (0, 0),
                     sh.point(lambda v: int(v * 0.32)))

        sprite = flat_glass_pip(512, edge)
        for (x, y) in pips:
            s = int(round(radius * 2)) + 2
            bead = sprite.resize((s, s), Image.LANCZOS)
            canvas.alpha_composite(bead, (int(round(x - s / 2.0)), int(round(y - s / 2.0))))
        return canvas

    # ---------------- 方案 B：玻璃骰子
    tile = 446 * SS
    angle = -8.0
    die = _die_layer(tile,
                     pip_r=46 * SS, spread=108 * SS,
                     face_hi=(255, 255, 255, 250), face_lo=(228, 237, 255, 242),
                     pip_in=(13, 19, 45), pip_out=(46, 58, 104))
    die = die.rotate(angle, resample=Image.BICUBIC, center=(N / 2, N / 2))
    die = ImageChops_offset(die, 0, -8 * SS)

    # 投影（屏幕空间，朝右下）
    alpha = die.split()[3]
    sh = alpha.filter(ImageFilter.GaussianBlur(tile * 0.055))
    sh = ImageChops_offset(sh, int(tile * 0.02), int(tile * 0.075))
    canvas.paste(Image.new("RGBA", (N, N), (4, 8, 22, 255)), (0, 0),
                 sh.point(lambda v: int(v * 0.62)))
    canvas.alpha_composite(die)
    return canvas


# ---------------------------------------------------------------- 主绘制
def render(variant="a", size=MASTER, bg="v10", edge="clean"):
    top_c, mid_c, bot_c = BG_PRESETS[bg]
    # 底板
    base = gradient(N, [(0.0, top_c), (0.46, mid_c), (1.0, bot_c)], angle_deg=132.0).convert("RGBA")

    # 中央蓝色辉光：把视线拉向中心，也呼应界面里的强调色
    glow = radial_alpha(N, (N * 0.5, N * 0.44), N * 0.62, inner=255, outer=0, gamma=1.9)
    glow_layer = Image.new("RGBA", (N, N), C_GLOW + (0,))
    glow_layer.putalpha(glow.point(lambda v: int(v * 0.34)))
    base.alpha_composite(glow_layer)

    # 左上冷光：玻璃片受光（不用斜向高光带，避免出现"划痕感"）
    top = radial_alpha(N, (N * 0.20, N * 0.12), N * 0.70, inner=255, outer=0, gamma=2.2)
    top_layer = Image.new("RGBA", (N, N), (255, 255, 255, 0))
    top_layer.putalpha(top.point(lambda v: int(v * 0.26)))
    base.alpha_composite(top_layer)

    # 底部压暗：让 824 方块有体积
    bot = radial_alpha(N, (N * 0.5, N * 1.16), N * 0.72, inner=255, outer=0, gamma=1.6)
    bot_layer = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    bot_layer.putalpha(bot.point(lambda v: int(v * 0.32)))
    base.alpha_composite(bot_layer)

    # 符号
    base = draw_die(base, variant, edge)

    # 内描边：上沿亮、下沿暗，模拟玻璃边缘
    edge = squircle_mask(N, INSET * SS, CORNER * SS)
    inner = squircle_mask(N, INSET * SS + int(2.2 * SS), CORNER * SS - int(2.2 * SS))
    ring = Image.composite(edge, Image.new("L", (N, N), 0),
                           Image.eval(inner, lambda v: 255 - v))
    ring = ring.filter(ImageFilter.GaussianBlur(0.7 * SS))
    base.paste(Image.new("RGBA", (N, N), (255, 255, 255, 120)), (0, 0), ring)

    # 裁成圆角方块
    mask = squircle_mask(N, INSET * SS, CORNER * SS)
    out = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    out.paste(base, (0, 0), mask)

    if size != N:
        out = out.resize((size, size), Image.LANCZOS)
    return out


# ---------------------------------------------------------------- 输出
def save_set(img, outdir, tag):
    os.makedirs(outdir, exist_ok=True)
    sizes = [16, 32, 64, 128, 256, 512, 1024]
    paths = {}
    for s in sizes:
        p = os.path.join(outdir, f"icon-{s}.png")
        img.resize((s, s), Image.LANCZOS).save(p)
        paths[s] = p
    img.save(os.path.join(outdir, f"{tag}-1024.png"))
    return paths


def contact_sheet(master, path, bg=(236, 236, 240)):
    """把 16/32/64/128 排成一张对照图，检查小尺寸可读性。"""
    sizes = [16, 32, 64, 128]
    pad, gap = 24, 28
    w = pad * 2 + sum(sizes) + gap * (len(sizes) - 1)
    h = pad * 2 + 128
    sheet = Image.new("RGB", (w, h), bg)
    x = pad
    for s in sizes:
        sheet.paste(master.resize((s, s), Image.LANCZOS), (x, pad + (128 - s) // 2),
                    master.resize((s, s), Image.LANCZOS))
        x += s + gap
    sheet.save(path)
    return path


def install(master):
    root = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                        "Random", "Assets.xcassets", "AppIcon.appiconset")
    spec = {
        "icon_16x16.png": 16, "icon_16x16@2x.png": 32,
        "icon_32x32.png": 32, "icon_32x32@2x.png": 64,
        "icon_128x128.png": 128, "icon_128x128@2x.png": 256,
        "icon_256x256.png": 256, "icon_256x256@2x.png": 512,
        "icon_512x512.png": 512, "icon_512x512@2x.png": 1024,
    }
    for name, s in spec.items():
        master.resize((s, s), Image.LANCZOS).save(os.path.join(root, name))
        print(f"  ✓ {name:22s} {s}×{s}")
    # iOS 1024（无透明、无圆角）
    ios = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                       "Random", "Assets-iOS.xcassets", "AppIcon.appiconset", "icon-1024.png")
    if os.path.isdir(os.path.dirname(ios)):
        master.resize((1024, 1024), Image.LANCZOS).convert("RGB").save(ios)
        print(f"  ✓ iOS icon-1024.png")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--variant", default="a", choices=["a", "b", "ab"])
    ap.add_argument("--bg", default="v10", choices=["v10", "v30", "mid", "light"])
    ap.add_argument("--install", action="store_true")
    ap.add_argument("--edge", default="clean", choices=["soft", "strong", "clean"])
    ap.add_argument("--out", default=os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "build", "icon"))
    args = ap.parse_args()

    variants = ["a", "b"] if args.variant == "ab" else [args.variant]
    for v in variants:
        print(f"绘制方案 {v.upper()} …")
        img = render(v, bg=args.bg, edge=args.edge)
        sub = os.path.join(args.out, f"{v}-{args.bg}-{args.edge}")
        save_set(img, sub, v)
        contact_sheet(img, os.path.join(args.out, f"对比-{v}.png"))
        print(f"  → {sub}")
        if args.install and v == args.variant:
            install(img)
            print("已写入 Assets.xcassets")


if __name__ == "__main__":
    main()
