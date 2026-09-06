import CoreGraphics

// MARK: - CoreSpacing

/// 间距 token，提供一套固定的 8pt 网格标度，覆盖从紧密分隔线到顶级页面结构的常见间距需求。
public nonisolated enum CoreSpacing {
    /// 无间距 (0pt)。零值占位，避免组件内魔法数字 0。
    public static let none: CGFloat = 0

    /// 超紧凑 (2pt)。表单字段分隔、紧密分隔线。
    public static let xxs: CGFloat = 2

    /// 紧凑 (4pt)。Badge / Tag 内 padding、紧密列表项分隔。
    public static let xs: CGFloat = 4

    /// 默认 (8pt)。绝大多数组件的标准 padding 与 gap。
    public static let sm: CGFloat = 8

    /// 舒适 (12pt)。容器舒展型 padding、section 之间分隔。
    public static let md: CGFloat = 12

    /// 宽松 (16pt)。主要布局区块之间分隔、容器外缘 margin。
    public static let lg: CGFloat = 16

    /// 充裕 (24pt)。大段落分隔、顶级页面结构。
    public static let xl: CGFloat = 24

    /// 大 (32pt)。大尺寸布局场景扩展档位。
    public static let xxl: CGFloat = 32

    /// 加大 (40pt)。大尺寸布局场景扩展档位。
    public static let xxxl: CGFloat = 40

    /// 特大 (48pt)。大尺寸布局场景扩展档位。
    public static let xxxxl: CGFloat = 48

    /// 巨大 (64pt)。大尺寸布局场景扩展档位。
    public static let huge: CGFloat = 64
}
