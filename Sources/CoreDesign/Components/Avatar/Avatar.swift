//
//  Avatar.swift
//  CoreDesign
//
//  Created by 王晓龙 on 2025/1/29.
//

import SwiftUI

// MARK: - Avatar

/// Native Primer avatar.
///
/// Content-layer identity affordance. Circular crop (by caller via
/// `.clipShape(Circle())`), no border. Uses name-derived background color
/// with white initial. No glass.
///
/// **Material layer**: content. **Surface role**: content.
///
/// 头像 / Avatar：根据姓名生成圆形彩色占位头像。
///
/// 使用场景：用户列表 / 评论作者 / 登录态指示器等需要在缺图情景下给出可视化身份提示
/// 的位置。Primer 概念上对应 `Avatar` 组件的"无图占位"分支——本组件不渲染外部图片，
/// 仅按姓名首字符 + 由姓名稳定哈希出的色相填充背景。
///
/// 视觉规格：
/// - 内部位图边长 `CoreSpacing.xxxxl`（48pt）。`.resizable()` + `.aspectRatio(.fill)`
///   暴露给调用方，调用方决定外框尺寸；圆形语义由调用方 `.clipShape(Circle())` 保证。
/// - 首字符字号 `CoreTypography.Token.title.font`（28pt regular）+ `.weight(.bold)`
///   保留原有 bold 视觉权重；颜色固定 `Color.white` 与彩色背景对比。
/// - light / dark 行为一致：背景由 `Color(text:)` 哈希派生，前景始终白色。
public struct Avatar: View {
    public init(name: String) {
        self.name = name
    }

    /// 内部位图边长。Avatar 圆角语义由调用方 `clipShape(Circle())` 保证（对应
    /// `Capsule()` 的 pill / 头像意图），本结构不在内部 `cornerRadius` 字面量上做约束。
    private static let canvasSide: CGFloat = CoreSpacing.xxxxl

    public var body: some View {
        let size = CGSize(width: Self.canvasSide, height: Self.canvasSide)
        let firstCharacter = String(name.prefix(1).uppercased())

        Image(size: size, label: Text(self.name)) { context in
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Color(text: self.name))
            )
            context.draw(
                Text(firstCharacter)
                    // Canvas / GraphicsContext.draw 是命令式绘制，套不了 `.coreFont`
                    // modifier，只能直接引用 `CoreTypography.Token.title.font`。
                    // Issue #119 起该 token 本身随 Dynamic Type 缩放（不再有"固定不
                    // 缩放"的 *Font 变体）——首字符字号因此也会跟着系统字号设置变化，
                    // 与旧版本"本就不纳入 Dynamic Type"的说法不再成立。
                    .font(CoreTypography.Token.title.font.weight(.bold))
                    .foregroundStyle(Color.white),
                at: CGPoint(x: size.width / 2, y: size.height / 2)
            )
        }
        .resizable()
        .aspectRatio(contentMode: .fill)
    }

    let name: String
}

#Preview {
    Avatar(name: "A").frame(width: 100, height: 100).clipShape(Circle())
}
