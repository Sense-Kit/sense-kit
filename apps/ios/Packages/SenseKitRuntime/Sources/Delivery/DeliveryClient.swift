import Foundation

public struct DeliveryResult: Sendable {
    public let statusCode: Int
    public let responseBody: String
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
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        let body = String(decoding: data, as: UTF8.self)
        return DeliveryResult(statusCode: statusCode, responseBody: body)
    }
}

