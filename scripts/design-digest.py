#!/usr/bin/env python3
"""从 Sources/ 派生设计系统摘要（docs/design-digest.md）。

条目全部机器派生；手写部分是 header 文件与本脚本内的各节段首说明，两者都按人工
评审项对待（见 docs/design-digest.header.md 顶部）。

每一节都有基数判据（当前钉法是精确值：删任何一条即判红）。空节在退出码上等同于
通过，是本仓反复吃过的那类假绿。判据不过时不写盘。
"""
import argparse
import glob
import os
import re
import sys

TARGETS = ["CoreDesign", "CoreDesignEffects", "CoreDesignCharts"]

# 当前钉法是**精确值**，不是留有余量的下界：任何删除即判红，任何新增也判红并要求
# 有人看一眼再改数。随源码变动时连同 PR 正文写明增减理由。
FLOORS = {
    "spacing": 11, "radius": 5, "border": 5, "typography": 12,
    "elevation": 4, "controlsize": 5,
    "colors": 115, "components": 90, "enums": 28, "enumcases": 102,
    "protocols": 6, "viewext": 40, "styleext": 9, "others": 29,
}

# 组件判定：conformance 列表里出现这些名字之一，或以 Style 结尾。
COMPONENT_CONFORMANCES = {"View", "Transition", "Layout", "Shape", "ViewModifier"}

DOC_RESIDUE = "⚠️ 源码缺摘要"


def read(path):
    with open(path, encoding="utf-8") as handle:
        return handle.read()


def strip_noise(line):
    """去掉行内注释与字符串字面量，供花括号计数使用。"""
    out = []
    in_string = False
    index = 0
    while index < len(line):
        char = line[index]
        if in_string:
            if char == "\\":
                index += 2
                continue
            if char == '"':
                in_string = False
            index += 1
            continue
        if char == '"':
            in_string = True
            index += 1
            continue
        if char == "/" and index + 1 < len(line) and line[index + 1] == "/":
            break
        out.append(char)
        index += 1
    return "".join(out)


def depth_delta(line):
    clean = strip_noise(line)
    return clean.count("{") - clean.count("}")


def doc_above(lines, index):
    out = []
    cursor = index - 1
    while cursor >= 0 and lines[cursor].strip().startswith("///"):
        out.insert(0, lines[cursor].strip()[3:].strip())
        cursor -= 1
    return " ".join(out).strip()


def summarise(raw, limit=170):
    """取文档注释首句。

    「材质层 / 表面角色」这两个字段**不丢**——它们正是 header 规则 3 要调用方填的
    `SurfaceKind` 语境，扔掉等于扔掉设计相关信息。剥出来当后缀，剥完真的为空才标注。
    """
    text = (raw or "").strip()
    facets = []
    for label in ("材质层", "表面角色"):
        hit = re.search(r"\*\*" + label + r"\*\*[:：]\s*([^.。]*)[.。]", text)
        if hit:
            facets.append(f"{label}: {hit.group(1).strip()}")
            text = text.replace(hit.group(0), "").strip()
    facet_suffix = f"（{' / '.join(facets)}）" if facets else ""
    if not text:
        return (DOC_RESIDUE + facet_suffix) if facet_suffix else DOC_RESIDUE
    cut = re.split(r"(?<=[。！？])", text)[0].strip()
    if not cut:
        return (DOC_RESIDUE + facet_suffix) if facet_suffix else DOC_RESIDUE
    body = cut if len(cut) <= limit else cut[:limit] + "…"
    return body + facet_suffix


