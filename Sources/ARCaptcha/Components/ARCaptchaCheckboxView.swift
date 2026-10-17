import SwiftUI
import UIKit

/// The UIKit version of ``ARCaptchaCheckbox``.
///
/// ```swift
/// let checkbox = ARCaptchaCheckboxView(configuration: configuration)
/// checkbox.onTokenChange = { [weak self] token in self?.submitButton.isEnabled = token != nil }
/// stackView.addArrangedSubview(checkbox)
/// ```
public final class ARCaptchaCheckboxView: UIView {
    /// The current token, or `nil` before verification and after expiry or ``reset()``.
    public var token: ARCaptchaToken? { controller.token }
    /// Called when ``token`` changes.
    public var onTokenChange: ((ARCaptchaToken?) -> Void)?
    public var onEvent: ((ARCaptchaEvent) -> Void)? {
        get { controller.onEvent }
        set { controller.onEvent = newValue }
    }
    public var onError: ((ARCaptchaError) -> Void)? {
        get { controller.onError }
        set { controller.onError = newValue }
    }

    private let controller: CheckboxController
    private let host: UIHostingController<CheckboxHost>

    public init(configuration: ARCaptchaConfiguration) {
        controller = CheckboxController(configuration: configuration, onEvent: nil, onError: nil)
        host = UIHostingController(rootView: CheckboxHost(controller: controller))
        super.init(frame: .zero)

        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: topAnchor),
            host.view.bottomAnchor.constraint(equalTo: bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        host.rootView.onTokenChange = { [weak self] token in
            self?.invalidateIntrinsicContentSize()
            self?.onTokenChange?(token)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Clears the token, for example after sending it to your backend.
    public func reset() {
        controller.reset()
    }

    public override var intrinsicContentSize: CGSize {
        let fitting = host.sizeThatFits(in: CGSize(width: bounds.width > 0 ? bounds.width : 320, height: .greatestFiniteMagnitude))
        return CGSize(width: UIView.noIntrinsicMetric, height: fitting.height)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        invalidateIntrinsicContentSize()
    }
}

struct CheckboxHost: View {
    @ObservedObject var controller: CheckboxController
    var onTokenChange: ((ARCaptchaToken?) -> Void)?

    var body: some View {
        CheckboxBody(controller: controller)
            .onChange(of: controller.token) { onTokenChange?($0) }
    }
}
