#!/usr/bin/env python3
"""重生成 docs/issues/295-network-graph-before-after.png。

⚠️ 存在的理由：上一版图由一次性命令产出、仓内无脚本 ⇒ 无法重生成也无法审计
（终审 S-3）。标签一律用 ASCII —— PIL 默认位图字体没有中文字形，中文会渲成豆腐块。

用法：先用 `SIMCTL_CHILD_PREVIEW_COMPONENT_ID=chart-network-graph` 在模拟器上
分别对「向心力=0」与「出厂默认」各截一张，然后
    python3 scripts/render-issue-295-figure.py <before.png> <after.png>
"""
import sys
from PIL import Image, ImageDraw

before, after = sys.argv[1], sys.argv[2]
out = Image.new("RGB", (2 * 410, 470), (210, 210, 212))
draw = ImageDraw.Draw(out)
for i, (path, label) in enumerate(((before, "BEFORE  pinned 14/14"), (after, "AFTER  pinned 0/14"))):
    im = Image.open(path).convert("RGB")
    w, h = im.size
    crop = im.crop((0, int(h * 0.31), w, int(h * 0.68)))
    crop.thumbnail((400, 440))
    out.paste(crop, (i * 410 + 5, 26))
    draw.text((i * 410 + 8, 8), label, fill=(10, 10, 10))
out.save("docs/issues/295-network-graph-before-after.png")
print("written docs/issues/295-network-graph-before-after.png")
