import SwiftUI

/// The native challenge: instructions, the challenge itself and a footer with actions.
struct NativeChallengeCard: View {
    @ObservedObject var model: NativeChallengeModel
    @ObservedObject var audioPlayer: AudioPlayer
    @State private var showsHelp = false

    init(model: NativeChallengeModel) {
        self.model = model
        self.audioPlayer = model.audioPlayer
    }

    private var appearance: ARCaptchaAppearance { model.configuration.appearance }
    private var strings: ARCaptchaStrings { model.strings }

    var body: some View {
        VStack(spacing: 14) {
            header
            content
                .frame(maxWidth: .infinity)
                .frame(minHeight: model.challenge == nil ? 220 : nil)
            footer
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: appearance.cornerRadius, style: .continuous)
                .fill(Color(uiColor: appearance.backgroundColor))
        )
        .environment(\.layoutDirection, model.configuration.language.isRightToLeft ? .rightToLeft : .leftToRight)
        .tint(Color(uiColor: appearance.accentColor))
        .alert(strings.help, isPresented: $showsHelp) {
            Button(strings.ok, role: .cancel) {}
        } message: {
            Text(helpText)
        }
        .animation(.easeInOut(duration: 0.2), value: model.phase)
    }

    // MARK: Header

    @ViewBuilder
    private var header: some View {
        Group {
            switch model.challenge?.kind {
            case let .imageSelection(category, _):
                instructionText(category: category)
            case .puzzle:
                Text(strings.puzzleInstruction)
            case .audio:
                Text(strings.audioInstruction)
            case nil:
                Text(model.mode == .audio ? strings.audioInstruction : " ")
            }
        }
        .font(appearance.font(.headline, size: 17, weight: .semibold))
        .foregroundColor(Color(uiColor: appearance.primaryTextColor))
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .accessibilityAddTraits(.isHeader)
    }

    private func instructionText(category: String) -> Text {
        let parts = strings.imageSelectionInstruction.components(separatedBy: "%@")
        guard parts.count == 2 else { return Text(strings.imageSelectionInstruction) }
        return Text(parts[0])
            + Text(category).foregroundColor(Color(uiColor: appearance.accentColor)).bold()
            + Text(parts[1])
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .failed:
            failure
        case .loading where model.challenge == nil:
            ProgressView()
                .accessibilityLabel(strings.loading)
        default:
            if let challenge = model.challenge {
                challengeView(challenge)
                    .disabled(!model.isInteractive)
                    .overlay {
                        if model.phase == .submitting || model.phase == .loading {
                            ProgressView().accessibilityLabel(strings.loading)
                        }
                    }
                    .overlay(alignment: .bottom) { feedback }
            }
        }
    }

    @ViewBuilder
    private func challengeView(_ challenge: NativeChallenge) -> some View {
        switch challenge.kind {
        case let .imageSelection(_, images):
            ImageSelectionChallengeView(model: model, images: images)
        case let .puzzle(background, piece, pieceY):
            PuzzleChallengeView(model: model, background: background, piece: piece, pieceY: pieceY)
        case .audio:
            AudioChallengeView(model: model, isPlaying: audioPlayer.isPlaying)
        }
    }

    @ViewBuilder
    private var feedback: some View {
        if model.phase == .solved || model.phase == .rejected {
            let solved = model.phase == .solved
            Label(solved ? strings.solved : strings.wrongAnswer, systemImage: solved ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(appearance.font(.subheadline, size: 15, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(uiColor: solved ? appearance.successColor : appearance.errorColor))
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .accessibilityAddTraits(.updatesFrequently)
                .onAppear {
                    UIAccessibility.post(notification: .announcement, argument: solved ? strings.solved : strings.wrongAnswer)
                }
        }
    }

    private var failure: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundColor(Color(uiColor: appearance.errorColor))
                .accessibilityHidden(true)
            Text(strings.loadFailed)
                .font(appearance.font(.body, size: 16))
                .foregroundColor(Color(uiColor: appearance.primaryTextColor))
                .multilineTextAlignment(.center)
            Button(strings.retry) { model.load() }
                .buttonStyle(PrimaryButtonStyle(appearance: appearance))
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 6) {
            if appearance.showsBranding {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(Color(uiColor: appearance.accentColor))
                    Text(strings.brandName)
                        .font(appearance.font(.footnote, size: 13, weight: .semibold))
                        .foregroundColor(Color(uiColor: appearance.secondaryTextColor))
                }
                .accessibilityElement(children: .combine)
            }
            Spacer(minLength: 0)
            FooterButton(systemImage: "questionmark.circle", label: strings.help, appearance: appearance) {
                showsHelp = true
            }
            if model.allowsAudio {
                FooterButton(
                    systemImage: model.mode == .audio ? "photo" : "speaker.wave.2",
                    label: model.mode == .audio ? strings.switchToVisual : strings.switchToAudio,
                    appearance: appearance
                ) {
                    model.switchMode()
                }
                .disabled(model.phase == .submitting)
            }
            FooterButton(systemImage: "arrow.clockwise", label: strings.refresh, appearance: appearance) {
                model.load()
            }
            .disabled(model.phase == .submitting || model.phase == .loading)
        }
    }

    private var helpText: String {
        switch model.challenge?.type {
        case .imageSelection: strings.imageSelectionHelp
        case .puzzle: strings.puzzleHelp
        case .audio: strings.audioHelp
        case nil: model.mode == .audio ? strings.audioHelp : strings.imageSelectionHelp
        }
    }
}

struct FooterButton: View {
    let systemImage: String
    let label: String
    let appearance: ARCaptchaAppearance
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(Color(uiColor: appearance.secondaryTextColor))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    let appearance: ARCaptchaAppearance
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(appearance.font(.body, size: 16, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: min(appearance.cornerRadius, 12), style: .continuous)
                    .fill(Color(uiColor: appearance.accentColor))
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
    }
}
