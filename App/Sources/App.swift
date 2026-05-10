import SwiftUI

@main
struct CoreDesignPreviewApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .toastHost(edge: .top)
        }
    }
}
