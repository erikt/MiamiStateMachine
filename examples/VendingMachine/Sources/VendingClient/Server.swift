import Foundation
import VendingModel

/// The vending machine server, reached over HTTP.
struct Server {

    /// What the server answered.
    struct Answer {

        /// The status of the response.
        let status: Int

        /// The body of the response.
        let body: Data

        /// The body as text.
        var text: String {
            String(decoding: body, as: UTF8.self)
        }

        /// Reads the body as JSON.
        /// - Parameter type: The type to read.
        /// - Returns: The value read.
        func decode<Value: Decodable>(_ type: Value.Type) throws -> Value {
            try JSONDecoder().decode(type, from: body)
        }

        /// Prints the body as it is, ending with a line break.
        func printBody() {
            print(text, terminator: text.hasSuffix("\n") ? "" : "\n")
        }
    }

    /// The URL the paths of the API are relative to.
    let url: URL

    /// Asks the server for something.
    /// - Parameters:
    ///   - path: The path of the API.
    ///   - query: The query of the request.
    /// - Returns: The answer, whatever its status.
    func get(_ path: String, query: [URLQueryItem] = []) async throws -> Answer {
        var components = URLComponents(url: url.appending(path: path), resolvingAgainstBaseURL: false)
        components?.queryItems = query.isEmpty ? nil : query
        guard let requestURL = components?.url else {
            throw ClientError.notAURL(url)
        }
        return try await send(URLRequest(url: requestURL))
    }

    /// Posts something to the server.
    /// - Parameters:
    ///   - path: The path of the API.
    ///   - body: What to post, written as JSON.
    /// - Returns: The answer, whatever its status.
    func post(_ path: String, json body: (some Encodable)? = nil as Int?) async throws -> Answer {
        var request = URLRequest(url: url.appending(path: path))
        request.httpMethod = "POST"
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }
        return try await send(request)
    }

    /// Sends a request, and waits for the answer.
    private func send(_ request: URLRequest) async throws -> Answer {
        do {
            let (body, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            return Answer(status: status, body: body)
        } catch let error as URLError {
            throw ClientError.unreachable(url, error)
        }
    }
}

/// Why the client could not do what it was asked.
enum ClientError: Error, CustomStringConvertible {

    /// The URL of the server cannot be used.
    case notAURL(URL)

    /// The server could not be reached.
    case unreachable(URL, URLError)

    /// The server answered with a status the client does not expect.
    case unexpectedAnswer(Server.Answer)

    var description: String {
        switch self {
        case .notAURL(let url):
            return "\(url) is not a URL for the server."
        case .unreachable(let url, let error):
            return "The server at \(url) could not be reached: \(error.localizedDescription)"
        case .unexpectedAnswer(let answer):
            // Hummingbird writes an error as {"error":{"message":"..."}}.
            struct ErrorBody: Decodable {
                struct Message: Decodable {
                    let message: String
                }
                let error: Message
            }
            let message = (try? answer.decode(ErrorBody.self).error.message) ?? answer.text
            return "The server answered \(answer.status): \(message)"
        }
    }
}
