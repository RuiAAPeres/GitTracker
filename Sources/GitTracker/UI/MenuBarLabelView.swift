import SwiftUI

struct MenuBarLabelView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        HStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "folder.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.primary)

                if store.breachedCount > 0 {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.yellow, .yellow)
                        .font(.system(size: 8, weight: .bold))
                        .background(
                            Circle()
                                .fill(Color(nsColor: .windowBackgroundColor))
                                .frame(width: 10, height: 10)
                        )
                        .offset(x: 4, y: -4)
                }
            }
            Text(store.menuTitle)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
    }
}
