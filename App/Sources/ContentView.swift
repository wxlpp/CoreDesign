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

    private let grouped: [ComponentCategory: [ComponentMeta]] = {
        Dictionary(grouping: ComponentMeta.all, by: \.category)
    }()

    var body: some View {
        List(selection: self.$selection) {
            ForEach(ComponentCategory.allCases, id: \.self) { category in
                if let items = self.grouped[category], !items.isEmpty {
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
        .listStyle(.sidebar)
        .navigationTitle("CoreDesign")
        .navigationDestination(for: ComponentMeta.self) { comp in
            ComponentDetail(component: comp)
        }
        .scrollContentBackground(.hidden)
        .background(Color.surfaceSidebar)
    }
}

// MARK: - ComponentRow

private struct ComponentRow: View {
    let component: ComponentMeta

    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.xxs) {
            Text(component.name)
                .font(CoreTypography.bodyMediumFont)
                .fontWeight(.medium)
                .foregroundStyle(Color.contentPrimary)
            Text(component.id)
                .font(CoreTypography.captionFont)
                .foregroundStyle(Color.contentSubtle)
        }
        .padding(.vertical, CoreSpacing.xxs)
    }
}

// MARK: - PlaceholderView

private struct PlaceholderView: View {
    var body: some View {
        VStack(spacing: CoreSpacing.sm) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 32, weight: .regular))
                .foregroundStyle(Color.contentSubtle)
                .accessibilityHidden(true)
            Text("Select a component")
                .font(CoreTypography.bodyMediumFont)
                .foregroundStyle(Color.contentMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.surfaceCanvas)
    }
}
