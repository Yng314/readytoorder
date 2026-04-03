import SwiftUI

struct OrderingComposerDock: View {
    let featureModel: OrderingFeatureModel

    var body: some View {
        OrderingComposerPanel(
            viewModel: featureModel.chatViewModel,
            outerContainerCornerRadius: 30,
            contentInsetFromOuterCard: 0,
            onToggleAttachmentDrawer: {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                    featureModel.toggleAttachmentDrawer()
                }
            }
        )
    }
}
