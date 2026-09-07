#!/usr/bin/env python3
"""从 Sources/ 派生设计系统摘要（docs/design-digest.md）。

正文全部机器派生；手写部分只有 header 文件，原样前置。
每一节都有基数下界，任一节空掉或缩水即非零退出——空节在退出码上等同于通过，
是本仓反复吃过的那类假绿。
"""
import argparse
import glob
import os
import re
import sys

TARGETS = ["CoreDesign", "CoreDesignEffects", "CoreDesignCharts"]

# 各节基数下界。缩水即判红——数字随源码增长可上调，下调必须在 PR 里说明理由。
FLOORS = {
    "spacing": 11, "radius": 5, "border": 5, "typography": 12,
    "elevation": 4, "controlsize": 5,
    "colors": 115, "components": 89, "enums": 30, "viewext": 31,
}


def read(path):
    with open(path, encoding="utf-8") as handle:
        return handle.read()


def doc_above(lines, index):
    out = []
    cursor = index - 1
    while cursor >= 0 and lines[cursor].strip().startswith("///"):
        out.insert(0, lines[cursor].strip()[3:].strip())
        cursor -= 1
    text = " ".join(out)
    text = re.sub(r"\*\*材质层\*\*.*?\.\s*", "", text)
    return text.strip()


def first_sentence(text, limit=170):
    if not text:
        return ""
    cut = re.split(r"(?<=[。！？])", text)[0]
    return (cut if len(cut) <= limit else cut[:limit] + "…").strip()


def scalar_tokens(root, filename, enum_name):
    src = read(os.path.join(root, "Sources/CoreDesign/Tokens", filename))
    lines = src.split("\n")
    rows = []
    for index, line in enumerate(lines):
        match = re.match(
            r"\s*public\s+static\s+let\s+(\w+)\s*:\s*\w+\s*=\s*([\-\d.]+)", line
        )
        if match:
            rows.append((match.group(1), match.group(2), first_sentence(doc_above(lines, index))))
    return enum_name, rows


def typography_tokens(root):
    src = read(os.path.join(root, "Sources/CoreDesign/Tokens/CoreTypography.swift"))
    body = src.split("public enum Token")[1].split("public var textStyle")[0]
    return re.findall(r"case\s+(\w+)", body)


def elevation_specs(root):
    src = read(os.path.join(root, "Sources/CoreDesign/Tokens/CoreElevation.swift"))
    body = src.split("public static func spec(for level: Level) -> Spec")[1]
    rows = []
    for chunk in re.split(r"case\s+\.", body)[1:]:
        name = re.match(r"(\w+)", chunk).group(1)
        radius = re.search(r"radius:\s*([\d.]+)", chunk)
        y_off = re.search(r"y:\s*([\d.]+)", chunk)
        if radius and y_off:
            rows.append((name, radius.group(1), y_off.group(1)))
    return rows


def control_metrics(root):
    src = read(os.path.join(root, "Sources/CoreDesign/Tokens/CoreControlMetrics.swift"))
    table = {}
    for func in ["height", "horizontalPadding", "verticalPadding", "fontToken", "iconSize"]:
        segment = src.split(f"public static func {func}(")[1].split("\n    }")[0]
        for size, value in re.findall(r"case\s+\.(\w+):\s*(?:return\s+)?([\w.]+)", segment):
            if size == "extraLarge" or size in ("mini", "small", "regular", "large"):
                table.setdefault(size, {})[func] = value
    order = ["mini", "small", "regular", "large", "extraLarge"]
    return [(size, table[size]) for size in order if size in table]


def semantic_colors(root):
    groups = []
    skip = {"ColorGrade.swift"}
    for path in sorted(glob.glob(os.path.join(root, "Sources/CoreDesign/Colors/*.swift"))):
        base = os.path.basename(path)
        if base in skip:
            continue
        lines = read(path).split("\n")
        rows = []
        for index, line in enumerate(lines):
            match = re.match(r"\s*static\s+(?:let|var)\s+(\w+)\s*[:=]", line)
            if match and "private" not in line:
                rows.append((match.group(1), first_sentence(doc_above(lines, index), 110)))
        if rows:
            groups.append((base.replace(".swift", ""), rows))
    return groups


