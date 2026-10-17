import UIKit

/// A window above the app that hosts a challenge. While nothing is shown it lets touches through,
/// so an invisible verification never blocks the app.
final class OverlayWindow: UIWindow {
    var passesTouchesThrough = true

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        passesTouchesThrough ? nil : super.hitTest(point, with: event)
    }
}

/// Dims the app and lays out the renderer's content with a close button.
final class OverlayViewController: UIViewController {
    var onClose: (() -> Void)?

    private let content: UIViewController
    private let hidesContentUntilPresented: Bool
    private let appearance: ARCaptchaAppearance
    private let strings: ARCaptchaStrings
    private let dimmingView = UIView()
    private let spinner = UIActivityIndicatorView(style: .large)
    private let closeButton = UIButton(type: .system)

    init(content: UIViewController, hidesContentUntilPresented: Bool, appearance: ARCaptchaAppearance, strings: ARCaptchaStrings) {
        self.content = content
        self.hidesContentUntilPresented = hidesContentUntilPresented
        self.appearance = appearance
        self.strings = strings
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        dimmingView.backgroundColor = appearance.dimmingColor
        dimmingView.alpha = 0
        dimmingView.frame = view.bounds
        dimmingView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(dimmingView)

        addChild(content)
        content.view.frame = view.bounds
        content.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        content.view.backgroundColor = .clear
        if hidesContentUntilPresented { content.view.alpha = 0 }
        view.addSubview(content.view)
        content.didMove(toParent: self)

        spinner.color = .white
        spinner.hidesWhenStopped = true
        spinner.accessibilityLabel = strings.loading
        spinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)

        var buttonConfiguration = UIButton.Configuration.filled()
        buttonConfiguration.image = UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .bold))
        buttonConfiguration.cornerStyle = .capsule
        buttonConfiguration.baseBackgroundColor = appearance.backgroundColor
        buttonConfiguration.baseForegroundColor = appearance.primaryTextColor
        closeButton.configuration = buttonConfiguration
        closeButton.accessibilityLabel = strings.close
        closeButton.alpha = 0
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addAction(UIAction { [weak self] _ in self?.onClose?() }, for: .primaryActionTriggered)
        view.addSubview(closeButton)

        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            closeButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40),
        ])
    }

    /// Shows the dimmed backdrop and, if `loading`, a spinner in place of the content.
    func reveal(loading: Bool, animated: Bool) {
        loadViewIfNeeded()
        if loading { spinner.startAnimating() } else { spinner.stopAnimating() }
        view.accessibilityViewIsModal = true
        let changes = {
            self.dimmingView.alpha = 1
            self.closeButton.alpha = 1
            if self.hidesContentUntilPresented { self.content.view.alpha = loading ? 0 : 1 }
        }
        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: [.beginFromCurrentState, .curveEaseOut], animations: changes)
        } else {
            changes()
        }
        if !loading {
            UIAccessibility.post(notification: .screenChanged, argument: content.view)
        }
    }

    func conceal(completion: @escaping () -> Void) {
        spinner.stopAnimating()
        UIView.animate(withDuration: 0.2, delay: 0, options: [.beginFromCurrentState, .curveEaseIn], animations: {
            self.view.alpha = 0
        }, completion: { _ in completion() })
    }
}
