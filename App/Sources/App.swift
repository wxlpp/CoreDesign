import SwiftUI
import CoreDesign

@main
struct CoreDesignPreviewApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("CoreDesign Components") {
                    Text("Hello, CoreDesign!")
                        .font(CoreTypography.bodyMediumFont)
                        .foregroundStyle(Color.contentPrimary)
                }
            }
            .navigationTitle("CoreDesign Preview")
            .background(Color.surfaceCanvas)
        }
    }
}

#Preview {
    ContentView()
}
