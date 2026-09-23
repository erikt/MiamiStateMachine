import Foundation
import Hummingbird

/// Makes a response of JSON, formatted to be read by people too.
/// - Parameters:
///   - value: What to answer with.
///   - status: The status of the response.
/// - Returns: The response.
func json(_ value: some Encodable, status: HTTPResponse.Status = .ok) throws -> Response {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    var body = ByteBuffer(bytes: try encoder.encode(value))
    body.writeString("\n")
    return Response(status: status,
                    headers: [.contentType: "application/json; charset=utf-8"],
                    body: ResponseBody(byteBuffer: body))
}

/// Makes a response of plain text, ending with a line break.
/// - Parameter text: The text to answer with.
/// - Returns: The response.
func text(_ text: String) -> Response {
    Response(status: .ok,
             headers: [.contentType: "text/plain; charset=utf-8"],
             body: ResponseBody(byteBuffer: ByteBuffer(string: text.hasSuffix("\n") ? text : text + "\n")))
}