def target_surface(root, target):
    files = []
    for path in sorted(glob.glob(os.path.join(root, f"Sources/{target}/**/*.swift"), recursive=True)):
        lines = read(path).split("\n")
        views, enums, protocols = [], [], []
        for index, line in enumerate(lines):
            match = re.match(
                r"\s*public\s+(?:nonisolated\s+)?(struct|enum|protocol|final class)\s+(\w+)(.*)",
                line,
            )
            if not match:
                continue
            kind, name, tail = match.group(1), match.group(2), match.group(3)
            doc = first_sentence(doc_above(lines, index))
            conforms = tail.split("{")[0].strip()
            if kind == "protocol":
                protocols.append((name, doc))
            elif "View" in conforms or "Transition" in conforms or "Style" in conforms or "Layout" in conforms:
                views.append((name, conforms, doc))
            elif kind == "enum":
                cases = enum_cases(lines, index)
                if cases:
                    enums.append((name, cases, doc))
        if views or enums or protocols:
            rel = os.path.relpath(path, os.path.join(root, f"Sources/{target}"))
            files.append((rel, views, enums, protocols))
    return files


def enum_cases(lines, start):
    depth = 0
    cases = []
    for line in lines[start:]:
        depth += line.count("{") - line.count("}")
        for raw in re.findall(r"^\s*case\s+([A-Za-z_][\w]*)", line):
            cases.append(raw)
        if depth <= 0 and line.count("}"):
            break
    return cases


