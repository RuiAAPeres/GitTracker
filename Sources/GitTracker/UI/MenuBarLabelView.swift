import SwiftUI

struct MenuBarLabelView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        Image(nsImage: MenuBarStatusIcon.image(breached: store.breachedCount > 0))
            .renderingMode(.original)
    }
}
