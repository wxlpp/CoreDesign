import SwiftUI

public extension View {
    /// `trigger` 变化时播一次触感反馈。
    func haptic(
        _ feedback: SensoryFeedback,
        trigger: some Equatable
    ) -> some View {
        self.sensoryFeedback(feedback, trigger: trigger)
    }
}

#Preview("haptic") {
    @Previewable @State var taps = 0
    VStack(spacing: 24) {
        Text(verbatim: "taps: \(taps)")
        Button("播一次 .success") { taps += 1 }
            .haptic(.success, trigger: taps)
    }
    .padding()
}
