import Foundation

public struct DeliveryResult: Sendable {
    public let statusCode: Int
    public let responseBody: String
}

public enum DeliveryClientError: Error, Sendable, CustomStringConvertible {
    case invalidHTTPResponse
    case unsuccessfulStatusCode(Int, String)

    public var description: String {
        switch self {
        case .invalidHTTPResponse:
            return "Delivery failed: invalid HTTP response"
        case .unsuccessfulStatusCode(let statusCode, let body):
            let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedBody.isEmpty {
                return "Delivery failed: HTTP \(statusCode)"
            }

            let preview = String(trimmedBody.prefix(200))
            return "Delivery failed: HTTP \(statusCode) body=\(preview)"
        }
    }
}

public actor DeliveryClient {
    private let adapter: OpenClawAdapter
    private let session: URLSession

    public init(adapter: OpenClawAdapter = OpenClawAdapter(), session: URLSession = .shared) {
        self.adapter = adapter
        self.session = session
    }

    public func deliver(_ envelope: SenseKitEventEnvelope, configuration: OpenClawConfiguration) async throws -> DeliveryResult {
        let request = try adapter.makeRequest(envelope: envelope, configuration: configuration)
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw DeliveryClientError.invalidHTTPResponse
        }

        let statusCode = response.statusCode
        let body = String(decoding: data, as: UTF8.self)

        guard (200 ... 299).contains(statusCode) else {
            throw DeliveryClientError.unsuccessfulStatusCode(statusCode, body)
        }

        return DeliveryResult(statusCode: statusCode, responseBody: body)
    }
}
