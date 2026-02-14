import SwiftUI

struct MenuBarLabelView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        ZStack {
            Image(systemName: "folder.fill")
                .font(.system(size: 13, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.primary)

            Circle()
                .fill(store.breachedCount > 0 ? Color(nsColor: .systemYellow) : Color(nsColor: .systemGreen))
                .frame(width: 11, height: 11)
                .overlay {
                    Image(systemName: store.breachedCount > 0 ? "exclamationmark" : "checkmark")
                        .font(.system(size: 7, weight: .black))
                        .foregroundStyle(store.breachedCount > 0 ? .black : .white)
                }
                .overlay {
                    Circle()
                        .stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 1)
                }
                .offset(x: 5, y: 5)
        }
        .frame(width: 18, height: 16)
    }
}
