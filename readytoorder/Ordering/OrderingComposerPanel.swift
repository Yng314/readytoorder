import Observation
import SwiftUI

struct OrderingComposerPanel: View {
    let viewModel: OrderingChatViewModel
    let outerContainerCornerRadius: CGFloat
    let contentInsetFromOuterCard: CGFloat
    let onToggleAttachmentDrawer: () -> Void

    @FocusState private var isComposerFocused: Bool

    private enum ComposerMetrics {
        static let outerControlHeight: CGFloat = 38
        static let sendButtonSize: CGFloat = 28
    }

    private var hasAttachments: Bool {
        !viewModel.attachments.isEmpty
    }

    private var canSendNow: Bool {
        if hasAttachments {
            return !viewModel.isSending
        }
        return !viewModel.isSending && !viewModel.trimmedDraftText.isEmpty
    }

    var body: some View {
        @Bindable var bindableViewModel = viewModel

        VStack(spacing: 12) {
            if !viewModel.attachments.isEmpty {
                attachmentStrip
            }

            composerControls(draftText: $bindableViewModel.draftText)
        }
    }

    @ViewBuilder
    private func composerControls(draftText: Binding<String>) -> some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: 12) {
                composerRow(draftText: draftText)
            }
        } else {
            composerRow(draftText: draftText)
        }
    }

    private func composerRow(draftText: Binding<String>) -> some View {
        HStack(alignment: .bottom, spacing: 12) {
            attachmentButton

            composerInputCapsule(draftText: draftText)
        }
    }

    private var attachmentButton: some View {
        Button {
            isComposerFocused = false
            onToggleAttachmentDrawer()
        } label: {
            Image(systemName: "plus")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color(red: 0.26, green: 0.25, blue: 0.32))
                .frame(width: ComposerMetrics.outerControlHeight, height: ComposerMetrics.outerControlHeight)
                .contentShape(Circle())
                .modifier(OrderingGlassCircleStyle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isSending || viewModel.remainingAttachmentSlots <= 0)
        .opacity(viewModel.isSending || viewModel.remainingAttachmentSlots <= 0 ? 0.48 : 1.0)
    }

    private func composerInputCapsule(draftText: Binding<String>) -> some View {
        HStack(spacing: 10) {
            TextField("发送菜单推荐菜品...", text: draftText, axis: .vertical)
                .lineLimit(1...4)
                .focused($isComposerFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(false)
                .font(.body.weight(.medium))
                .foregroundStyle(Color(red: 0.26, green: 0.25, blue: 0.32))
                .submitLabel(.send)
                .onSubmit(sendPrimaryAction)
                .frame(maxWidth: .infinity, alignment: .leading)

            sendButton
        }
        .padding(.leading, 18)
        .padding(.trailing, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, minHeight: ComposerMetrics.outerControlHeight, alignment: .leading)
        .modifier(OrderingGlassCapsuleStyle())
    }

    private var sendButton: some View {
        Button(action: sendPrimaryAction) {
            Image(systemName: "arrow.up")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: ComposerMetrics.sendButtonSize, height: ComposerMetrics.sendButtonSize)
                .background(
                    Circle()
                        .fill(canSendNow ? Color.black.opacity(0.92) : Color.black.opacity(0.28))
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!canSendNow)
    }

    private var attachmentStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(viewModel.attachments) { attachment in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: attachment.previewImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 84, height: 84)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(.white.opacity(0.72), lineWidth: 1)
                            )

                        Button {
                            viewModel.removeAttachment(id: attachment.id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 19))
                                .foregroundStyle(.white, Color.black.opacity(0.45))
                        }
                        .offset(x: 7, y: -7)
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 2)
        }
        .padding(.horizontal, 2)
    }

    private func sendPrimaryAction() {
        isComposerFocused = false
        if hasAttachments {
            viewModel.sendRecommend()
        } else {
            viewModel.sendChat()
        }
    }
}

private struct OrderingGlassCircleStyle: ViewModifier {
    func body(content: Content) -> some View {
        Group {
            if #available(iOS 26, *) {
                content
                    .glassEffect(
                        .regular.tint(Color.white.opacity(0.04)).interactive(),
                        in: .circle
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.28), lineWidth: 1)
                    )
            } else {
                content
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.74), lineWidth: 1)
                    )
            }
        }
    }
}

private struct OrderingGlassCapsuleStyle: ViewModifier {
    func body(content: Content) -> some View {
        Group {
            if #available(iOS 26, *) {
                content
                    .glassEffect(
                        .regular.tint(Color.white.opacity(0.04)).interactive(),
                        in: .capsule
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.28), lineWidth: 1)
                    )
            } else {
                content
                    .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.74), lineWidth: 1)
                    )
            }
        }
    }
}
