import Foundation

public protocol ZWBCodable: Codable {
    init()

    static var zwbKeyMapping: [String: [String]] { get }
    static func zwbDidFinishMapping()
}

public extension ZWBCodable {
    static var zwbKeyMapping: [String: [String]] { [:] }
    static func zwbDidFinishMapping() {}
}

public enum ZWBObjectArrayFallback {
    case firstElement
    case emptyObject
    case fail
}

public struct ZWBDecodingOptions {
    public var objectFromArrayFallback: ZWBObjectArrayFallback
    public var arrayFromObjectFallback: Bool
    public var parsesStringifiedJSON: Bool

    public init(
        objectFromArrayFallback: ZWBObjectArrayFallback = .firstElement,
        arrayFromObjectFallback: Bool = true,
        parsesStringifiedJSON: Bool = true
    ) {
        self.objectFromArrayFallback = objectFromArrayFallback
        self.arrayFromObjectFallback = arrayFromObjectFallback
        self.parsesStringifiedJSON = parsesStringifiedJSON
    }

    public static let `default` = ZWBDecodingOptions()
}

public final class ZWBJSONDecoder {
    public var options: ZWBDecodingOptions

    public init(options: ZWBDecodingOptions = .default) {
        self.options = options
    }

    public func decode<T>(_ type: T.Type, from data: Data) throws -> T where T: Decodable {
        let json = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        return try decode(type, fromJSONObject: json)
    }

    public func decode<T>(_ type: T.Type, from jsonString: String) throws -> T where T: Decodable {
        guard let data = jsonString.data(using: .utf8) else {
            throw ZWBDecodingError.invalidJSONString
        }
        return try decode(type, from: data)
    }

    public func decode<T>(_ type: T.Type, fromJSONObject jsonObject: Any) throws -> T where T: Decodable {
        let context = ZWBDecodingContext(options: options)
        let result = try _ZWBDecoder.unbox(T.self, from: jsonObject, context: context, codingPath: [])
        context.flushLogs()
        return result
    }
}

public extension ZWBCodable {
    static func zwbDecode(from data: Data, options: ZWBDecodingOptions = .default) throws -> Self {
        try ZWBJSONDecoder(options: options).decode(Self.self, from: data)
    }

    static func zwbDecode(from jsonString: String, options: ZWBDecodingOptions = .default) throws -> Self {
        try ZWBJSONDecoder(options: options).decode(Self.self, from: jsonString)
    }

    static func zwbDecode(fromJSONObject jsonObject: Any, options: ZWBDecodingOptions = .default) throws -> Self {
        try ZWBJSONDecoder(options: options).decode(Self.self, fromJSONObject: jsonObject)
    }
}

public enum ZWBDecodingError: Error, Equatable {
    case invalidJSONString
    case unsupportedValue(String)
}