def conformance_tokens(tail):
    """把 `<T: View>: Sendable, Identifiable` 归约成 ['Sendable','Identifiable']。

    泛型参数区不参与判定——`<Content: View>` 里的 View 是约束，不是遵从。
    """
    tail = tail.split("{")[0]
    if tail.lstrip().startswith("<"):
        tail = tail.lstrip()
        depth = 0
        for pos, char in enumerate(tail):
            if char == "<":
                depth += 1
            elif char == ">":
                depth -= 1
                if depth == 0:
                    tail = tail[pos + 1:]
                    break
    tail = re.split(r"\bwhere\b", tail)[0]
    if ":" not in tail:
        return []
    return [t.strip() for t in tail.split(":", 1)[1].split(",") if t.strip()]


def is_component(tokens):
    return any(t in COMPONENT_CONFORMANCES or t.endswith("Style") for t in tokens)


def enum_cases(lines, start):
    """收集 enum 的 case。

    只在 **enum 自身体那一层深度**收——`switch self { case let .leading(x): … }` 住在
    更深的层，混进来会把 `let` 当成 case 名（`.let` 曾两次进入产物）。花括号计数前
    剥注释与字符串，否则注释里的 `.mask {` 会跑飞。
    """
    cases = []
    depth = 0
    entered = False
    for line in lines[start:]:
        body = strip_noise(line)
        if entered and depth <= 0:
            break
        if depth == 1:
            for raw in re.findall(r"^\s*case\s+(?!let\b|var\b)([A-Za-z_]\w*)", body):
                cases.append(raw)
            for extra in re.findall(r";\s*case\s+(?!let\b|var\b)([A-Za-z_]\w*)", body):
                cases.append(extra)
        depth += body.count("{") - body.count("}")
        if depth > 0:
            entered = True
    return cases


def scalar_tokens(root, filename, enum_name):
    src = read(os.path.join(root, "Sources/CoreDesign/Tokens", filename))
    lines = src.split("\n")
    rows = []
    for index, line in enumerate(lines):
        match = re.match(
            r"\s*public\s+static\s+let\s+(\w+)\s*:\s*\w+\s*=\s*([\-\d.]+)", line
        )
        if match:
            rows.append((match.group(1), match.group(2), summarise(doc_above(lines, index))))
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
    order = ["mini", "small", "regular", "large", "extraLarge"]
    table = {}
    for func in ["height", "horizontalPadding", "verticalPadding", "fontToken", "iconSize"]:
        segment = src.split(f"public static func {func}(")[1].split("\n    }")[0]
        for size, value in re.findall(r"case\s+\.(\w+):\s*(?:return\s+)?([\w.]+)", segment):
            if size in order:
                table.setdefault(size, {})[func] = value
    return [(size, table[size]) for size in order if size in table]


def single_line_alias(lines, index):
    """取 `static var x: Color { .secondaryLabel }` 这类单行别名的右手边。

    本仓的写法是**函数体换行**（`{` 在声明行末，表达式在下一行），所以不能只看同一行。
    """
    line = lines[index]
    same = re.search(r"=\s*(.+?)\s*$", line)
    if same:
        return same.group(1)
    same = re.search(r"\{\s*([^{}]+?)\s*\}\s*$", line)
    if same:
        return same.group(1)
    if line.rstrip().endswith("{") and index + 2 < len(lines):
        expr = lines[index + 1].strip()
        closer = lines[index + 2].strip()
        if closer == "}" and expr and "{" not in expr and "}" not in expr:
            return expr
    return None


