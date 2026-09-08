import Foundation
import SwiftUI
import Testing
@testable import OhMyDesign

// MARK: - asset catalog 取色的「解析得出来吗」守卫 / Asset-catalog color resolvability (Issue #275)

private nonisolated func resourceBundleHas(_ name: String) -> Bool {
    guard let root = Bundle.module.resourceURL else { return false }
    return FileManager.default.fileExists(atPath: root.appendingPathComponent(name).path)
}

private nonisolated var assetCatalogIsCompiled: Bool {
    resourceBundleHas("Assets.car")
}

private nonisolated var assetCatalogIsRawDirectoryOnly: Bool {
    !assetCatalogIsCompiled && resourceBundleHas("Resources.xcassets")
}

@Suite("asset catalog 取色的解析可用性")
struct ColorGradeResolutionGuard {
    private nonisolated static func env(_ scheme: ColorScheme) -> EnvironmentValues {
        var e = EnvironmentValues()
        e.colorScheme = scheme
        return e
    }

    // MARK: - 抽样面

    private static var hueSamples: [(String, Color)] {
        [
            ("brand5", .brand5), ("amber5", .amber5), ("blue5", .blue5),
            ("cyan5", .cyan5), ("green5", .green5), ("grey5", .grey5),
            ("indigo5", .indigo5), ("lightBlue5", .lightBlue5),
            ("lightGreen5", .lightGreen5), ("lime5", .lime5),
            ("orange5", .orange5), ("pink5", .pink5), ("purple5", .purple5),
            ("red5", .red5), ("teal5", .teal5), ("violet5", .violet5),
            ("yellow5", .yellow5),
        ]
    }

    private static var statusSamples: [(String, Color)] {
        [
            ("statusAccentForeground", .statusAccentForeground),
            ("statusAccentEmphasis", .statusAccentEmphasis),
            ("statusAccentMuted", .statusAccentMuted),
            ("statusAccentSubtle", .statusAccentSubtle),
            ("statusAccentBorder", .statusAccentBorder),
            ("statusSuccessForeground", .statusSuccessForeground),
            ("statusSuccessEmphasis", .statusSuccessEmphasis),
            ("statusSuccessMuted", .statusSuccessMuted),
            ("statusSuccessSubtle", .statusSuccessSubtle),
            ("statusSuccessBorder", .statusSuccessBorder),
            ("statusAttentionForeground", .statusAttentionForeground),
            ("statusAttentionEmphasis", .statusAttentionEmphasis),
            ("statusAttentionMuted", .statusAttentionMuted),
            ("statusAttentionSubtle", .statusAttentionSubtle),
            ("statusAttentionBorder", .statusAttentionBorder),
            ("statusDangerForeground", .statusDangerForeground),
            ("statusDangerEmphasis", .statusDangerEmphasis),
            ("statusDangerMuted", .statusDangerMuted),
            ("statusDangerSubtle", .statusDangerSubtle),
            ("statusDangerBorder", .statusDangerBorder),
            ("statusDoneForeground", .statusDoneForeground),
            ("statusDoneEmphasis", .statusDoneEmphasis),
            ("statusDoneMuted", .statusDoneMuted),
            ("statusDoneSubtle", .statusDoneSubtle),
        ]
    }

    private static var shadowSamples: [(String, Color)] {
        [CoreElevation.Level.small, .medium, .large].map { level in
            ("CoreElevation.spec(for: .\(level)).color", CoreElevation.spec(for: level).color)
        }
    }

    private static var samples: [(String, Color)] {
        hueSamples + statusSamples + shadowSamples
    }

