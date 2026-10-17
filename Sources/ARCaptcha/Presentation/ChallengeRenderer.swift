import UIKit

/// What a renderer reports to the verification session that hosts it.
enum RendererOutput {
    case event(ARCaptchaEvent)
    /// A challenge needs the user, so the overlay must become visible.
    case needsPresentation
    case solved(ARCaptchaToken)
    case failed(ARCaptchaError)
    /// The user closed the challenge.
    case dismissed
}

/// Draws a challenge inside the overlay. One renderer runs one verification.
@MainActor
protocol ChallengeRenderer: AnyObject {
    var viewController: UIViewController { get }
    /// `true` to keep the content invisible until ``RendererOutput/needsPresentation``. A web view stays
    /// visible but transparent instead, because WebKit throttles pages it considers hidden.
    var hidesContentUntilPresented: Bool { get }
    var output: ((RendererOutput) -> Void)? { get set }
    func start()
    func stop()
}
