#!/usr/bin/env python3
"""逐帧量 `SegmentedControl` 选中 thumb 的横向位置，判它是**滑过去**还是**snap 过去**。

用法：
    python3 measure-thumb.py '<glob>' --y0 N --y1 N [--x0 N] [--x1 N]
                             [--width N] [--polarity darker|brighter|auto]
依赖 numpy + Pillow。

## 判据形态：模板相关，不是阈值分割

早先那一版按「亮度低于某阈值的连续段」找 thumb，**三个方向都会错**，逐条实测过：
- **极性是会翻的**。iOS 默认的 `GlassSegmentedControlStyle` 走原生 `UISegmentedControl`，
  thumb **比轨道暗**（浅色实测 231 vs 251）；`PlainSegmentedControlStyle` 走 SwiftUI 回退，
  thumb 是 `surfaceCanvasSubtle`（白 255）、**比轨道亮**（实测 255 vs 228）。
  阈值法在极性翻转时**不报错**，会从「轨道减 thumb」剩下的那块里挑一段，给出一个假坐标。
- **非选中的文字会被并进 thumb 段**（它本就低于阈值），中段坐标带 ±40 px 的系统偏差。
- **阈值贴太紧会丢帧**，看上去像「thumb 消失了」。

⇒ 改成滑动一个 `width` 宽的窗口做**模板相关**：`score(x) = sign * (窗口内均值 - 窗口外均值)`，
取 `score` 最大的位置。它对文字不敏感（文字只占窗口的一小部分）、对整体明暗漂移免疫
（比的是内外差），而且**始终给得出一个 `score`**——`score` 太低就判「量不到」而不是硬给坐标。

## 四条 fail-closed

1. `--polarity auto` 在首帧两个方向各试一次，取 `score` 大的，**打印选了哪个及两个分数**；
   胜者不足败者 `POLARITY_MARGIN` 倍时**中止**。
   ⚠️⚠️ **选错极性不会被 `MIN_CONTRAST` 挡下** —— 实测 `--polarity darker` 跑在
   thumb 偏亮的那条路上，score 9.5–11.3（阈值的 2.5 倍），给出一条**像模像样的假轨迹**。
   两个方向的分数**无论 auto 还是显式都会打印**，**看到打印再往下读**。
   ⚠️⚠️ **胜负比那道门槛只在 auto 下生效** —— 显式传 `--polarity` 会跳过它
   （只在你指定的是败者时打一条警告）。实测显式指定错误极性能得到一条 21 帧的假滑动。
   ⚠️ auto 只看**首帧**：首帧若不代表稳态（启动过渡、正在滑到一半），全程会算错。
2. `score < MIN_CONTRAST` 的帧判「量不到」，不进轨迹。
3. **横向行程过小时判「未观察到切换」，不判 snap** —— 窗口选错、点击落空、
   Reduce Motion 打开都会得到零行程，把它们并进 snap 是把三种情形读成同一个结论。
4. `--width` 与裁剪宽度的比例、以及 argmax 是否被钳在裁剪区边界，都要检。
   ⚠️ 实测 `--width` 给成 900（裁剪宽 1026）会产出**假 snap**——正是本判据要排除的那个结论；
   给成 600 会产出方向反转的轨迹。⇒ `width > (x1-x0)/2` 直接拒绝，
   argmax 落在边界的帧逐帧打 `钳`，**只要有帧被钳就警告**（警告文本里再区分「两端是否都被钳」）。

⚠️ **它判「有没有中间位置」，不判「时长对不对」**：`easeInOut` 尾巴很长，末段每帧只挪
1–2 px，拿它钉时长会得到一个不稳的数。
⚠️ **「0 个中间位置 = snap」的前提是采样间隔远小于动画时长**（本仓那次是 2–30 ms vs 180 ms）。
低帧率录屏或 Reduce Motion 下会假阳性。
⚠️ **它判的是「中心挪了」，不是「平移」**：合成实测，一个「从 A 拉长到覆盖 A..B 再收缩到 B」
的伸缩式过渡会被读成滑动（中间 5 帧）。对 `#233` 无害（那条路要么滑要么 snap），但别外推。
⚠️ **交叉淡变会被报成 snap，不是「识别出淡变」**：合成实测中心一帧不落地跳过去。
本判据只保证**不把淡变误读成滑动**。
"""
import sys
import glob
import os
import argparse

import numpy as np
from PIL import Image

MIN_CONTRAST = 4.0        # score 低于此判「量不到」
MIDDLE_MARGIN = 0.15      # 距两端 15% 行程以内的采样不算「中间位置」
# 1.5：正当录制实测胜负比 1.84（plain）/ 1.81（原生），错误裁剪（放宽到整屏）1.33，取中。
# ⚠️ 只有 3 个样本；正当输入若只有 1.4× 会被误中止（失效方向向红，可接受），
# 错误裁剪若到 1.6× 会被放行。
POLARITY_MARGIN = 1.5


def profile(path, y0, y1, x0, x1):
    a = np.asarray(Image.open(path).convert("L"), dtype=np.float64)
    return a[y0:y1, x0:x1].mean(axis=0)


