import Foundation

public enum RPCEnvelope {
    public struct Response: Sendable {
        public let id: Int
        public let result: Data?
        public let errorMessage: String?
    }

    public struct Parsed: Sendable {
        public let response: Response?
        public let method: String?
        public let params: Data?
    }

    public static func parse(_ data: Data) throws -> Parsed {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RPCError.invalidEnvelope
        }

        var response: Response?
        if let id = object["id"] as? Int {
            let result = object["result"].flatMap { try? JSONSerialization.data(withJSONObject: $0) }
            let error = object["error"] as? [String: Any]
            response = Response(id: id, result: result, errorMessage: error?["message"] as? String)
        }

        let params = object["params"].flatMap { try? JSONSerialization.data(withJSONObject: $0) }
        return Parsed(response: response, method: object["method"] as? String, params: params)
    }

    public enum RPCError: Error {
        case invalidEnvelope
    }
}
