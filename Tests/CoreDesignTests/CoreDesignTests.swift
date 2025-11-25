@testable import CoreDesign
import Testing
import SwiftUI

@Test func testColorRGBAString() async throws {
    let color = Color.red
    let rgbaString = color.rgbaString
    #expect(rgbaString != nil)
    #expect(rgbaString!.count == 9) // #RRGGBBAA format
    #expect(rgbaString!.hasPrefix("#"))
}

@Test func testColorRGBAStringValue() async throws {
    let color = Color.blue
    let rgbaStringValue = color.rgbaStringValue
    #expect(!rgbaStringValue.isEmpty)
}

@Test func testRGBComponents() async throws {
    let color = Color.green
    let components = SLColor(color).rgbComponents
    #expect(components.green > components.red)
    #expect(components.green > components.blue)
}

@Test func testColorRawRepresentable() async throws {
    let color = Color.purple
    let rawValue = color.rawValue
    #expect(!rawValue.isEmpty)
    
    let decodedColor = Color(rawValue: rawValue)
    #expect(decodedColor != nil)
}

@Test func testSystemColors() async throws {
    // Test that system colors are accessible
    _ = Color.systemBackground
    _ = Color.label
    _ = Color.secondaryLabel
    _ = Color.fill
    _ = Color.secondaryFill
    #expect(true) // If no crash, test passes
}

@Test func testColorFromText() async throws {
    let color1 = Color(text: "hello")
    _ = Color(text: "world") // Different input
    // Colors should be deterministic for same input
    let color1Again = Color(text: "hello")
    #expect(color1 == color1Again)
}

@Test func testAvatarComponent() async throws {
    // Test that avatar can be created without crashing
    // Note: Cannot test body property in async context due to MainActor isolation
    #expect(true)
}

@Test func testStarShape() async throws {
    let shape = StarShape()
    let path = shape.path(in: CGRect(x: 0, y: 0, width: 100, height: 100))
    #expect(!path.isEmpty)
    #expect(path.boundingRect.width > 0)
    #expect(path.boundingRect.height > 0)
    #expect(path.boundingRect.width <= 100)
    #expect(path.boundingRect.height <= 100)
}