def semantic_colors(root):
    """只收 `public extension Color` 块内的 static 成员。

    可见性判定按所在块，不按行内有没有 private 字样——private 换行写时行内查不到。
    """
    groups = []
    for path in sorted(glob.glob(os.path.join(root, "Sources/CoreDesign/Colors/*.swift"))):
        base = os.path.basename(path)
        if base == "ColorGrade.swift":
            continue
        lines = read(path).split("\n")
        rows = []
        depth = 0
        public_ext_depth = None
        for index, line in enumerate(lines):
            ext = re.match(r"\s*public\s+extension\s+Color\b", line)
            if ext and public_ext_depth is None:
                public_ext_depth = depth
            if public_ext_depth is not None and depth > public_ext_depth:
                member = re.match(r"\s*static\s+(?:let|var)\s+(\w+)\s*[:=]", line)
                if member:
                    doc = summarise(doc_above(lines, index), 110)
                    # 没有文档注释时退到**单行别名**：这批 token 几乎全是
                    # `static var surfaceRaised: Color { .secondarySystemGroupedBackground }`
                    # 这种形态，指向哪个系统语义色比一句中文摘要更有用（能直接映射到 HIG）。
                    if doc.startswith(DOC_RESIDUE):
                        alias = single_line_alias(lines, index)
                        if alias:
                            doc = f"→ `{alias}`"
                    rows.append((member.group(1), doc))
            depth += depth_delta(line)
            if public_ext_depth is not None and depth <= public_ext_depth:
                public_ext_depth = None
        if rows:
            groups.append((base.replace(".swift", ""), rows))
    return groups


def target_surface(root, target):
    """收集各 target 的公开类型，分四桶：组件 / protocol / 配置枚举 / 其他公开类型。

    第四桶存在的理由：不静默丢弃任何公开类型——`ToastHost`、`ToastItem`、各
    `*StyleConfiguration` 都落在前三桶之外，漏掉它们读者无从知道有取舍。
    嵌套类型输出**限定名**（`CoreElevation.Spec`），裸名不是能写进代码的真名。
    """
    files = []
    for path in sorted(glob.glob(os.path.join(root, f"Sources/{target}/**/*.swift"), recursive=True)):
        lines = read(path).split("\n")
        views, enums, protocols, others = [], [], [], []
        depth = 0
        stack = []
        for index, line in enumerate(lines):
            body = strip_noise(line)
            while stack and stack[-1][1] >= depth:
                stack.pop()
            match = re.match(
                r"\s*public\s+(?:nonisolated\s+)?(struct|enum|protocol|final class|class)\s+(\w+)(.*)",
                line,
            )
            if match:
                kind, name, tail = match.group(1), match.group(2), match.group(3)
                qualified = ".".join([n for n, _ in stack] + [name])
                doc = summarise(doc_above(lines, index))
                tokens = conformance_tokens(tail)
                conforms = tail.split("{")[0].strip()
                if kind == "protocol":
                    protocols.append((qualified, doc))
                elif kind == "enum":
                    cases = enum_cases(lines, index)
                    if cases:
                        enums.append((qualified, cases, doc))
                    else:
                        others.append((kind, qualified, doc))
                elif is_component(tokens):
                    views.append((qualified, conforms, doc))
                else:
                    others.append((kind, qualified, doc))
                stack.append((name, depth))
            depth += body.count("{") - body.count("}")
        if views or enums or protocols or others:
            rel = os.path.relpath(path, os.path.join(root, f"Sources/{target}"))
            files.append((rel, views, enums, protocols, others))
    return files


