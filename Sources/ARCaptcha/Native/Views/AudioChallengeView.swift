import SwiftUI

/// An audio clip to listen to and a field for what was heard.
struct AudioChallengeView: View {
    @ObservedObject var model: NativeChallengeModel
    let isPlaying: Bool
    @State private var isFieldFocused = false

    private var appearance: ARCaptchaAppearance { model.configuration.appearance }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Button(action: model.toggleAudioPlayback) {
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 52, height: 52)
                        .background(Circle().fill(Color(appearance.accentColor)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPlaying ? model.strings.stopAudio : model.strings.playAudio)

                TextField(
                    model.strings.audioPlaceholder,
                    text: $model.audioAnswer,
                    onEditingChanged: { isFieldFocused = $0 },
                    onCommit: model.submitAudioAnswer
                )
                .font(appearance.font(.body, size: 17))
                .foregroundColor(Color(appearance.primaryTextColor))
                .answerKeyboard()
                .disableAutocorrection(true)
                .padding(.horizontal, 14)
                .frame(minHeight: 52)
                .background(
                    RoundedRectangle(cornerRadius: min(appearance.cornerRadius, 12), style: .continuous)
                        .fill(Color(appearance.fieldBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: min(appearance.cornerRadius, 12), style: .continuous)
                        .stroke(Color(appearance.accentColor), lineWidth: isFieldFocused ? 1.5 : 0)
                )
            }
            .frame(maxWidth: 340)

            Button(model.strings.confirm, action: model.submitAudioAnswer)
                .buttonStyle(PrimaryButtonStyle(appearance: appearance))
                .disabled(model.audioAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}

private extension View {
    /// No capitalization and a Done key. iOS 14 has no `submitLabel`, so it keeps the Return key there.
    @ViewBuilder
    func answerKeyboard() -> some View {
        if #available(iOS 15.0, *) {
            textInputAutocapitalization(.never).submitLabel(.done)
        } else {
            autocapitalization(.none)
        }
    }
}
