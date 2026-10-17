import ARCaptcha
import SwiftUI
import UIKit

/// The SDK used from UIKit: a checkbox in a stack view and a button that runs a modal verification.
final class UIKitDemoViewController: UIViewController {
    private let configuration: ARCaptchaConfiguration
    private let log: EventLog
    private lazy var captcha = ARCaptcha(configuration: configuration)
    private let tokenLabel = UILabel()

    init(configuration: ARCaptchaConfiguration, log: EventLog) {
        self.configuration = configuration
        self.log = log
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        let checkbox = ARCaptchaCheckboxView(configuration: configuration)
        checkbox.onTokenChange = { [weak self] token in
            self?.show(token.map { "Checkbox token: \($0.value)" } ?? "No token")
        }

        var buttonConfiguration = UIButton.Configuration.filled()
        buttonConfiguration.title = "Verify from UIKit"
        let button = UIButton(configuration: buttonConfiguration, primaryAction: UIAction { [weak self] _ in
            self?.verify()
        })

        tokenLabel.numberOfLines = 0
        tokenLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        tokenLabel.text = "No token"

        let stack = UIStackView(arrangedSubviews: [checkbox, button, tokenLabel])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
        ])
    }

    private func verify() {
        captcha.verify(in: view.window?.windowScene) { [weak self] result in
            switch result {
            case let .success(token): self?.show("Modal token: \(token.value)")
            case let .failure(error): self?.show("Error \(error.code.rawValue): \(error.message)")
            }
        }
    }

    private func show(_ text: String) {
        tokenLabel.text = text
        log.add("uikit \(text)")
    }
}

struct UIKitDemo: UIViewControllerRepresentable {
    let configuration: ARCaptchaConfiguration
    let log: EventLog

    func makeUIViewController(context: Context) -> UIKitDemoViewController {
        UIKitDemoViewController(configuration: configuration, log: log)
    }

    func updateUIViewController(_ controller: UIKitDemoViewController, context: Context) {}
}
