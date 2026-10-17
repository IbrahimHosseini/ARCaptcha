import SwiftUI

/// The slide puzzle: a background with a slot and a piece moved by a slider.
struct PuzzleChallengeView: View {
    @ObservedObject var model: NativeChallengeModel
    let background: UIImage
    let piece: UIImage
    let pieceY: CGFloat

    private let originalSize = NativeProtocol.originalPuzzleSize
    private var maxOffset: CGFloat { max(originalSize.width - piece.size.width, 1) }
    private var appearance: ARCaptchaAppearance { model.configuration.appearance }

    var body: some View {
        VStack(spacing: 18) {
            Color.clear
                .aspectRatio(originalSize.width / originalSize.height, contentMode: .fit)
                .overlay(
                    GeometryReader { proxy in
                        let scale = proxy.size.width / originalSize.width
                        ZStack(alignment: .topLeading) {
                            Image(uiImage: background)
                                .resizable()
                                .frame(width: proxy.size.width, height: proxy.size.height)
                            Image(uiImage: piece)
                                .resizable()
                                .frame(width: piece.size.width * scale, height: piece.size.height * scale)
                                .shadow(color: .black.opacity(0.45), radius: 3)
                                .offset(x: model.puzzleOffset * scale, y: pieceY * scale)
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)

            PuzzleSlider(
                fraction: Binding(
                    get: { model.puzzleOffset / maxOffset },
                    set: { model.puzzleOffset = $0 * maxOffset }
                ),
                appearance: appearance,
                accessibilityLabel: model.strings.puzzleSliderAccessibilityLabel,
                accessibilityHint: model.allowsAudio ? model.strings.switchToAudio : nil,
                onBegan: model.beginPuzzleDrag,
                onEnded: model.endPuzzleDrag
            )
        }
        .frame(maxWidth: 340)
        // The puzzle is measured left to right whatever the language.
        .environment(\.layoutDirection, .leftToRight)
    }
}

/// A track with a draggable thumb, reporting its position from 0 to 1.
struct PuzzleSlider: View {
    @Binding var fraction: CGFloat
    let appearance: ARCaptchaAppearance
    let accessibilityLabel: String
    let accessibilityHint: String?
    let onBegan: () -> Void
    let onEnded: () -> Void

    @State private var dragStartFraction: CGFloat?
    @Environment(\.isEnabled) private var isEnabled
    private let thumbWidth: CGFloat = 60
    private let height: CGFloat = 44

    var body: some View {
        GeometryReader { proxy in
            let travel = max(proxy.size.width - thumbWidth, 1)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(uiColor: appearance.fieldBackgroundColor))
                    .frame(height: 22)
                Capsule()
                    .fill(Color(uiColor: appearance.accentColor).opacity(0.3))
                    .frame(width: thumbWidth / 2 + fraction * travel, height: 22)
                RoundedRectangle(cornerRadius: min(appearance.cornerRadius, 14), style: .continuous)
                    .fill(Color(uiColor: appearance.accentColor))
                    .frame(width: thumbWidth, height: height)
                    .overlay(
                        Image(systemName: "arrow.right")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                    .offset(x: fraction * travel)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if dragStartFraction == nil {
                                    dragStartFraction = fraction
                                    onBegan()
                                }
                                let start = dragStartFraction ?? 0
                                fraction = min(max(start + value.translation.width / travel, 0), 1)
                            }
                            .onEnded { _ in
                                guard dragStartFraction != nil else { return }
                                dragStartFraction = nil
                                onEnded()
                            }
                    )
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: height)
        .opacity(isEnabled ? 1 : 0.6)
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(Text("\(Int((fraction * 100).rounded()))%"))
        .accessibilityHint(accessibilityHint.map { Text($0) } ?? Text(""))
    }
}
