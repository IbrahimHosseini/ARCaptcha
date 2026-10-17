import Foundation

/// A challenge as received from the API, before its images are decoded.
struct NativeChallengePayload: Sendable, Equatable {
    enum Kind: Sendable, Equatable {
        case imageSelection(category: String, images: [Data])
        case puzzle(background: Data, piece: Data, pieceY: Double)
        case audio(url: URL)
    }

    let id: String
    let kind: Kind
}

enum CreateOutcome: Sendable, Equatable {
    /// ARCaptcha trusted the client and issued a token without a challenge.
    case passed(token: String)
    case challenge(NativeChallengePayload)
}

enum AnswerOutcome: Sendable, Equatable {
    case correct
    case incorrect
    /// The challenge no longer exists on the server, usually because it expired.
    case expired
}

/// Talks to ARCaptcha's mobile API.
struct NativeAPIClient: Sendable {
    let baseURL: URL
    let siteKey: String
    let domain: String
    let session: URLSession

    init(configuration: ARCaptchaConfiguration, session: URLSession = .shared) {
        self.baseURL = configuration.native.apiBaseURL
        self.siteKey = configuration.siteKey
        self.domain = configuration.domain
        self.session = session
    }

    func createChallenge(_ type: ARCaptchaChallengeType) async throws -> CreateOutcome {
        let path = type == .audio ? "arcaptcha/api/create/voice" : "arcaptcha/api/create"
        let body = CreateChallengeRequest(siteKey: siteKey, domain: domain, captchaType: NativeProtocol.requestedType(for: type))
        let (data, response) = try await send(path: path, body: body, networkError: .createNetworkError)

        guard (200..<300).contains(response.statusCode) else {
            throw ARCaptchaError(code: .createServerError, message: Self.serverMessage(data, status: response.statusCode))
        }
        guard let decoded = try? JSONDecoder().decode(CreateChallengeResponse.self, from: data),
              let content = decoded.content, let id = content.challengeID, !id.isEmpty else {
            throw ARCaptchaError(code: .createServerError, message: "Unexpected response from the create endpoint.")
        }
        if decoded.captchaType == "cookie" {
            return .passed(token: id)
        }
        return .challenge(try await payload(id: id, content: content))
    }

    func submit(_ answer: NativeAnswer, challengeID: String) async throws -> AnswerOutcome {
        let body = AnswerRequest(siteKey: siteKey, domain: domain, challengeID: challengeID, answer: answer)
        let (data, response) = try await send(path: "arcaptcha/api/answer", body: body, networkError: .answerNetworkError)

        guard (200..<300).contains(response.statusCode) else {
            let error = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            if error?.message?.lowercased().contains("challenge not exist") == true {
                return .expired
            }
            throw ARCaptchaError(code: .answerServerError, message: Self.serverMessage(data, status: response.statusCode))
        }
        guard let decoded = try? JSONDecoder().decode(AnswerResponse.self, from: data) else {
            throw ARCaptchaError(code: .answerServerError, message: "Unexpected response from the answer endpoint.")
        }
        return decoded.success ? .correct : .incorrect
    }

    // MARK: - Resources

    func imageURL(_ id: String) -> URL {
        baseURL.appendingPathComponent("arcaptcha/api/images").appendingPathComponent(id)
    }

    func puzzleImageURL(_ id: String) -> URL {
        // The middle segment is a literal placeholder in the official Android SDK too.
        baseURL.appendingPathComponent("arcaptcha/api/puzzles")
            .appendingPathComponent(siteKey)
            .appendingPathComponent(":original_image_id")
            .appendingPathComponent(id)
    }

    func voiceURL(_ id: String) -> URL {
        baseURL.appendingPathComponent("arcaptcha/api/voices").appendingPathComponent(id)
    }

    // MARK: - Private

    private func payload(id: String, content: CreateChallengeResponse.Content) async throws -> NativeChallengePayload {
        if let background = content.puzzleBackground, let piece = content.puzzlePiece {
            async let backgroundData = download(puzzleImageURL(background))
            async let pieceData = download(puzzleImageURL(piece))
            let kind = NativeChallengePayload.Kind.puzzle(background: try await backgroundData, piece: try await pieceData, pieceY: content.y ?? 0)
            return NativeChallengePayload(id: id, kind: kind)
        }
        if let imageIDs = content.imageURLs, !imageIDs.isEmpty {
            let images = try await withThrowingTaskGroup(of: (Int, Data).self) { group in
                for (index, imageID) in imageIDs.enumerated() {
                    group.addTask { (index, try await download(imageURL(imageID))) }
                }
                var result = [Data?](repeating: nil, count: imageIDs.count)
                for try await (index, data) in group { result[index] = data }
                return result.compactMap { $0 }
            }
            return NativeChallengePayload(id: id, kind: .imageSelection(category: content.category ?? "", images: images))
        }
        if let path = content.path, !path.isEmpty {
            return NativeChallengePayload(id: id, kind: .audio(url: voiceURL(path)))
        }
        throw ARCaptchaError(code: .createServerError, message: "Unsupported challenge type \(content.challengeID ?? "").")
    }

    private func download(_ url: URL) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.compatibleData(for: URLRequest(url: url))
        } catch {
            throw ARCaptchaError(code: .createNetworkError, message: error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), !data.isEmpty else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw ARCaptchaError(code: .createServerError, message: "Could not load \(url.lastPathComponent) (\(status)).")
        }
        return data
    }

    private func send(path: String, body: some Encodable, networkError: ARCaptchaError.Code) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(body)
        do {
            let (data, response) = try await session.compatibleData(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw ARCaptchaError(code: networkError, message: "The response was not HTTP.")
            }
            return (data, http)
        } catch let error as ARCaptchaError {
            throw error
        } catch {
            throw ARCaptchaError(code: networkError, message: error.localizedDescription)
        }
    }

    private static func serverMessage(_ data: Data, status: Int) -> String {
        let message = (try? JSONDecoder().decode(APIErrorResponse.self, from: data))?.message
        return "\(status)-\(message ?? HTTPURLResponse.localizedString(forStatusCode: status))"
    }
}

extension URLSession {
    /// `data(for:)` that also runs on iOS 14, which has no async URLSession API.
    func compatibleData(for request: URLRequest) async throws -> (Data, URLResponse) {
        if #available(iOS 15.0, *) {
            return try await data(for: request)
        }
        let handle = DataTaskHandle()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let task = dataTask(with: request) { data, response, error in
                    if let data, let response {
                        continuation.resume(returning: (data, response))
                    } else {
                        continuation.resume(throwing: error ?? URLError(.badServerResponse))
                    }
                }
                handle.start(task)
            }
        } onCancel: {
            handle.cancel()
        }
    }
}

/// Lets a Swift task cancel the data task it is waiting on, even if cancellation comes first.
private final class DataTaskHandle: @unchecked Sendable {
    private let lock = NSLock()
    private var task: URLSessionDataTask?
    private var isCancelled = false

    func start(_ task: URLSessionDataTask) {
        lock.lock()
        self.task = task
        let cancelled = isCancelled
        lock.unlock()
        task.resume()
        if cancelled { task.cancel() }
    }

    func cancel() {
        lock.lock()
        isCancelled = true
        let task = self.task
        lock.unlock()
        task?.cancel()
    }
}
