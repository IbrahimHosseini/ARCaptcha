import SwiftUI
import UIKit

/// Shows the native challenge as a card in the verification overlay.
@MainActor
final class NativeChallengeRenderer: ChallengeRenderer {
    let viewController: UIViewController
    let hidesContentUntilPresented = true
    var output: ((RendererOutput) -> Void)? {
        didSet { connect() }
    }

    private let model: NativeChallengeModel
    private var hasPresented = false

    init(configuration: ARCaptchaConfiguration, session: URLSession = .shared) {
        model = NativeChallengeModel(configuration: configuration, isEmbedded: false, session: session)
        let host = UIHostingController(rootView: NativeOverlayContent(model: model))
        host.view.backgroundColor = .clear
        viewController = host
    }

    func start() {
        model.startIfNeeded()
    }

    func stop() {
        model.stop()
    }

    private func connect() {
        model.onEvent = { [weak self] event in self?.output?(.event(event)) }
        model.onChallengeReady = { [weak self] in
            guard let self, !self.hasPresented else { return }
            self.hasPresented = true
            self.output?(.needsPresentation)
        }
        model.onSolved = { [weak self] token in self?.output?(.solved(token)) }
        model.onFailure = { [weak self] error in self?.output?(.failed(error)) }
    }
}

/// Centers the card on screen, below the overlay's close button and above the keyboard.
/// The theme reaches it through the overlay window's interface style.
struct NativeOverlayContent: View {
    let model: NativeChallengeModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 56)
            NativeChallengeCard(model: model)
                .frame(maxWidth: 380)
                .shadow(color: .black.opacity(0.2), radius: 20, y: 8)
            Spacer(minLength: 16)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
    }
}
