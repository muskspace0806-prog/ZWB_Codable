import Foundation

public enum ZWBJSONValue: Codable, Equatable {
    case object([String: ZWBJSONValue])
    case array([ZWBJSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: ZWBJSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([ZWBJSONValue].self) {
            self = .array(value)
        } else {
            self = .null
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    nonisolated public init(any value: Any) {
        if value is NSNull {
            self = .null
        } else if let value = value as? Bool {
            self = .bool(value)
        } else if let value = value as? NSNumber {
            self = .number(value.doubleValue)
        } else if let value = value as? String {
            self = .string(value)
        } else if let value = value as? [Any] {
            self = .array(value.map(ZWBJSONValue.init(any:)))
        } else if let value = value as? [String: Any] {
            self = .object(value.mapValues(ZWBJSONValue.init(any:)))
        } else {
            self = .null
        }
    }

    nonisolated public subscript(key: String) -> ZWBJSONValue {
        guard case .object(let object) = self else { return .null }
        return object[key] ?? .null
    }

    nonisolated public subscript(index: Int) -> ZWBJSONValue {
        guard case .array(let array) = self, array.indices.contains(index) else { return .null }
        return array[index]
    }

    nonisolated public var stringValue: String? {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return String(value)
        case .bool(let value):
            return String(value)
        default:
            return nil
        }
    }

    nonisolated public var intValue: Int? {
        switch self {
        case .number(let value):
            return Int(value)
        case .string(let value):
            return ZWBValueConverter.int(from: value)
        case .bool(let value):
            return value ? 1 : 0
        default:
            return nil
        }
    }

    nonisolated public var boolValue: Bool? {
        switch self {
        case .bool(let value):
            return value
        case .number(let value):
            return value != 0
        case .string(let value):
            return ZWBValueConverter.bool(from: value)
        default:
            return nil
        }
    }

    nonisolated public var objectValue: [String: ZWBJSONValue]? {
        guard case .object(let value) = self else { return nil }
        return value
    }

    nonisolated public var arrayValue: [ZWBJSONValue]? {
        guard case .array(let value) = self else { return nil }
        return value
    }
}

extension ZWBJSONValue: _ZWBAnyValueDecodable {
    static func _zwbDecodeAny(_ value: Any, context: ZWBDecodingContext, codingPath: [CodingKey]) throws -> Any {
        ZWBJSONValue(any: value)
    }

    static func _zwbDefaultAny(context: ZWBDecodingContext, codingPath: [CodingKey]) -> Any? {
        ZWBJSONValue.null
    }
}
