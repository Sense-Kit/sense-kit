import CryptoKit
import Foundation

public struct OpenClawAdapter: Sendable {
    public init() {}

    public func makeRequest(envelope: SenseKitEventEnvelope, configuration: OpenClawConfiguration) throws -> URLRequest {
        let body = try JSONCoding.encoder.encode(envelope)
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let signature = hmac(body: body, timestamp: timestamp, secret: configuration.hmacSecret)

        var request = URLRequest(url: configuration.endpointURL)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue(timestamp, forHTTPHeaderField: "X-SenseKit-Timestamp")
        request.setValue("sha256=\(signature)", forHTTPHeaderField: "X-SenseKit-Signature")
        return request
    }

    private func hmac(body: Data, timestamp: String, secret: String) -> String {
        let key = SymmetricKey(data: Data(secret.utf8))
        let payload = body + Data(timestamp.utf8)
        let signature = HMAC<SHA256>.authenticationCode(for: payload, using: key)
        return Data(signature).map { String(format: "%02x", $0) }.joined()
    }
}

