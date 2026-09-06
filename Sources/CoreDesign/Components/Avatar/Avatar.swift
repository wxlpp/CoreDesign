import SwiftUI

// MARK: - Avatar

/// **材质层**: 内容. **表面角色**: 内容.
public struct Avatar: View {
    public init(name: String) {
        self.name = name
    }

    private static let canvasSide: CGFloat = CoreSpacing.xxxxl

    public var body: some View {
        let size = CGSize(width: Self.canvasSide, height: Self.canvasSide)
        let firstCharacter = String(name.prefix(1).uppercased())

        Image(size: size, label: Text(self.name)) { context in
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Color(text: self.name))
            )
            context.draw(
                Text(firstCharacter)
                    .font(CoreTypography.Token.title.font.weight(.bold))
                    .foregroundStyle(Color.white),
                at: CGPoint(x: size.width / 2, y: size.height / 2)
            )
        }
        .resizable()
        .aspectRatio(contentMode: .fill)
    }

    let name: String
}

#Preview {
    Avatar(name: "A").frame(width: 100, height: 100).clipShape(Circle())
}
