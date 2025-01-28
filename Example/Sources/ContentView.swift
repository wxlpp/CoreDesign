//
//  ContentView.swift
//  iOS Example
//
//  Created by Evan wang on 2025年1月28日.
//

import CoreDesign
import SwiftUI

struct SwiftUICoreDesign: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        CoreDesign()
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct ContentView: View {
    var body: some View {
        VStack(alignment: .center) {
            SwiftUICoreDesign()
        }
    }
}

#Preview {
    ContentView()
}
