import SwiftUI

/// A 3×3 grid of images to pick from.
struct ImageSelectionChallengeView: View {
    @ObservedObject var model: NativeChallengeModel
    let images: [UIImage]

    private var appearance: ARCaptchaAppearance { model.configuration.appearance }
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

    var body: some View {
        VStack(spacing: 14) {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(images.indices, id: \.self) { index in
                    tile(index)
                }
            }
            .frame(maxWidth: 340)
            // Image order is part of the answer, so the grid never mirrors.
            .environment(\.layoutDirection, .leftToRight)

            // Some challenges have no matching image, so an empty selection is a valid answer.
            Button(model.strings.confirm, action: model.submitImageSelection)
                .buttonStyle(PrimaryButtonStyle(appearance: appearance))
        }
    }

    private func tile(_ index: Int) -> some View {
        let isSelected = model.selection.contains(index)
        return Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                Image(uiImage: images[index])
                    .resizable()
                    .scaledToFill()
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(uiColor: appearance.accentColor), lineWidth: isSelected ? 3 : 0)
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white, Color(uiColor: appearance.accentColor))
                        .padding(4)
                }
            }
            .scaleEffect(isSelected ? 0.92 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
            .contentShape(Rectangle())
            .onTapGesture { model.toggleImage(index) }
            .accessibilityElement()
            .accessibilityLabel(String(format: model.strings.imageAccessibilityLabel, index + 1, images.count))
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction { model.toggleImage(index) }
    }
}
