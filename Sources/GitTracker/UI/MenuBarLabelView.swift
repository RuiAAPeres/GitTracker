import SwiftUI

struct MenuBarLabelView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: store.breachedCount > 0 ? "exclamationmark.triangle.fill" : "line.3.horizontal.decrease.circle")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(store.breachedCount > 0 ? .orange : .primary)
            Text(store.menuTitle)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
    }
}