    @Test("抽样面必须覆盖三组、且基数与登记相符")
    func sampleBasisHasExpectedCardinality() {
        #expect(
            Self.hueSamples.count == 17,
            "色相抽样应为 17（17 色相各一档），实为 \(Self.hueSamples.count)"
        )
        #expect(
            Self.statusSamples.count == 24,
            "status 抽样应为 24（全量），实为 \(Self.statusSamples.count)"
        )
        #expect(
            Self.shadowSamples.count == 3,
            "shadow 抽样应为 3（4 档去掉设计上全透明的 shadow-none），实为 \(Self.shadowSamples.count)"
        )
        let names = Set(Self.samples.map(\.0))
        #expect(
            names.count == 44,
            "抽样合计（按名字去重）应为 44（共 198 个 catalog 取色常量中），实为 \(names.count)"
        )
        for (group, entries) in [
            ("色相", Self.hueSamples), ("status", Self.statusSamples), ("shadow", Self.shadowSamples),
        ] {
            let missing = entries.map(\.0).filter { !names.contains($0) }
            #expect(
                missing.isEmpty,
                "\(group) 组有 \(missing.count) 个没进 samples：\(missing.joined(separator: ", "))"
            )
        }
    }

    // MARK: - label ↔ 取值 的同源核对

    private static func kebabCased(_ label: String) -> String {
        var out = ""
        for ch in label {
            if ch.isUppercase {
                out += "-" + ch.lowercased()
            } else if ch.isNumber {
                out += "-" + String(ch)
            } else {
                out.append(ch)
            }
        }
        return out
    }

    private static func statusAssetName(_ label: String) -> String {
        let kebab = Self.kebabCased(label)
        guard kebab.hasSuffix("-foreground") else { return kebab }
        return kebab.replacingOccurrences(of: "-foreground", with: "-fg")
    }

    private static func shadowAssetName(_ label: String) -> String? {
        guard let head = label.range(of: "for: ."),
              let tail = label[head.upperBound...].firstIndex(of: ")")
        else { return nil }
        return "shadow-" + label[head.upperBound..<tail]
    }

    private static var labelToAssetName: [(label: String, expected: String, color: Color)] {
        Self.hueSamples.map { ($0.0, Self.kebabCased($0.0), $0.1) }
            + Self.statusSamples.map { ($0.0, Self.statusAssetName($0.0), $0.1) }
            + Self.shadowSamples.map {
                ($0.0, Self.shadowAssetName($0.0) ?? "<label 里抠不出档位名>", $0.1)
            }
    }

    @Test("抽样的 label 必须与取值同源")
    func sampleLabelsMatchTheirColors() {
        let table = Self.labelToAssetName
        #expect(table.count == 44, "对表面应覆盖全部 44 个抽样，实为 \(table.count)")
        for entry in table {
            guard let actual = assetName(of: entry.color) else {
                Issue.record(
                    """
                    \(entry.label)：`String(describing:)` 里抠不出 asset 名——\
                    `NamedColor(name: "…")` 这个 description 形状被 SDK 换掉了。\
                    本条判据已失去内省依据，**先回来重读 `assetName(of:)` 的注释**再动它，\
                    别让它静默退化成空转。实际 description = \(String(describing: entry.color))
                    """
                )
                continue
            }
            #expect(
                actual == entry.expected,
                """
                \(entry.label) 的取值实际指向 asset `\(actual)`，而 label 推出的是 \
                `\(entry.expected)`——名字与取值不同源，这条抽样的失败信息会指错 token。
                """
            )
        }
    }

    @Test("bundle 必须呈现 Assets.car 或原样 xcassets 之一")
    func catalogFormIsDetectable() {
        #expect(
            assetCatalogIsCompiled || assetCatalogIsRawDirectoryOnly,
            """
            资源 bundle 里既没有 Assets.car 也没有 Resources.xcassets/——\
            那 198 个走 catalog 查找的 token 会静默 fallback，\
            而本文件的两条分叉判据会双双跳过。\
            resourceURL = \(Bundle.module.resourceURL?.path ?? "nil")
            """
        )
    }

    @Test(
        "编译后的 asset catalog 上，抽样的 catalog 取色必须解析为非全透明",
        .enabled(
            if: assetCatalogIsCompiled,
            """
            跳过：本次构建的 bundle 里没有 Assets.car（`actool` 没跑）。\
            SwiftPM native 构建（`swift build` / `swift test`）就是这种情形——\
            catalog 取色**必然**解析为 (0,0,0,0)，正向断言在这条腿上无意义。\
            要覆盖这一条，跑 iOS Simulator 腿（xcodebuild -scheme OhMyDesign-Package）\
            或 `swift test --build-system swiftbuild`。此时改由同文件的\
            `catalogColorsAreFullyTransparentOnRawXcassets` 钉住反向事实。
            """
        )
    )
    func catalogColorsResolveOpaqueOnCompiledCatalog() {
        for scheme in [ColorScheme.light, .dark] {
            let e = Self.env(scheme)
            for (name, color) in Self.samples {
                let r = color.resolve(in: e)
                #expect(
                    r.opacity > 0,
                    "\(scheme)：\(name) 解析为 α=\(r.opacity)——编译后的 catalog 里查不到它，asset 名多半错了"
                )
            }
        }
    }

    @Test(
        "原样拷贝的 xcassets 上，抽样的 catalog 取色恒为全透明（钉住 macOS 腿的盲区）",
        .enabled(
            if: assetCatalogIsRawDirectoryOnly,
            """
            跳过：本次构建的 bundle 里有 Assets.car，`actool` 跑过 \
            ⇒ catalog 取色能正常解析，反向钉子不适用。此时由同文件的 \
            `catalogColorsResolveOpaqueOnCompiledCatalog` 正向覆盖。
            """
        )
    )
    func catalogColorsAreFullyTransparentOnRawXcassets() {
        for scheme in [ColorScheme.light, .dark] {
            let e = Self.env(scheme)
            for (name, color) in Self.samples {
                let r = color.resolve(in: e)
                #expect(
                    r.opacity == 0,
                    """
                    \(scheme)：\(name) 解析出了 α=\(r.opacity)——SwiftPM native 腿\
                    竟然能解析 asset 色了。这是好消息，但 `CLAUDE.md`《验证边界与常见坑》\
                    与本文件顶部那张表已经过期，先改文档再删这条判据。
                    """
                )
            }
        }
    }
}
