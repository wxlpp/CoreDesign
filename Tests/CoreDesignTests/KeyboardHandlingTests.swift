import Combine
import Foundation
import Testing
@testable import CoreDesign

@Suite("KeyboardHandling")
struct KeyboardHandlingTests {
    @Test("keyboard height publisher emits show, frame change, and hide values")
    func keyboardHeightPublisherTracksFullLifecycle() {
        let show = PassthroughSubject<Notification, Never>()
        let hide = PassthroughSubject<Notification, Never>()
        let changeFrame = PassthroughSubject<Notification, Never>()
        var received: [CGFloat] = []

        let cancellable = KeyboardHeightPublisherFactory.make(
            show: show.eraseToAnyPublisher(),
            hide: hide.eraseToAnyPublisher(),
            changeFrame: changeFrame.eraseToAnyPublisher(),
            frameEndUserInfoKey: "frame"
        )
        .sink { received.append($0) }

        show.send(Self.notification(height: 216))
        changeFrame.send(Self.notification(height: 180))
        hide.send(Notification(name: Notification.Name("hide")))

        #expect(received == [216, 180, 0])
        withExtendedLifetime(cancellable) {}
    }

    @Test("keyboard height parsing falls back to zero when frame is missing")
    func keyboardHeightParsingFallsBackToZero() {
        let notification = Notification(name: Notification.Name("show"))
        #expect(
            KeyboardHeightPublisherFactory.height(
                from: notification,
                frameEndUserInfoKey: "frame"
            ) == 0
        )
    }

    private static func notification(height: CGFloat) -> Notification {
        Notification(
            name: Notification.Name("show"),
            userInfo: ["frame": Self.frameValue(height: height)]
        )
    }

    private static func frameValue(height: CGFloat) -> NSValue {
        #if canImport(UIKit)
            NSValue(cgRect: CGRect(x: 0, y: 0, width: 320, height: height))
        #elseif canImport(AppKit)
            NSValue(rect: CGRect(x: 0, y: 0, width: 320, height: height))
        #else
            NSValue()
        #endif
    }
}
