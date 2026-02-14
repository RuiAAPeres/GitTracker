import SwiftUI

struct MenuBarLabelView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(systemName: "folder")
                .font(.system(size: 14, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.primary)

            Image(systemName: store.breachedCount > 0 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.system(size: 8, weight: .bold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(
                    store.breachedCount > 0 ? Color(nsColor: .systemYellow) : Color(nsColor: .systemGreen),
                    store.breachedCount > 0 ? Color(nsColor: .systemYellow) : Color(nsColor: .systemGreen)
                )
                .background(
                    Circle()
                        .fill(Color(nsColor: .windowBackgroundColor))
                        .frame(width: 9, height: 9)
                )
                .offset(x: 1, y: 1)
        }
        .frame(width: 20, height: 16, alignment: .center)
    }
}
