import SwiftUI

struct MenuBarLabelView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(systemName: "folder.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.primary)

            Circle()
                .fill(store.breachedCount > 0 ? Color(nsColor: .systemYellow) : Color(nsColor: .systemGreen))
                .frame(width: 10, height: 10)
                .overlay {
                    Image(systemName: store.breachedCount > 0 ? "exclamationmark" : "checkmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(store.breachedCount > 0 ? .black : .white)
                }
                .overlay {
                    Circle()
                        .stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 1)
                }
                .offset(x: 4, y: 3)
        }
    }
}