def locate(p, width, sign):
    """滑窗模板相关。返回 (窗口中心, score, 是否钳在裁剪区边界)。"""
    n = len(p)
    if width >= n:
        return None
    csum = np.concatenate([[0.0], np.cumsum(p)])
    total = csum[-1]
    inside = (csum[width:] - csum[:-width]) / width
    outside = (total - (csum[width:] - csum[:-width])) / (n - width)
    score = sign * (inside - outside)
    i = int(np.argmax(score))
    return i + width / 2, float(score[i]), i == 0 or i == len(score) - 1


def main(a):
    files = sorted(glob.glob(a.pattern))
    if not files:
        sys.exit(f"没有匹配到帧：{a.pattern}")
    crop = a.x1 - a.x0
    if a.width > crop / 2:
        sys.exit(f"--width {a.width} 超过裁剪宽 {crop} 的一半 —— 窗口会被钳在两端，"
                 f"实测这种设置会产出**假 snap**。把 --x0/--x1 收到控件上，或改小 --width。")
    # ⚠️ 两个方向的分数**无论如何都算、都打印** —— 早先只在 auto 分支里算，于是显式传
    # --polarity 就绕过了全部防线，实测能得到一条 21 帧的假滑动而不留任何痕迹。
    p0 = profile(files[0], a.y0, a.y1, a.x0, a.x1)
    cands = {s: locate(p0, a.width, s)[1] for s in (-1, 1)}
    asked = {"darker": -1, "brighter": 1}.get(a.polarity, 0)
    auto = max(cands, key=lambda s: cands[s])
    sign = asked or auto
    name = lambda s: "thumb 比轨道亮" if s > 0 else "thumb 比轨道暗"
    print(f"首帧极性分数：亮 {cands[1]:.1f} / 暗 {cands[-1]:.1f} ⇒ 用「{name(sign)}」"
          f"（{'auto' if not asked else '你指定的'}）")
    if not asked:
        win, lose = cands[auto], cands[-auto]
        if lose > 0 and win < lose * POLARITY_MARGIN:
            sys.exit(f"极性判不开（要求胜者 ≥ {POLARITY_MARGIN}×）。首帧可能不代表稳态；"
                     f"确认后用 --polarity 显式指定 —— ⚠️ 显式指定会跳过这道门槛。")
    elif cands[sign] < cands[-sign]:
        print(f"⚠️⚠️ 你指定的极性在首帧上**是败者**（{cands[sign]:.1f} < {cands[-sign]:.1f}）。"
              f"实测极性选错会给出一条像模像样的假轨迹，**下面的结果很可能是假的**。")
    print()

    print(f"{'frame':<22}{'thumb 中心 x':>12}{'score':>8}  钳")
    seen = []
    clamped = 0
    for f in files:
        p = profile(f, a.y0, a.y1, a.x0, a.x1)
        r = locate(p, a.width, sign)
        if r is None or r[1] < MIN_CONTRAST:
            print(f"{os.path.basename(f):<22}{'量不到':>12}{(r[1] if r else 0):>8.1f}")
            continue
        cx, score, edge = r
        clamped += edge
        seen.append(cx + a.x0)
        print(f"{os.path.basename(f):<22}{cx + a.x0:>12.0f}{score:>8.1f}  {'钳' if edge else ''}")

    if not seen:
        print(f"\n没有任何一帧的 score 达到 {MIN_CONTRAST} —— 窗口 / 极性 / 宽度选错了")
        return
    lo, hi = min(seen), max(seen)
    span = hi - lo
    if span < a.width * 0.1:
        print(f"\n横向行程只有 {span:.0f} px —— **未观察到切换**"
              f"（窗口选错 / 点击落空 / Reduce Motion 开着都会这样）。**不是 snap 的证据。**")
        return
    middles = [c for c in seen if lo + span * MIDDLE_MARGIN < c < hi - span * MIDDLE_MARGIN]
    distinct = len(set(round(c) for c in middles))
    positions = sorted(set(round(c) for c in middles))
    print(f"\n横向行程 {span:.0f} px（{lo:.0f} → {hi:.0f}），"
          f"其中**中间位置** {len(middles)} 帧 / **{distinct} 个不同位置**：{positions}")
    print("⇒ 0 个不同的中间位置 = snap；多个 = 在滑。")
    print("⚠️ 帧数会被录屏过采样抬高（同一位置连着好几帧），承重的是**不同位置**那个数。")
    if clamped:
        print(f"⚠️ 有 {clamped} 帧的窗口被**钳在裁剪区边界** —— 这些帧的坐标是裁剪边界值、"
              f"不是 thumb 真实位置。若行程两端都落在被钳的帧上，那个行程数就是"
              f"「裁剪宽 − width」这个结构常数，不承重。")
    print("⚠️ 交叉淡变会被本判据报成 **snap**（合成实测中心一帧不落地跳过去）"
          "—— 本判据只保证不把淡变误读成滑动，不保证能识别出淡变。")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("pattern")
    ap.add_argument("--y0", type=int, required=True)
    ap.add_argument("--y1", type=int, required=True)
    ap.add_argument("--x0", type=int, default=90)
    ap.add_argument("--x1", type=int, default=1116)
    ap.add_argument("--width", type=int, default=342, help="thumb 宽度（px）；114 pt @3x")
    ap.add_argument("--polarity", choices=["darker", "brighter", "auto"], default="auto")
    main(ap.parse_args())
