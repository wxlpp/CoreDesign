import CoreDesign
import Foundation
import SwiftUI

// MARK: - 公开可见性契约（Issue #94）
//
// 以下符号此前漏写 `public`，下游实测报 `cannot find in scope` /
// `initializer is inaccessible`。库内测试看不见这个问题——它们跑在 target
// 内部，internal 符号一样可达。只有从外部包才能守住这条契约。
//
// 注意本文件与同目录 `NonisolatedUsage.swift` 的分工：那边守**隔离**契约
// （函数全部 `nonisolated`），这边守**可见性**契约。CoreDesign 开了
// `.defaultIsolation(MainActor.self)`，所以这里的函数都得是 `@MainActor`
// ——包括读 `ButtonRoleStyleRole` 的调色板属性。换言之：这三个属性对下游
// **可见但不是 nonisolated 可达的**；若日后需要 nonisolated 可达，那是另一个
// 范围内的改动（给属性标 `nonisolated`），不要在本文件里顺手夹带。

@MainActor
func constructCheckBoxToggleStyle() -> CheckBoxToggleStyle {
    CheckBoxToggleStyle()
}

@MainActor
func constructBorderlessStyle() -> CoreBorderlessButtonStyle {
    let style = CoreBorderlessButtonStyle(role: .danger)
    _ = style.role
    return style
}

@MainActor
func readRolePalette(_ role: ButtonRoleStyleRole) -> [Color] {
    [role.color, role.activeColor, role.disabledColor]
}

// MARK: - 静态访问器与 style 消费路径
//
// 上面三个函数直接构造类型，但下游**实际**走的是访问器与 `.buttonStyle(...)` /
// `.toggleStyle(...)`。A3a 的结论「改名后 `App/` 与 docs 示例无需改动，因为
// `.borderless(role:)` 名称不变」正是靠 `ButtonStyle where Self == ...` 那个
// public extension 成立的——若日后有人把它的 `public` 弄丢，四条 SwiftPM 命令
// 与上面的直接构造都仍然绿，破坏只会在真实下游炸。这两个函数把访问器本身
// 也纳入契约。

@MainActor
func consumeBorderlessAccessor() -> some View {
    Button("borderless") {}
        .buttonStyle(.borderless(role: .danger))
}

@MainActor
func consumeCheckBoxToggleStyle(isOn: Binding<Bool>) -> some View {
    Toggle("checkbox", isOn: isOn)
        .toggleStyle(CheckBoxToggleStyle())
}

// MARK: - CircularGlassButtonStyle 的破坏性类型变更（Issue #96）
//
// `diameter` 从 `CGFloat` 变为 `CGFloat?`（B3e：档位改由 `size` 决定，
// `diameter` 退化为显式覆写通道）。这是**源码级破坏性变更**——下游写
// `let d: CGFloat = style.diameter` 会断。下面用 `guard let` 把这一事实固定进
// probe：日后若改回非 optional，条件绑定会编译失败。

@MainActor
func constructCircularGlass() -> CGFloat {
    let style = CircularGlassButtonStyle(size: .large, diameter: 44)
    // 必须用 `guard let` 而非「返回 `CGFloat?`」——Swift 对 `T` → `T?` 有隐式提升，
    // `return style.diameter` 在 `diameter` 改回非 optional 时**照样编译**，那样
    // 这个关卡就是空的。条件绑定对非 optional 会硬报
    // `initializer for conditional binding must have Optional type`。
    guard let diameter = style.diameter else {
        return CoreControlMetrics.height(for: style.size)
    }
    return diameter
}

// 访问器路径单独覆盖：`circularGlass(diameter:)` 是本任务未改动但公开的 API。
//
// > 必须经 `.buttonStyle(.circularGlass(...))` 的前导点推断来触达，**不能**写
// > `ButtonStyle.circularGlass(diameter:)`——该静态成员定义在
// > `extension ButtonStyle where Self == CircularGlassButtonStyle` 上，经协议
// > 元类型访问会报 `static member 'circularGlass' cannot be used on protocol
// > metatype '(any ButtonStyle).Type'`。
@MainActor
func consumeCircularGlassAccessor() -> some View {
    Button("circular") {}
        .buttonStyle(.circularGlass(diameter: 44))
}

// MARK: - Issue #96 新增的公开面

// `TelegramGlassButtonModifier` 的默认值契约：该类型的 doc 写明「新增参数时
// 务必保持这一契约」——两参数形态必须**永远**能编译。这句承诺此前只是注释，
// 现在由 probe 从外部视角钉住：任何人给 init 加无默认值的参数都会在此失败。
@MainActor
func consumeGlassModifierTwoArgForm() -> some View {
    Text("glass")
        .modifier(TelegramGlassButtonModifier(shape: Capsule(), isPressed: false))
}

// `ButtonRoleStyleRole.resolvedColor` 是 #96 新增的 public 方法，现为三个
// ButtonStyle 三态取色的唯一来源。`readRolePalette` 只覆盖了三个调色板属性。
// 与 `readRolePalette` 同样必须 `@MainActor`——`defaultIsolation(MainActor.self)`
// 下这个方法也是 MainActor 隔离的（它读三个隔离的调色板属性）。
@MainActor
func consumeResolvedColor(_ role: ButtonRoleStyleRole) -> Color {
    role.resolvedColor(isEnabled: true, isPressed: false)
}

// 档位主通道访问器（`circularGlass(size:)`），与逃生舱 `circularGlass(diameter:)`
// 并列覆盖。
@MainActor
func consumeCircularGlassTierAccessor() -> some View {
    Button("tier") {}
        .buttonStyle(.circularGlass(size: .small))
}