def view_extensions(root):
    rows = []
    for target in TARGETS:
        for path in sorted(glob.glob(os.path.join(root, f"Sources/{target}/**/*.swift"), recursive=True)):
            lines = read(path).split("\n")
            host = None
            for index, line in enumerate(lines):
                ext = re.match(r"\s*(?:public\s+)?extension\s+([\w.]+)", line)
                if ext:
                    host = ext.group(1)
                member = re.match(r"\s*(?:public\s+)?(?:nonisolated\s+)?func\s+(\w+)", line)
                if member and host in ("View", "Transition"):
                    name = member.group(1)
                    if name in ("body", "makeBody", "makeCoordinator"):
                        continue
                    rows.append((target, host, name, first_sentence(doc_above(lines, index), 110)))
    seen, out = set(), []
    for row in rows:
        key = (row[1], row[2])
        if key not in seen:
            seen.add(key)
            out.append(row)
    return out


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    repo = os.path.dirname(here)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=repo)
    parser.add_argument("--header", default=os.path.join(repo, "docs/design-digest.header.md"))
    parser.add_argument("--out", default=os.path.join(repo, "docs/design-digest.md"))
    args = parser.parse_args()
    root = os.path.abspath(args.root)

    counts = {}
    body = []
    add = body.append

    add("\n---\n\n# Token 词汇\n")
    for filename, enum_name, key in [
        ("CoreSpacing.swift", "CoreSpacing", "spacing"),
        ("CoreRadius.swift", "CoreRadius", "radius"),
        ("CoreBorderWidth.swift", "CoreBorderWidth", "border"),
    ]:
        name, rows = scalar_tokens(root, filename, enum_name)
        counts[key] = len(rows)
        add(f"## `{name}`（{len(rows)} 档）\n")
        add("| token | 值 (pt) | 用途 |")
        add("|---|---|---|")
        for token, value, doc in rows:
            add(f"| `{name}.{token}` | {value} | {doc or '—'} |")
        add("")

    typo = typography_tokens(root)
    counts["typography"] = len(typo)
    add(f"## `CoreTypography.Token`（{len(typo)} 档，经 `.coreFont(_:)` 施加）\n")
    add("每档直接对应一个 Apple 系统文本样式，字号 / 行高 / 字重 / Dynamic Type 缩放由系统决定。\n")
    add(", ".join(f"`.{t}`" for t in typo) + "\n")

    elev = elevation_specs(root)
    counts["elevation"] = len(elev)
    add(f"## `CoreElevation.Level`（{len(elev)} 档，经 `.coreShadow(_:)`）\n")
    add("| 档位 | blur radius | y 偏移 |")
    add("|---|---|---|")
    for name, radius, y_off in elev:
        add(f"| `.{name}` | {radius} | {y_off} |")
    add("")

    metrics = control_metrics(root)
    counts["controlsize"] = len(metrics)
    add(f"## `CoreControlMetrics`（按 SwiftUI `ControlSize`，{len(metrics)} 档）\n")
    add("| ControlSize | height | h-padding | v-padding | font | icon |")
    add("|---|---|---|---|---|---|")
    for size, row in metrics:
        add(
            f"| `.{size}` | {row.get('height','—')} | {row.get('horizontalPadding','—')} "
            f"| {row.get('verticalPadding','—')} | {row.get('fontToken','—')} | {row.get('iconSize','—')} |"
        )
    add("")

    add("\n---\n\n# 语义颜色（第 3 / 4 层）\n")
    add("⚠️ 第 1 层色阶（`ColorGrade` 的 17 色相 × 10 档）**有意不列入本摘要**——组件里不直接用。\n")
    total_colors = 0
    for group, rows in semantic_colors(root):
        total_colors += len(rows)
        add(f"## `{group}`（{len(rows)}）\n")
        add("| token | 说明 |")
        add("|---|---|")
        for token, doc in rows:
            add(f"| `Color.{token}` | {doc or '—'} |")
        add("")
    counts["colors"] = total_colors

    add("\n---\n\n# 组件与类型\n")
    comp_total = 0
    enum_total = 0
    for target in TARGETS:
        files = target_surface(root, target)
        add(f"## `{target}`\n")
        for rel, views, enums, protocols in files:
            if not (views or enums or protocols):
                continue
            add(f"### `{rel}`\n")
            for name, conforms, doc in views:
                comp_total += 1
                add(f"- **`{name}`** *{conforms}* — {doc or '—'}")
            for name, doc in protocols:
                add(f"- *protocol* **`{name}`** — {doc or '—'}")
            for name, cases, doc in enums:
                enum_total += 1
                add(f"- *enum* **`{name}`**: " + ", ".join(f"`.{c}`" for c in cases))
            add("")
    counts["components"] = comp_total
    counts["enums"] = enum_total

    exts = view_extensions(root)
    counts["viewext"] = len(exts)
    add("\n---\n\n# Modifier / Transition 入口点\n")
    add(f"共 {len(exts)} 个（按 `Host.member` 去重，含参重载算一条）。\n")
    add("| target | 入口 | 说明 |")
    add("|---|---|---|")
    for target, host, name, doc in exts:
        add(f"| `{target}` | `.{name}` on `{host}` | {doc or '—'} |")
    add("")

    add("\n---\n\n# 生成基数\n")
    add("| 节 | 计数 | 下界 |")
    add("|---|---|---|")
    for key, floor in FLOORS.items():
        add(f"| {key} | {counts.get(key, 0)} | {floor} |")
    add("")

    failed = [
        f"{key}: {counts.get(key, 0)} < {floor}"
        for key, floor in FLOORS.items()
        if counts.get(key, 0) < floor
    ]
    header = read(os.path.abspath(args.header)).rstrip() + "\n"
    with open(os.path.abspath(args.out), "w", encoding="utf-8") as handle:
        handle.write(header + "\n".join(body) + "\n")

    if failed:
        print("FAIL 基数缩水：", "; ".join(failed), file=sys.stderr)
        return 1
    print("OK", {k: counts.get(k, 0) for k in FLOORS})
    return 0


if __name__ == "__main__":
    sys.exit(main())
