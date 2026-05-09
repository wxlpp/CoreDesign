//
//  CheckBox.swift
//  CoreDesign
//
//  Created by 王晓龙 on 2025/2/2.
//

import SwiftUI

// MARK: - CheckBoxToggleStyle

struct CheckBoxToggleStyle: ToggleStyle {
    @MainActor @preconcurrency
    func makeBody(configuration: ButtonToggleStyle.Configuration) -> some View {
        HStack(alignment: .top) {
            if configuration.isOn {
                Image(systemName: "checkmark.square.fill").foregroundStyle(Color.primary)
            } else {
                Image(systemName: "square").foregroundStyle(Color.gray)
            }
            configuration.label
        }
        .animation(.easeOut(duration: 0.25), value: configuration.isOn)
        .onTapGesture {
            configuration.isOn.toggle()
        }
    }
}

// MARK: - CheckBox

struct CheckBox: View {
    @State var isOn = false

    var body: some View {
        Toggle("哈哈哈哈哈", isOn: self.$isOn).toggleStyle(CheckBoxToggleStyle())
    }
}

#Preview {
    CheckBox()
}
