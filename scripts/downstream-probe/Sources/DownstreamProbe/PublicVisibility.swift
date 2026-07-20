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
// `let d: CGFloat = style.diameter` 会断。返回类型写 `CGFloat?` 把这一事实
// 固定进 probe：日后若改回非 optional，此处会编译失败。

@MainActor
func constructCircularGlass() -> CGFloat? {
    let style = CircularGlassButtonStyle(size: .large, diameter: 44)
    return style.diameter
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
