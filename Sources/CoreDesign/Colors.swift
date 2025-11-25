//
//  Colors.swift
//  CoreDesign
//
//  Created by 王晓龙 on 2025/1/28.
//

import SwiftUI

#if canImport(UIKit)
typealias SLColor = UIColor
#endif

#if canImport(AppKit)
typealias SLColor = NSColor
#endif

public struct RGBComponents {
    public let red: CGFloat
    public let green: CGFloat
    public let blue: CGFloat
    public let alpha: CGFloat
}

extension SLColor {
    public var rgbComponents: RGBComponents {
        #if canImport(UIKit)
        let slColor = self
        #endif
        #if canImport(AppKit)
        let slColor = self.usingColorSpace(.deviceRGB) ?? self
        #endif
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        slColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return RGBComponents(red: red, green: green, blue: blue, alpha: alpha)
    }
}

extension Color {
    public var rgbaString: String? {
        let components = SLColor(self).rgbComponents
        guard components.red >= 0, components.green >= 0,
              components.blue >= 0, components.alpha >= 0 else {
            return nil
        }

        let redInt = Int(components.red * 255)
        let greenInt = Int(components.green * 255)
        let blueInt = Int(components.blue * 255)
        let alphaInt = Int(components.alpha * 255)

        return String(format: "#%02X%02X%02X%02X",
                      redInt, greenInt, blueInt, alphaInt)
    }

    public var rgbaStringValue: String {
        self.rgbaString ?? ""
    }
}

extension Color: @retroactive RawRepresentable {
    public init?(rawValue: String) {
        guard let data = Data(base64Encoded: rawValue) else {
            self = .black
            return
        }

        do {
            let color = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: SLColor.self, from: data) ?? .black
            self = Color(color)
        } catch {
            self = .black
        }
    }

    public var rawValue: String {
        do {
            let data = try NSKeyedArchiver.archivedData(
                withRootObject: SLColor(self),
                requiringSecureCoding: false) as Data
            return data.base64EncodedString()

        } catch {
            return ""
        }
    }
}

public struct ColorItemView: View {
    let name: String
    let description: String
    let color: Color

    let textColor: Color

    init(name: String, description: String, color: Color, textColor: Color = .label) {
        self.name = name
        self.description = description
        self.color = color
        self.textColor = textColor
    }

    public var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(self.name)
                    .foregroundStyle(self.textColor)
                    .font(.headline)
                Text(String(self.description))
                    .foregroundStyle(self.textColor)
                    .font(.caption)
            }
            Spacer()
            Text(self.color.rgbaStringValue)
                .foregroundColor(self.textColor)
        }
        .listRowSeparator(.hidden)
        .listRowBackground(self.color)
        .listRowInsets(.none)
    }
}

#Preview {
    List {
        Section {
            ColorItemView(name: "systemBackground", description: "第一层级背景色", color: Color.white)
            ColorItemView(name: "secondarySystemBackground", description: "第二层级背景色", color: Color.gray.opacity(0.1))
            ColorItemView(name: "tertiarySystemBackground", description: "第三层级背景色", color: Color.gray.opacity(0.05))
        } header: {
            Text("背景色").foregroundStyle(Color.black)
        }
        Section {
            ColorItemView(name: "systemGroupedBackground", description: "第一层级背景色", color: Color.white)
            ColorItemView(
                name: "secondarySystemGroupedBackground",
                description: "第二层级背景色",
                color: Color.gray.opacity(0.1)
            )
            ColorItemView(
                name: "tertiarySystemGroupedBackground",
                description: "第三层级背景色",
                color: Color.gray.opacity(0.05)
            )
        } header: {
            Text("分组界面背景色").foregroundStyle(Color.black)
        }
        Section {
            ColorItemView(name: "fill", description: "为细小形状的叠加填充颜色。", color: .fill)
            ColorItemView(name: "secondaryFill", description: "中等大小形状的叠加填充颜色。", color: .secondaryFill)
            ColorItemView(name: "tertiaryFill", description: "大型形状的叠加填充颜色。", color: .tertiaryFill)
            ColorItemView(name: "quaternaryFill", description: "大区域复杂内容的覆盖填充颜色。", color: .quaternaryFill)
        } header: {
            Text("填充色").foregroundStyle(Color.black)
        }

        Section {
            ColorItemView(name: "label", description: "标签", color: Color.black, textColor: Color.white)
            ColorItemView(name: "secondaryLabel", description: "二级标签", color: .secondaryLabel)
            ColorItemView(name: "tertiaryLabel", description: "三级标签", color: .tertiaryLabel)
            ColorItemView(name: "quaternaryLabel", description: "四级标签", color: .quaternaryLabel)
            ColorItemView(name: "placeholderText", description: "占位符文本", color: .placeholderText)
            ColorItemView(name: "separator", description: "分隔符", color: .separator)
            ColorItemView(name: "opaqueSeparator", description: "不透明分隔符", color: .opaqueSeparator)
            ColorItemView(name: "link", description: "链接", color: .link)
            ColorItemView(name: "darkText", description: "", color: Color.black, textColor: Color.white)
            ColorItemView(name: "lightText", description: "", color: Color.white, textColor: Color.black)

        } header: {
            Text("文本颜色").foregroundStyle(Color.black)
        }
    }
    .headerProminence(.increased)
    .background(content: {
        Color.white
    })
    .scrollContentBackground(.hidden)
}
