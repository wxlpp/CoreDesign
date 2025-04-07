//
//  ContentView.swift
//  iOS Example
//
//  Created by Evan wang on 2025年1月28日.
//

import CoreDesign
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Group {
                Text("11111111111111211111111111111111111111111111112111")
                Text("22222").frame(maxWidth: .infinity)
                Text("3333333")
            }.border(Color.red)
        }.frame(width: 300)
            .border(Color.green)
    }
}

#Preview {
    ContentView()
}
