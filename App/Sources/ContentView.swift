import SwiftUI
import CoreDesign

struct ContentView: View {
    @State private var selectedComponent: ComponentMeta?

    var body: some View {
        NavigationSplitView {
            ComponentList(selection: self.$selectedComponent)
        } detail: {
            if let comp = self.selectedComponent {
                ComponentDetail(component: comp)
            } else {
                PlaceholderView()
            }
        }
    }
}

// MARK: - ComponentList

private struct ComponentList: View {
    @Binding var selection: ComponentMeta?

    var body: some View {
        List(selection: self.$selection) {
            ForEach(ComponentCategory.allCases, id: \.self) { category in
                let items = ComponentMeta.all.filter { $0.category == category }
                if !items.isEmpty {
                    Section(category.rawValue) {
                        ForEach(items) { comp in
                            NavigationLink(value: comp) {
                                ComponentRow(component: comp)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("CoreDesign")
        .navigationDestination(for: ComponentMeta.self) { comp in
            ComponentDetail(component: comp)
        }
        .background(Color.surfaceCanvas)
    }
}

// MARK: - ComponentRow

private struct ComponentRow: View {
    let component: ComponentMeta

    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.xxs) {
            Text(component.name)
                .font(CoreTypography.bodyMediumFont)
                .foregroundStyle(Color.contentPrimary)
            Text(component.id)
                .font(CoreTypography.bodySmallFont)
                .foregroundStyle(Color.contentMuted)
        }
    }
}

// MARK: - PlaceholderView

private struct PlaceholderView: View {
    var body: some View {
        VStack(spacing: CoreSpacing.md) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 48))
                .foregroundStyle(Color.contentMuted)
            Text("Select a component")
                .font(CoreTypography.bodyMediumFont)
                .foregroundStyle(Color.contentMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.surfaceCanvas)
    }
}
