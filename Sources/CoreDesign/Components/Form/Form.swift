//
//  Form.swift
//  CoreDesign
//
//  Created by 王晓龙 on 2025/2/9.
//

import SwiftUI

public struct LabelIcon: View {
    private let systemName: String
    private let backgroundColor: Color
    private let variableValue: Double?

    public init(systemName: String, backgroundColor: Color, variableValue: Double? = nil) {
        self.systemName = systemName
        self.backgroundColor = backgroundColor
        self.variableValue = variableValue
    }

    public var body: some View {
        Image(systemName: "app.fill")
            .font(.system(size: 26))
            .foregroundColor(self.backgroundColor)
            .overlay(alignment: .center) {
                Image(systemName: self.systemName, variableValue: self.variableValue)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }
    }
}

public struct ChevronRightIcon: View {
    public init() {}
    public var body: some View {
        Image(systemName: "chevron.right")
    }
}

public struct DangerIcon: View {
    public init() {}
    public var body: some View {
        Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Color.danger)
    }
}

#Preview {
    @Previewable @State var isSaveDataTraffic = false
    Form {
        Section {
            LabeledContent {
                ChevronRightIcon()
            } label: {
                Label {
                    Text("主页")
                } icon: {
                    LabelIcon(systemName: "person.circle.fill", backgroundColor: .red4)
                }
            }
        }

        Section {
            LabeledContent {
                Text("扫描二维码")
                ChevronRightIcon()
            } label: {
                Label {
                    Text("设备")
                } icon: {
                    LabelIcon(systemName: "ipad.case.and.iphone.case", backgroundColor: .yellow4)
                }
            }
            LabeledContent {
                DangerIcon()
                ChevronRightIcon()
            } label: {
                Label {
                    Text("通知")
                } icon: {
                    LabelIcon(systemName: "bell.badge.fill", backgroundColor: .danger)
                }
            }
            Toggle("节省流量", isOn: $isSaveDataTraffic)
        }
    }
}
