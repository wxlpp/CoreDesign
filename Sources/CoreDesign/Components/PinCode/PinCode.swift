//
//  PinCode.swift
//  CoreDesign
//

import SwiftUI

// MARK: - PinCode

/// **材质层**: 控件. **表面角色**: 控件.
///
/// `Binding<String>` 驱动的验证码 / PIN 分格输入组件 / PIN & OTP entry control driven
/// by a `Binding<String>`，固定格数（`length`）。
///
/// ## 实现手法
///
/// 渲染层是 `length` 个独立格子（各自带边框的容器），按下标把 `value` 拆成单字符渲染；
/// 输入层复用**单一隐藏 `TextField`**捕获系统键盘输入（常见 OTP 实现手法）——两端天然
/// 获得同一套光标跟随 / 退格删除上一位 / 粘贴多位数字 / iOS 单条码 OTP 自动填充横幅行为，
/// 不需要每格各自 `FocusState` + 手写前后跳转逻辑。隐藏字段视觉上不可见
/// （`opacity` 极低），但仍是真实可聚焦的系统输入控件；`cellsRow` 整体挂 `onTapGesture`
/// 把 `isFocused` 设为 `true`，间接聚焦隐藏字段并唤起键盘。
///
/// ## 双端行为（NFR-2：不留单端公开符号）
///
/// 公开 API（类型 / init / 参数）在 iOS 与 macOS 两端完全一致；平台差异全部封装在
/// `hiddenTextField` 实现内部的 `#if os(iOS)` 分支——iOS 端追加
/// `.textContentType(.oneTimeCode)`（触发系统单条码 OTP 自动填充）+
/// `.keyboardType(.numberPad)`（数字键盘）；macOS 端复用同一个 `TextField`，只是跳过
/// 这两个 modifier（`.keyboardType` 在 macOS 上不存在，`.textContentType(.oneTimeCode)`
/// 在 macOS 上无实际效果）。
///
/// ## 受控逻辑
///
/// 每次 `value` 变化都经 `sanitizedValue(from:length:)` 过滤非数字字符并 clamp 长度，
/// 结果写回 `Binding`；当结果字符数等于 `length` 时触发 `onComplete?(value)`。这条
/// 处理流水线抽成静态纯函数（`sanitizedValue` / `isComplete`）+ 单个处理入口
/// （`processInput(_:)`），可脱离 SwiftUI 渲染上下文直接单测——与 `Rating` /
/// `RadioGroup` 同样的手法。
///
/// > Note: `processInput(_:)` 在「已填满后又输入被过滤掉的噪声字符」这类边缘场景下，
/// > 可能因为一次「写回清洗值 → 触发下一轮 `onChange`」的连锁反应而对同一次用户操作
/// > 调用 `onComplete` 两次（两次参数相同、幂等）。未做额外去重状态跟踪——这是显式
/// > 评估后的取舍：修复需要引入「上次是否已完成」的额外私有状态，而验收标准只要求
/// > 「输入填满时触发回调」，不要求「每次填满事件严格恰好触发一次」。
///
/// ## 强调色
///
/// 当前焦点格边框走 `.tint`（`TintShapeStyle`）——不写死 `Color.accent`，调用方外加
/// `.tint(_:)` 会让焦点格边框真的变色；非焦点格边框走 `Color.borderMuted`。
///
/// ## Accessibility
///
/// 每格是独立的 accessibility element：label 用 Phase 0 预登记键 `"Verification code"`，
/// value 用位置键 `"%@ of %@"`（`String(localized: "\(idx.formatted()) of
/// \(count.formatted())", bundle: .module)`），如「3 of 6」。真正承接键盘输入的隐藏
/// `TextField` 对 accessibility 树隐藏（`accessibilityHidden(true)`）——避免与逐格
/// element 重复播报；VoiceOver 双击某一格时经 `accessibilityAction` 把 `isFocused`
/// 设为 `true`，转发到隐藏字段唤起键盘，格子本身仍然只负责播报状态。
///
/// ```swift
/// @State private var code: String = ""
///
/// PinCode(value: $code, length: 6) { completed in
///     verify(completed)
/// }
///
/// // 掩码显示（PIN 场景）
/// PinCode(value: $pin, length: 4, isSecure: true)
///
/// // 覆盖强调色——焦点格边框走 `.tint`，不写死 `Color.accent`
/// PinCode(value: $code, length: 6)
///     .tint(.orange)
/// ```
public struct PinCode: View {
    // 非 `private`：`length` / `isSecure` 需要在 `@testable import` 的单测里直接断言
    // 构造参数是否原样保留（见 PinCodeTests）。这不扩大 public API 表面——外部下游仍
    // 只能通过 `init` 设置，读不到这些字段。
    @Binding var value: String
    let length: Int
    let isSecure: Bool
    let onComplete: ((String) -> Void)?

