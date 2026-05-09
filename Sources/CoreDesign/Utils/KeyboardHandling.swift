//
//  KeyboardHandling.swift
//  CoreDesign
//
//  Created by Evan Wang on 2026/4/7.
//

import Combine
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

// MARK: - KeyboardReadable

/// Publisher to read keyboard changes.
public protocol KeyboardReadable {
    var keyboardWillChangePublisher: AnyPublisher<Bool, Never> { get }
    var keyboardDidChangePublisher: AnyPublisher<Bool, Never> { get }
    var keyboardHeight: AnyPublisher<CGFloat, Never> { get }
}

/// Default implementation.
public extension KeyboardReadable {
    var keyboardWillChangePublisher: AnyPublisher<Bool, Never> {
        #if canImport(UIKit)
            Publishers.Merge(
                NotificationCenter.default
                    .publisher(for: UIResponder.keyboardWillShowNotification)
                    .map { _ in true },
                NotificationCenter.default
                    .publisher(for: UIResponder.keyboardWillHideNotification)
                    .map { _ in false }
            )
            .eraseToAnyPublisher()
        #else
            Empty<Bool, Never>().eraseToAnyPublisher()
        #endif
    }

    var keyboardDidChangePublisher: AnyPublisher<Bool, Never> {
        #if canImport(UIKit)
            Publishers.Merge(
                NotificationCenter.default
                    .publisher(for: UIResponder.keyboardDidShowNotification)
                    .map { _ in true },
                NotificationCenter.default
                    .publisher(for: UIResponder.keyboardDidHideNotification)
                    .map { _ in false }
            )
            .eraseToAnyPublisher()
        #else
            Empty<Bool, Never>().eraseToAnyPublisher()
        #endif
    }

    var keyboardHeight: AnyPublisher<CGFloat, Never> {
        #if canImport(UIKit)
            NotificationCenter
                .default
                .publisher(for: UIResponder.keyboardDidShowNotification)
                .map { notification in
                    if
                        let keyboardFrame: NSValue = notification
                            .userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue
                    {
                        let keyboardRectangle = keyboardFrame.cgRectValue
                        return keyboardRectangle.height
                    } else {
                        return 0
                    }
                }
                .eraseToAnyPublisher()
        #else
            Just(0).eraseToAnyPublisher()
        #endif
    }
}

public extension View {
    /// Dismisses the keyboard when tapping on the view.
    /// - Parameters:
    ///   - enabled: If true, tapping on the view dismisses the view, otherwise keyboard stays visible.
    ///   - onTapped: A closure which is triggered when keyboard is dismissed after tapping the view.
    func dismissKeyboardOnTap(enabled: Bool, onKeyboardDismissed: (() -> Void)? = nil) -> some View {
        modifier(HideKeyboardOnTapGesture(shouldAdd: enabled, onTapped: onKeyboardDismissed))
    }
}

// MARK: - HideKeyboardOnTapGesture

/// View modifier for hiding the keyboard on tap.
public struct HideKeyboardOnTapGesture: ViewModifier {
    public init(shouldAdd: Bool, onTapped: (() -> Void)? = nil) {
        self.shouldAdd = shouldAdd
        self.onTapped = onTapped
    }

    public func body(content: Content) -> some View {
        content
            .gesture(self.shouldAdd
                ? TapGesture().onEnded { _ in
                    resignFirstResponder()
                    if let onTapped {
                        onTapped()
                    }
                }
                : nil)
    }

    var shouldAdd: Bool
    var onTapped: (() -> Void)?
}

/// Resigns first responder and hides the keyboard.
@MainActor
public func resignFirstResponder() {
    #if canImport(UIKit)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    #endif
}

public let anyWriterFirstResponderNotification = "io.platform.inputView.becomeFirstResponder"

public func becomeFirstResponder() {
    NotificationCenter.default.post(
        name: NSNotification.Name(anyWriterFirstResponderNotification),
        object: nil
    )
}
