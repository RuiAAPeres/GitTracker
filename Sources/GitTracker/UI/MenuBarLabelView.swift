import SwiftUI

struct MenuBarLabelView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        ZStack {
            Image(systemName: "folder")
                .font(.system(size: 14, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.primary)

            Image(systemName: store.breachedCount > 0 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.system(size: 8, weight: .bold))
                .offset(x: 6, y: 5)
        }
        .frame(width: 20, height: 16)
    }
}