    @FocusState private var isFocused: Bool
    @Environment(\.controlSize) private var controlSize
    @Environment(\.isEnabled) private var isEnabled

    /// - Parameters:
    ///   - value: 当前验证码文本，驱动方通过 `Binding<String>` 双向绑定；组件内部会
    ///     过滤非数字字符并 clamp 到 `length`，结果写回本绑定。
    ///   - length: 固定格数，非正数会被 clamp 到 1。
    ///   - isSecure: 掩码显示是否开启，默认 `false`（明文展示）；开启后各格以圆点
    ///     替代实际字符。
    ///   - onComplete: 输入填满 `length` 格时触发的可选回调，参数为最终值。
    public init(
        value: Binding<String>,
        length: Int,
        isSecure: Bool = false,
        onComplete: ((String) -> Void)? = nil
    ) {
        self._value = value
        self.length = max(1, length)
        self.isSecure = isSecure
        self.onComplete = onComplete
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            self.hiddenTextField
            self.cellsRow
        }
        // 挂载时先规整初始 `value`（去非数字/截断），避免第一帧显示未清洗的原始值；
        // 但**挂载路径不触发 `onComplete`**（`firesOnComplete: false`）——「初值即完成」不是
        // 一次「填满」事件，且重放会在 NavigationStack 里 push→pop→再 push 成循环。
        .onAppear {
            self.processInput(self.value, previousValue: self.value, firesOnComplete: false)
        }
    }

    private var cellsRow: some View {
        HStack(spacing: CoreSpacing.sm) {
            ForEach(0..<self.length, id: \.self) { index in
                self.cell(at: index)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            self.isFocused = true
        }
    }

    /// 隐藏的系统 `TextField`——真实键盘输入全部落在这一个不可见字段上，`cellsRow`
    /// 只负责按下标把 `value` 渲染成格子视觉。视觉上不可见（`opacity` 极低）但仍是
    /// 真实可聚焦的系统输入控件，保留系统键盘 / 光标 / 粘贴 / iOS 单条码 OTP
    /// 自动填充横幅等原生行为；对 accessibility 树隐藏，键盘唤起改由格子的
    /// `accessibilityAction` 转发。
    ///
    /// Phase 3 / #173 视觉复查发现的修复：`TextField` 不加约束时会撑满 `ZStack` 提议的
    /// 全部可用宽度（而非贴合自身文字内容），当外层给出的宽度**大于** `cellsRow` 的实际
    /// 宽度时（例如宿主画廊详情页的固定列宽），`ZStack` 默认居中对齐让较窄的 `cellsRow`
    /// 整体右移，而占满全宽的 `TextField` 其文字仍从最左侧起排——0.01 透明度的文字因此
    /// 露出在 `cellsRow` 左侧边界之外的空白区域（截图可见「12」重影），不再被任何不透明
    /// 格子遮挡。`.fixedSize()` 让 `TextField` 退回到贴合自身文字内容的 ideal 宽度，
    /// 使其在 `ZStack` 中与更宽的 `cellsRow` 居中对齐、落在格子的不透明背景之下，
    /// 从而真正不可见（而不仅仅是"透明度很低但仍会露出"）。
    private var hiddenTextField: some View {
        TextField("", text: self.$value)
            .focused(self.$isFocused)
            .textFieldStyle(.plain)
            .autocorrectionDisabled(true)
            #if os(iOS)
            .textContentType(.oneTimeCode)
            .keyboardType(.numberPad)
            #endif
            .fixedSize()
            .opacity(0.01)
            .accessibilityHidden(true)
            .onChange(of: self.value) { oldValue, newValue in
                // 穿透 SwiftUI 提供的**真**击键前旧值——`self.value` 此刻已是新值，不可用。
                self.processInput(newValue, previousValue: oldValue)
            }
    }

    // MARK: - Cell rendering

    private var cellSize: CGFloat {
        CoreControlMetrics.height(for: self.controlSize)
    }

    @ViewBuilder
    private func cell(at index: Int) -> some View {
        let character = Self.character(at: index, in: self.value)
        let isCurrent = self.isFocused
            && self.isEnabled
            && index == Self.focusedIndex(valueCount: self.value.count, length: self.length)
        let shape = CoreShape.rounded(CoreRadius.medium)

        Text(Self.displayText(for: character, isSecure: self.isSecure))
            .coreFont(.title2)
            .foregroundStyle(self.isEnabled ? Color.contentPrimary : Color.contentDisabled)
            .frame(width: self.cellSize, height: self.cellSize)
            .background {
                shape.fill(Color.surfaceInteractive)
            }
            .overlay {
                // 焦点格边框走 `.tint`（不写死 `Color.accent`），非焦点格走
                // `Color.borderMuted`——`AnyShapeStyle` 统一两条分支的类型，与
                // `Components/Form/Form.swift` 的 `LabelIcon` 同一手法。
                shape.strokeBorder(
                    isCurrent ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.borderMuted),
                    lineWidth: isCurrent ? CoreBorderWidth.thick : CoreBorderWidth.thin
                )
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Verification code", bundle: .module))
            .accessibilityValue(Text(verbatim: Self.accessibilityValueText(index: index + 1, count: self.length, character: character, isSecure: self.isSecure)))
            .accessibilityAddTraits(isCurrent ? .isSelected : [])
            .accessibilityAction {
                self.isFocused = true
            }
    }

    // MARK: - Processing entry (unit-testable via `@testable import`)

    /// 处理一次原始输入：过滤非数字字符 + clamp 长度，结果写回 `value`；**仅在「未满→满」
    /// 的转变沿**触发 `onComplete`。`hiddenTextField` 的 `onChange` 与 `body` 的 `onAppear`
    /// 都经由这一个入口，保证初始值与运行期输入走同一套清洗逻辑。
    ///
    /// 转变沿判定基于「写回前的旧 `value` 是否已满」vs「清洗后的新值是否已满」——只有从
    /// 「未满」跨到「满」才触发。这消除三类误触发：①已满态再键入任意字符（含被过滤的噪声）
    /// 时的重复触发；②`onAppear` 对已满初始值的重放（NavigationStack 场景下会 push→pop→
    /// 再 push 成导航循环）。删一位再补回最后一位时旧值已「未满」，故能正确再次触发。
    func processInput(_ raw: String, previousValue: String, firesOnComplete: Bool = true) {
        let sanitized = Self.sanitizedValue(from: raw, length: self.length)
        let fires = firesOnComplete
            && Self.shouldFireComplete(previousValue: previousValue, newSanitized: sanitized, length: self.length)
        if sanitized != self.value {
            self.value = sanitized
        }
        if fires {
            self.onComplete?(sanitized)
        }
    }

    /// `onComplete` 触发判定（纯函数，可单测）：新值已满**且**「规整后的旧值 ≠ 新值」时才为真。
    ///
    /// `previousValue` 是 `onChange` 提供的**击键前**旧值——**不能**用 `self.value`：隐藏
    /// `TextField` 直接绑 `$value`，onChange 触发时 `self.value` 已被写成新值。
    ///
    /// 抑制条件用「规整旧值 == 新值」而非「旧值已满」：后者会漏掉「满态整体替换成另一个完整
    /// 码」——iOS `.oneTimeCode` 自动填充的招牌场景（用户已手输错码、验证失败未清空，短信到达
    /// 点自动填充横幅整体替换）就是满→满但内容不同，应当触发。用相等判定：补满触发 ✓；满态多敲/
    /// 噪声引发的写回第二轮配对恒为 `(raw, sanitize(raw))`、规整后必然相等 → 结构性永假、不重触发 ✓；
    /// 满态替换新码 → 不等 → 触发 ✓。
    static func shouldFireComplete(previousValue: String, newSanitized: String, length: Int) -> Bool {
        Self.isComplete(value: newSanitized, length: length)
            && Self.sanitizedValue(from: previousValue, length: length) != newSanitized
    }

    // MARK: - Pure logic (unit-testable via `@testable import`)

    /// 过滤非数字字符（保留 ASCII `0`–`9`）并 clamp 到 `length`。
    static func sanitizedValue(from raw: String, length: Int) -> String {
        let digitsOnly = raw.filter { $0.isASCII && $0.isNumber }
        return String(digitsOnly.prefix(length))
    }

    /// 字符数是否恰好等于 `length`（判定是否触发 `onComplete`）。
    static func isComplete(value: String, length: Int) -> Bool {
        value.count == length
    }

    /// 取 `value` 中第 `index`（0-based）位字符；越界或负数返回 `nil`（渲染为空格）。
    static func character(at index: Int, in value: String) -> Character? {
        guard index >= 0, index < value.count else { return nil }
        return value[value.index(value.startIndex, offsetBy: index)]
    }

    /// 单格展示文案：`isSecure` 为 `true` 时以圆点替代实际字符；字符为 `nil` 时始终为
    /// 空字符串。
    static func displayText(for character: Character?, isSecure: Bool) -> String {
        guard let character else { return "" }
        return isSecure ? "\u{2022}" : String(character)
    }

    /// 当前应高亮的格位下标（0-based）：未填满时指向下一个空格，填满时 clamp 在
    /// 最后一格，不越界。
    static func focusedIndex(valueCount: Int, length: Int) -> Int {
        min(valueCount, max(length - 1, 0))
    }

    /// 格位 accessibility value 文案组装：Phase 0 位置键 `"%@ of %@"`
    /// （`.claude/epics/semi-mobile-components/phase0-decisions.md` §2），两端均为
    /// `Int.formatted()`。`index` 为 1-based（如「3 of 6」）。抽成静态纯函数——
    /// 与 `Rating.accessibilityValueText` 同样的理由：`bundle: .module` 漏传或插值
    /// 形状跑偏都是静默 fallback，需要能被单测锁定。
    static func positionText(index: Int, count: Int) -> String {
        String(localized: "\(index.formatted()) of \(count.formatted())", bundle: .module)
    }

    /// 格位 accessibility value：位置键（`positionText`）+ 非掩码且已填时把该格数字明文附上
    /// （数字本身是数值、无需本地化键），让 VoiceOver 用户能逐格复核已输入内容——弥补
    /// 纯位置播报「听不到填了什么」的缺口。`isSecure` 或空格时只播位置，不泄露/不臆造内容。
    /// （空格「empty」/掩码「filled」这类措辞需新本地化键，按房规留到 013 统一补登。）
    static func accessibilityValueText(index: Int, count: Int, character: Character?, isSecure: Bool) -> String {
        let position = Self.positionText(index: index, count: count)
        guard !isSecure, let character else { return position }
        return "\(position), \(character)"
    }
}

