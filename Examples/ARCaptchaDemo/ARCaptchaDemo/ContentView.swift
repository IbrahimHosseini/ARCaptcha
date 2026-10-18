import ARCaptcha
import SwiftUI

/// Settings shared by every demo screen. Site key and domain can also be passed as launch
/// arguments: `-siteKey YOUR_KEY -domain example.com`.
struct DemoSettings: DynamicProperty {
    @AppStorage("siteKey") var siteKey = ""
    @AppStorage("domain") var domain = ""
    @AppStorage("renderer") var renderer = ARCaptchaConfiguration.Renderer.web
    @AppStorage("language") var language = ARCaptchaLanguage.persian
    @AppStorage("theme") var theme = ARCaptchaTheme.automatic
    @AppStorage("customAppearance") var customAppearance = false

    var configuration: ARCaptchaConfiguration {
        var configuration = ARCaptchaConfiguration(siteKey: siteKey, domain: domain, renderer: renderer, language: language, theme: theme)
        configuration.web.isInspectable = true
        // Lets UI tests point the native renderer at a mock server: `-nativeAPIBaseURL http://127.0.0.1:8798/`.
        if let override = UserDefaults.standard.string(forKey: "nativeAPIBaseURL"), let url = URL(string: override) {
            configuration.native.apiBaseURL = url
        }
        if customAppearance {
            configuration.appearance = ARCaptchaAppearance(
                accentColor: .systemTeal,
                backgroundColor: .secondarySystemGroupedBackground,
                primaryTextColor: .label,
                secondaryTextColor: .secondaryLabel,
                fieldBackgroundColor: .tertiarySystemFill,
                cornerRadius: 8
            )
        }
        return configuration
    }

    /// Changes whenever a setting changes, to rebuild components that captured the old configuration.
    var identity: String {
        [siteKey, domain, renderer.rawValue, language.rawValue, theme.rawValue, String(customAppearance)].joined(separator: "|")
    }
}

@MainActor
final class EventLog: ObservableObject {
    @Published private(set) var lines: [String] = []
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()

    func add(_ line: String) {
        let time = timeFormatter.string(from: Date())
        lines.insert("\(time)  \(line)", at: 0)
    }

    func clear() { lines.removeAll() }
}

struct ContentView: View {
    private let settings = DemoSettings()
    @StateObject private var log = EventLog()
    @State private var checkboxToken: ARCaptchaToken?
    @State private var showsCaptcha = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Site")) {
                    TextField("Site key", text: settings.$siteKey)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    TextField("Domain, e.g. example.com", text: settings.$domain)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                }

                Section(header: Text("Options")) {
                    Picker("Renderer", selection: settings.$renderer) {
                        Text("Web").tag(ARCaptchaConfiguration.Renderer.web)
                        Text("Native").tag(ARCaptchaConfiguration.Renderer.native)
                    }
                    .pickerStyle(.segmented)
                    Picker("Language", selection: settings.$language) {
                        Text("فارسی").tag(ARCaptchaLanguage.persian)
                        Text("English").tag(ARCaptchaLanguage.english)
                    }
                    Picker("Theme", selection: settings.$theme) {
                        Text("Automatic").tag(ARCaptchaTheme.automatic)
                        Text("Light").tag(ARCaptchaTheme.light)
                        Text("Dark").tag(ARCaptchaTheme.dark)
                    }
                    Toggle("Custom appearance", isOn: settings.$customAppearance)
                }

                Section {
                    Button("Verify (modal)") { verify(.modal) }
                        .accessibilityIdentifier("verifyModal")
                    Button("Verify (invisible)") { verify(.invisible) }
                        .accessibilityIdentifier("verifyInvisible")
                    Button("Verify with .arcaptcha modifier") { showsCaptcha = true }
                        .arcaptcha(isPresented: $showsCaptcha, configuration: settings.configuration, onEvent: logEvent) { result in
                            logResult("modifier", result)
                        }
                } header: {
                    Text("Programmatic")
                } footer: {
                    Text("Invisible shows a challenge only when ARCaptcha asks for one.")
                }

                Section(header: Text("Checkbox")) {
                    ARCaptchaCheckbox(configuration: settings.configuration, token: $checkboxToken, onEvent: logEvent) { error in
                        log.add("checkbox error \(error.code.rawValue): \(error.message)")
                    }
                    .id(settings.identity)
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                    if let checkboxToken {
                        Text(checkboxToken.value)
                            .font(.system(.caption, design: .monospaced))
                            .contextMenu {
                                Button("Copy") { UIPasteboard.general.string = checkboxToken.value }
                            }
                        Button("Use token (clears it)") { self.checkboxToken = nil }
                    }
                }

                Section(header: Text("More")) {
                    NavigationLink("Inline native challenge", destination: InlineChallengeScreen(settings: settings, log: log))
                    NavigationLink(
                        "UIKit",
                        destination: UIKitDemo(configuration: settings.configuration, log: log).navigationTitle("UIKit")
                    )
                }

                Section {
                    ForEach(log.lines.indices, id: \.self) { index in
                        Text(log.lines[index]).font(.system(.caption, design: .monospaced))
                    }
                } header: {
                    HStack {
                        Text("Log")
                        Spacer()
                        Button("Clear", action: log.clear).font(.caption)
                    }
                }
            }
            .navigationTitle("ARCaptcha")
        }
        .navigationViewStyle(.stack)
    }

    private func verify(_ presentation: ARCaptchaPresentation) {
        let captcha = ARCaptcha(configuration: settings.configuration)
        captcha.onEvent = logEvent
        Task {
            do {
                logResult("verify", .success(try await captcha.verify(presentation: presentation)))
            } catch {
                logResult("verify", .failure(error as? ARCaptchaError ?? ARCaptchaError(code: .unknown, message: "\(error)")))
            }
        }
    }

    private func logEvent(_ event: ARCaptchaEvent) {
        log.add("event \(event)")
    }

    private func logResult(_ source: String, _ result: Result<ARCaptchaToken, ARCaptchaError>) {
        switch result {
        case let .success(token): log.add("\(source) token \(token.value)")
        case let .failure(error): log.add("\(source) error \(error.code.rawValue): \(error.message)")
        }
    }
}

struct InlineChallengeScreen: View {
    let settings: DemoSettings
    @ObservedObject var log: EventLog
    @State private var token: ARCaptchaToken?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("The native challenge laid out inside the screen, like a form field.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                ARCaptchaChallengeView(configuration: settings.configuration, onEvent: { log.add("inline event \($0)") }) { token in
                    self.token = token
                    log.add("inline token \(token.value)")
                }
                .id(settings.identity)
                if let token {
                    Label("Token: \(token.value)", systemImage: "checkmark.seal.fill")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundColor(.green)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Inline challenge")
        .navigationBarTitleDisplayMode(.inline)
    }
}
