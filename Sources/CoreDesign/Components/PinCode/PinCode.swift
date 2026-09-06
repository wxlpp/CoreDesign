import SwiftUI

// MARK: - PinCode

/// **材质层**: 控件. **表面角色**: 控件.
public struct PinCode: View {
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

    static func shouldFireComplete(previousValue: String, newSanitized: String, length: Int) -> Bool {
        Self.isComplete(value: newSanitized, length: length)
            && Self.sanitizedValue(from: previousValue, length: length) != newSanitized
    }

    // MARK: - Pure logic (unit-testable via `@testable import`)

    static func sanitizedValue(from raw: String, length: Int) -> String {
        let digitsOnly = raw.filter { $0.isASCII && $0.isNumber }
        return String(digitsOnly.prefix(length))
    }

    static func isComplete(value: String, length: Int) -> Bool {
        value.count == length
    }

    static func character(at index: Int, in value: String) -> Character? {
        guard index >= 0, index < value.count else { return nil }
        return value[value.index(value.startIndex, offsetBy: index)]
    }

    static func displayText(for character: Character?, isSecure: Bool) -> String {
        guard let character else { return "" }
        return isSecure ? "\u{2022}" : String(character)
    }

    static func focusedIndex(valueCount: Int, length: Int) -> Int {
        min(valueCount, max(length - 1, 0))
    }

    static func positionText(index: Int, count: Int) -> String {
        String(localized: "\(index.formatted()) of \(count.formatted())", bundle: .module)
    }

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
