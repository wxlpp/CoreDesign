#!/usr/bin/env python3
"""逐帧量目的地那个饱和蓝图标（`photo.fill` + `.tint`）的质心与包围盒。

用法：`python3 measure.py '<glob>' [visible_min]`（依赖 numpy + Pillow）。

⚠️ 本脚本的三个常数**只对 `#277` 那组录制成立**，不是通用门槛：
- 掩码 `b > 150 and b - r > 70 and b - g > 50` 绑死在那个 tint 蓝上；
- `STATUS_BAR_ROWS = 140` 绑死在 @3x 的 1206×2622 上；
- `VISIBLE_MIN` 默认 5000 ≈ 该图标终态命中数 26709 的 19%，用来把「淡入中的鬼影帧」
  （实测出现过 n = 102、包围盒完全不稳）挡在外面。它必须成文，否则表按文档复现不出来。
换设备缩放、换组件、换 tint 都要重新定这三个数。

⚠️ 掩码宽松到能命中「不该命中的东西」：`#277` 第一次录对照用的是 RadarChart 详情页，
本以为那页没有饱和蓝，实测 **85 帧过阈值**（`n ≈ 6700`），命中的是雷达多边形的蓝紫描边
——包围盒 ≈ 307×1214 横跨两块预览、密度 0.018。⇒ 判「这一段能不能用」要看**密度与包围盒**，
不能只看 `n > 0`。
"""
import sys
import glob
import os

import numpy as np
from PIL import Image

DEFAULT_VISIBLE_MIN = 5000
STATUS_BAR_ROWS = 140


def stats(path):
    a = np.asarray(Image.open(path).convert("RGB"), dtype=np.int16)
    r, g, b = a[:, :, 0], a[:, :, 1], a[:, :, 2]
    m = (b > 150) & (b - r > 70) & (b - g > 50)
    m[:STATUS_BAR_ROWS, :] = False
    n = int(m.sum())
    if n == 0:
        return n, None
    ys, xs = np.nonzero(m)
    w = int(xs.max() - xs.min() + 1)
    h = int(ys.max() - ys.min() + 1)
    return n, dict(cx=float(xs.mean()), cy=float(ys.mean()), w=w, h=h,
                   x0=int(xs.min()), x1=int(xs.max()),
                   y0=int(ys.min()), y1=int(ys.max()),
                   density=n / (w * h))


def main(pattern, visible_min):
    first_visible = None
    print(f"{'frame':<22}{'n':>7}{'cx':>7}{'cy':>7}{'w':>5}{'h':>5}{'密度':>8}  可见")
    for f in sorted(glob.glob(pattern)):
        n, s = stats(f)
        if s is None:
            print(f"{os.path.basename(f):<22}{n:>7}")
            continue
        visible = n >= visible_min
        if visible and first_visible is None:
            first_visible = (os.path.basename(f), s)
        print(f"{os.path.basename(f):<22}{n:>7}{s['cx']:>7.0f}{s['cy']:>7.0f}"
              f"{s['w']:>5}{s['h']:>5}{s['density']:>8.3f}  {'✓' if visible else '·'}")
    if first_visible:
        name, s = first_visible
        print(f"\n首个可见帧（n >= {visible_min}）：{name}  "
              f"cy={s['cy']:.0f} w={s['w']} h={s['h']} 密度={s['density']:.2f}")
    else:
        print(f"\n没有任何一帧命中 n >= {visible_min} —— 掩码或窗口选错了")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_VISIBLE_MIN)
