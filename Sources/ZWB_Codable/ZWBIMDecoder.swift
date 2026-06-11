import Foundation

public enum ZWBIMBodyKind: Equatable {
    case object
    case array
    case text
}

public struct ZWBDecodedMessage<Model> {
    public let model: Model?
    public let rawJSON: ZWBJSONValue?
    public let rawString: String
    public let bodyKind: ZWBIMBodyKind
    public let warnings: [String]

    public var isModelReady: Bool {
        model != nil
    }
}

public final class ZWBIMDecoder {
    public var options: ZWBDecodingOptions

    public init(options: ZWBDecodingOptions = .default) {
        self.options = options
    }

    public func decodeSafely<Model>(_ type: Model.Type, from body: String) -> ZWBDecodedMessage<Model> where Model: Decodable {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            return ZWBDecodedMessage(
                model: nil,
                rawJSON: nil,
                rawString: body,
                bodyKind: .text,
                warnings: ["IM body is not valid JSON, treated as text."]
            )
        }

        var logs: [String] = []
        let oldMode = ZWBCodableLogger.mode
        let oldLogger = ZWBCodableLogger.onLog
        ZWBCodableLogger.mode = .verbose
        ZWBCodableLogger.onLog = { logs.append("\($0.path): \($0.message)") }
        defer {
            ZWBCodableLogger.mode = oldMode
            ZWBCodableLogger.onLog = oldLogger
        }

        let model = try? ZWBJSONDecoder(options: options).decode(Model.self, fromJSONObject: jsonObject)
        let kind: ZWBIMBodyKind
        if jsonObject is [String: Any] {
            kind = .object
        } else if jsonObject is [Any] {
            kind = .array
        } else {
            kind = .text
        }

        return ZWBDecodedMessage(
            model: model,
            rawJSON: ZWBJSONValue(any: jsonObject),
            rawString: body,
            bodyKind: kind,
            warnings: logs
        )
    }

    public static func decodeSafely<Model>(_ type: Model.Type, from body: String, options: ZWBDecodingOptions = .default) -> ZWBDecodedMessage<Model> where Model: Decodable {
        ZWBIMDecoder(options: options).decodeSafely(type, from: body)
    }
}