// MARK: - Preview

#Preview("PinCode — Light") {
    PinCodePreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("PinCode — Dark") {
    PinCodePreviewGallery()
        .preferredColorScheme(.dark)
}

private struct PinCodePreviewGallery: View {
    @State private var emptyCode: String = ""
    @State private var partialCode: String = "12"
    @State private var filledCode: String = "123456"
    @State private var securePin: String = "42"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CoreSpacing.lg) {
                VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                    Text("默认 · 空态（length: 6）")
                        .coreFont(.caption)
                        .foregroundStyle(Color.contentMuted)
                    PinCode(value: self.$emptyCode, length: 6)
                }

                VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                    Text("部分填充（length: 6）")
                        .coreFont(.caption)
                        .foregroundStyle(Color.contentMuted)
                    PinCode(value: self.$partialCode, length: 6)
                }

                VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                    Text("填满态（length: 6）")
                        .coreFont(.caption)
                        .foregroundStyle(Color.contentMuted)
                    PinCode(value: self.$filledCode, length: 6)
                }

                VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                    Text("isSecure: true（4 位 PIN，圆点掩码）")
                        .coreFont(.caption)
                        .foregroundStyle(Color.contentMuted)
                    PinCode(value: self.$securePin, length: 4, isSecure: true)
                }

                VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                    Text("覆盖强调色（.tint(.orange)）")
                        .coreFont(.caption)
                        .foregroundStyle(Color.contentMuted)
                    PinCode(value: self.$partialCode, length: 6)
                        .tint(.orange)
                }

                VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                    Text("禁用态（.disabled(true)）")
                        .coreFont(.caption)
                        .foregroundStyle(Color.contentMuted)
                    PinCode(value: self.$partialCode, length: 6)
                        .disabled(true)
                }

                Spacer()
            }
            .padding(CoreSpacing.lg)
        }
        .background(Color.surfaceCanvas)
    }
}