def extension_members(root, hosts, require_where=False):
    """抽 `public extension <Host>` 块内的成员入口。

    host 按花括号深度维护——不清空会让一个 public extension View 之后的所有
    private 类型成员都被当成 View 上的入口（本脚本第一版就是这么把 5 条非 API
    写进产物的）。static 成员必须收：Transition / ButtonStyle 上的入口全是 static。
    """
    rows = []
    for target in TARGETS:
        for path in sorted(glob.glob(os.path.join(root, f"Sources/{target}/**/*.swift"), recursive=True)):
            lines = read(path).split("\n")
            depth = 0
            host = None
            host_depth = None
            host_note = None
            for index, line in enumerate(lines):
                ext = re.match(
                    r"\s*public\s+extension\s+([\w.]+)(?:\s+where\s+Self\s*==\s*(\w+))?", line
                )
                if ext and host is None:
                    name, where = ext.group(1), ext.group(2)
                    if require_where:
                        hit = where is not None and name.endswith("Style")
                    else:
                        hit = hosts is not None and name in hosts
                    if hit:
                        host = name
                        host_depth = depth
                        host_note = where
                if host is not None and depth > host_depth:
                    member = re.match(
                        r"\s*(?:public\s+)?(?:nonisolated\s+)?(?:static\s+)?(?:func|var)\s+(\w+)", line
                    )
                    if member:
                        rows.append(
                            (target, host, member.group(1), host_note,
                             summarise(doc_above(lines, index), 110))
                        )
                depth += depth_delta(line)
                if host is not None and depth <= host_depth:
                    host = None
                    host_depth = None
                    host_note = None
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
    parser.add_argument("--header", default=None)
    parser.add_argument("--out", default=None)
    args = parser.parse_args()
    root = os.path.abspath(args.root)
    # --header / --out 默认相对 --root 解析，否则 `--root /elsewhere` 会把别处的树
    # 写进本仓产物。
    header_path = os.path.abspath(args.header or os.path.join(root, "docs/design-digest.header.md"))
    out_path = os.path.abspath(args.out or os.path.join(root, "docs/design-digest.md"))

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
            add(f"| `{name}.{token}` | {value} | {doc} |")
        add("")

    typo = typography_tokens(root)
    counts["typography"] = len(typo)
    add(f"## `CoreTypography.Token`（{len(typo)} 档，经 `.coreFont(_:)` 施加）\n")
    add("每档对应一个 Apple 系统文本样式，字号 / 行高 / 字重 / Dynamic Type 缩放由系统决定。")
    add("⚠️ 不是一一对应：`captionMono` 与 `caption` 共用 `Font.TextStyle.caption`，差别是 "
        "`design: .monospaced`。\n")
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

    add("\n---\n\n# 语义颜色（第 2–4 层）\n")
    add("⚠️ **本节跨层，不都是第 3 / 4 层**——按 CLAUDE.md《分层色彩系统》的定层："
        "`SystemBackgroundColors` / `SystemLabelColors` 是**第 2 层**系统色桥接；"
        "`MaskColors` 的 `maskOpaque` **不在四层之内**（唯一契约是 α = 1，不是一个颜色决定，"
        "别拿它当前景/背景色用）。其余各组为第 3 / 4 层。"
        "⇒ 原型标注里**不要**直接写第 2 层的名字，走对应的第 3 层别名"
        "（`surfaceBase` / `contentPrimary` …）。")
    add("⚠️ 第 1 层色阶（`ColorGrade` 的 17 色相 × 10 档）**有意不列入本摘要**——组件里不直接用。\n")
    total_colors = 0
    for group, rows in semantic_colors(root):
        total_colors += len(rows)
        add(f"## `{group}`（{len(rows)}）\n")
        add("| token | 说明 |")
        add("|---|---|")
        for token, doc in rows:
            add(f"| `Color.{token}` | {doc} |")
        add("")
    counts["colors"] = total_colors

    add("\n---\n\n# 组件与类型\n")
    add("每个文件下分四类：**组件**（遵从 `View` / `Transition` / `Layout` / `Shape` / "
        "`ViewModifier` 或以 `Style` 结尾的协议）、**protocol**、**配置枚举**、"
        "**其他公开类型**（前三类之外的，如 `ToastHost` / 各 `*StyleConfiguration`）。\n"
        "⚠️ 名字带 `RenderProbe` 的是**测试探针**，不是设计系统表面，别当组件用。\n")
    comp_total = enum_total = other_total = proto_total = case_total = 0
    for target in TARGETS:
        add(f"## `{target}`\n")
        for rel, views, enums, protocols, others in target_surface(root, target):
            add(f"### `{rel}`\n")
            for name, conforms, doc in views:
                comp_total += 1
                add(f"- **`{name}`** *{conforms}* — {doc}")
            for name, doc in protocols:
                proto_total += 1
                add(f"- *protocol* **`{name}`** — {doc}")
            for name, cases, doc in enums:
                enum_total += 1
                case_total += len(cases)
                add(f"- *enum* **`{name}`**: " + ", ".join(f"`.{c}`" for c in cases))
            for kind, name, doc in others:
                other_total += 1
                add(f"- *{kind}* **`{name}`** — {doc}")
            add("")
    counts["components"] = comp_total
    counts["enums"] = enum_total
    counts["enumcases"] = case_total
    counts["protocols"] = proto_total
    counts["others"] = other_total

    exts = extension_members(root, {"View", "Transition"})
    counts["viewext"] = len(exts)
    add("\n---\n\n# Modifier / Transition 入口点\n")
    add(f"共 {len(exts)} 个（按 `Host.member` 去重，含参重载算一条）。\n")
    add("| target | 入口 | 说明 |")
    add("|---|---|---|")
    for target, host, name, _where, doc in exts:
        add(f"| `{target}` | `.{name}` on `{host}` | {doc} |")
    add("")

    # host 不写死白名单：判定为「`where Self ==` 且 host 名以 Style 结尾」。写死白名单
    # 的失效方向向绿——新增一族样式协议会既不进本节、也不让 styleext 计数变化。
    styles = extension_members(root, None, require_where=True)
    counts["styleext"] = len(styles)
    add("\n---\n\n# 样式入口点（`*Style where Self == …`）\n")
    add(f"共 {len(styles)} 个（按 `Host.member` 去重，含参重载算一条——`.solid` 与 `.solid(role:)` 是同一条）。经 `.buttonStyle(_:)` / `.progressViewStyle(_:)` 等施加。")
    add("⚠️ **`.borderless` 必须带括号**：该名与 SwiftUI 自带的 "
        "`PrimitiveButtonStyle.borderless` 重合，两者只差一对括号、**都能编译且无诊断**——"
        "`.buttonStyle(.borderless)` 拿到的是 **SwiftUI 的**样式，`.buttonStyle(.borderless())` "
        "才是本包的。\n")
    add("| 入口 | 协议 | 具体样式 | 说明 |")
    add("|---|---|---|---|")
    for target, host, name, where, doc in styles:
        add(f"| `.{name}` | `{host}` | `{where}` | {doc} |")
    add("")

    add("\n---\n\n# 生成基数\n")
    add("当前钉法是**精确值**，不是留有余量的下界：任何一节增减都判红，要求有人看一眼再改数。\n")
    add("| 节 | 计数 | 钉住的值 |")
    add("|---|---|---|")
    for key, expected in FLOORS.items():
        add(f"| {key} | {counts.get(key, 0)} | {expected} |")
    add("")

    failed = [
        f"{key}: {counts.get(key, 0)} != {expected}"
        for key, expected in FLOORS.items()
        if counts.get(key, 0) != expected
    ]

    # 判据不过**照常写盘**：此处产物已完整构建（上面几百行都跑完了），与钉住的数不符
    # 不等于文件残缺——「生成基数」那张表自己就把两列并排印出来。不写盘只会逼开发者
    # 跑两趟才看得见 diff，而摩擦正是「干脆把判据调松」的第一推动力。
    header = read(header_path).rstrip() + "\n"
    with open(out_path, "w", encoding="utf-8") as handle:
        handle.write(header + "\n".join(body) + "\n")

    if failed:
        print("FAIL 基数与钉住的值不符：", "; ".join(failed), file=sys.stderr)
        print("核对无误后，把 FLOORS 换成：", file=sys.stderr)
        print("FLOORS = {", file=sys.stderr)
        for key in FLOORS:
            print(f'    "{key}": {counts.get(key, 0)},', file=sys.stderr)
        print("}", file=sys.stderr)
        return 1
    print("OK", {k: counts.get(k, 0) for k in FLOORS})
    return 0


if __name__ == "__main__":
    sys.exit(main())
