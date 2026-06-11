import Foundation

protocol _ZWBAnyValueDecodable {
    static func _zwbDecodeAny(_ value: Any, context: ZWBDecodingContext, codingPath: [CodingKey]) throws -> Any
    static func _zwbDefaultAny(context: ZWBDecodingContext, codingPath: [CodingKey]) -> Any?
}

extension _ZWBAnyValueDecodable {
    static func _zwbDefaultAny(context: ZWBDecodingContext, codingPath: [CodingKey]) -> Any? {
        nil
    }
}

extension Optional: _ZWBAnyValueDecodable where Wrapped: Decodable {
    static func _zwbDecodeAny(_ value: Any, context: ZWBDecodingContext, codingPath: [CodingKey]) throws -> Any {
        if ZWBValueConverter.isNullLike(value) {
            return Optional<Wrapped>.none as Any
        }
        do {
            let decoded = try _ZWBDecoder.unbox(Wrapped.self, from: value, context: context, codingPath: codingPath)
            return Optional.some(decoded) as Any
        } catch {
            context.log(path: codingPath, "optional conversion failed, fallback nil")
            return Optional<Wrapped>.none as Any
        }
    }

    static func _zwbDefaultAny(context: ZWBDecodingContext, codingPath: [CodingKey]) -> Any? {
        Optional<Wrapped>.none as Any
    }
}

extension String: _ZWBAnyValueDecodable {
    static func _zwbDecodeAny(_ value: Any, context: ZWBDecodingContext, codingPath: [CodingKey]) throws -> Any {
        if ZWBValueConverter.isNullLike(value) { return "" }
        if let string = value as? String { return string }
        if let number = value as? NSNumber {
            context.log(path: codingPath, "expected String, got Number, converted")
            return number.stringValue
        }
        context.log(path: codingPath, "expected String, got \(ZWBValueConverter.describe(value)), fallback empty string")
        return ""
    }

    static func _zwbDefaultAny(context: ZWBDecodingContext, codingPath: [CodingKey]) -> Any? {
        ""
    }
}

extension Int: _ZWBAnyValueDecodable {
    static func _zwbDecodeAny(_ value: Any, context: ZWBDecodingContext, codingPath: [CodingKey]) throws -> Any {
        if ZWBValueConverter.isNullLike(value) { return 0 }
        if let int = value as? Int { return int }
        if let number = value as? NSNumber {
            context.log(path: codingPath, "expected Int, got Number, converted")
            return number.intValue
        }
        if let string = value as? String, let int = ZWBValueConverter.int(from: string) {
            context.log(path: codingPath, "expected Int, got String(\"\(string)\"), converted")
            return int
        }
        context.log(path: codingPath, "expected Int, got \(ZWBValueConverter.describe(value)), fallback 0")
        return 0
    }

    static func _zwbDefaultAny(context: ZWBDecodingContext, codingPath: [CodingKey]) -> Any? {
        0
    }
}

extension Int64: _ZWBAnyValueDecodable {
    static func _zwbDecodeAny(_ value: Any, context: ZWBDecodingContext, codingPath: [CodingKey]) throws -> Any {
        if ZWBValueConverter.isNullLike(value) { return Int64(0) }
        if let int64 = value as? Int64 { return int64 }
        if let number = value as? NSNumber {
            context.log(path: codingPath, "expected Int64, got Number, converted")
            return number.int64Value
        }
        if let string = value as? String, let double = Double(string.trimmingCharacters(in: .whitespacesAndNewlines)) {
            context.log(path: codingPath, "expected Int64, got String(\"\(string)\"), converted")
            return Int64(double)
        }
        context.log(path: codingPath, "expected Int64, got \(ZWBValueConverter.describe(value)), fallback 0")
        return Int64(0)
    }

    static func _zwbDefaultAny(context: ZWBDecodingContext, codingPath: [CodingKey]) -> Any? {
        Int64(0)
    }
}

extension Double: _ZWBAnyValueDecodable {
    static func _zwbDecodeAny(_ value: Any, context: ZWBDecodingContext, codingPath: [CodingKey]) throws -> Any {
        if ZWBValueConverter.isNullLike(value) { return 0.0 }
        if let double = value as? Double { return double }
        if let number = value as? NSNumber {
            context.log(path: codingPath, "expected Double, got Number, converted")
            return number.doubleValue
        }
        if let string = value as? String, let double = Double(string.trimmingCharacters(in: .whitespacesAndNewlines)) {
            context.log(path: codingPath, "expected Double, got String(\"\(string)\"), converted")
            return double
        }
        context.log(path: codingPath, "expected Double, got \(ZWBValueConverter.describe(value)), fallback 0")
        return 0.0
    }

    static func _zwbDefaultAny(context: ZWBDecodingContext, codingPath: [CodingKey]) -> Any? {
        0.0
    }
}

extension Float: _ZWBAnyValueDecodable {
    static func _zwbDecodeAny(_ value: Any, context: ZWBDecodingContext, codingPath: [CodingKey]) throws -> Any {
        let double = try Double._zwbDecodeAny(value, context: context, codingPath: codingPath) as? Double ?? 0
        return Float(double)
    }

    static func _zwbDefaultAny(context: ZWBDecodingContext, codingPath: [CodingKey]) -> Any? {
        Float(0)
    }
}

extension Bool: _ZWBAnyValueDecodable {
    static func _zwbDecodeAny(_ value: Any, context: ZWBDecodingContext, codingPath: [CodingKey]) throws -> Any {
        if ZWBValueConverter.isNullLike(value) { return false }
        if let bool = value as? Bool { return bool }
        if let number = value as? NSNumber {
            context.log(path: codingPath, "expected Bool, got Number, converted")
            return number.boolValue
        }
        if let string = value as? String, let bool = ZWBValueConverter.bool(from: string) {
            context.log(path: codingPath, "expected Bool, got String(\"\(string)\"), converted")
            return bool
        }
        context.log(path: codingPath, "expected Bool, got \(ZWBValueConverter.describe(value)), fallback false")
        return false
    }

    static func _zwbDefaultAny(context: ZWBDecodingContext, codingPath: [CodingKey]) -> Any? {
        false
    }
}

extension Array: _ZWBAnyValueDecodable where Element: Decodable {
    static func _zwbDecodeAny(_ value: Any, context: ZWBDecodingContext, codingPath: [CodingKey]) throws -> Any {
        var rawArray: [Any]
        if let array = value as? [Any] {
            rawArray = array
        } else if context.options.arrayFromObjectFallback, value is [String: Any] {
            context.log(path: codingPath, "expected Array, got Object, wrapped as single element")
            rawArray = [value]
        } else if ZWBValueConverter.isNullLike(value) {
            return [Element]()
        } else {
            context.log(path: codingPath, "expected Array, got \(ZWBValueConverter.describe(value)), fallback empty array")
            return [Element]()
        }

        var result: [Element] = []
        for (index, item) in rawArray.enumerated() {
            let itemPath = codingPath + [ZWBAnyCodingKey(intValue: index)]
            do {
                result.append(try _ZWBDecoder.unbox(Element.self, from: item, context: context, codingPath: itemPath))
            } catch {
                context.log(path: itemPath, "array element decode failed, skipped")
            }
        }
        return result
    }

    static func _zwbDefaultAny(context: ZWBDecodingContext, codingPath: [CodingKey]) -> Any? {
        [Element]()
    }
}

extension Dictionary: _ZWBAnyValueDecodable where Key == String, Value: Decodable {
    static func _zwbDecodeAny(_ value: Any, context: ZWBDecodingContext, codingPath: [CodingKey]) throws -> Any {
        guard let dictionary = value as? [String: Any] else {
            if ZWBValueConverter.isNullLike(value) { return [String: Value]() }
            context.log(path: codingPath, "expected Dictionary, got \(ZWBValueConverter.describe(value)), fallback empty dictionary")
            return [String: Value]()
        }
        var result: [String: Value] = [:]
        for (key, rawValue) in dictionary {
            let valuePath = codingPath + [ZWBAnyCodingKey(key)]
            do {
                result[key] = try _ZWBDecoder.unbox(Value.self, from: rawValue, context: context, codingPath: valuePath)
            } catch {
                context.log(path: valuePath, "dictionary value decode failed, skipped")
            }
        }
        return result
    }

    static func _zwbDefaultAny(context: ZWBDecodingContext, codingPath: [CodingKey]) -> Any? {
        [String: Value]()
    }
}

enum ZWBValueConverter {
    nonisolated static func isNullLike(_ value: Any) -> Bool {
        if value is NSNull { return true }
        if let string = value as? String {
            return string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return false
    }

    nonisolated static func int(from string: String) -> Int? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if let int = Int(trimmed) { return int }
        if let double = Double(trimmed) { return Int(double) }
        return nil
    }

    nonisolated static func bool(from string: String) -> Bool? {
        switch string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "true", "yes", "y", "1": return true
        case "false", "no", "n", "0": return false
        default: return nil
        }
    }

    nonisolated static func parseStringifiedJSON(_ value: Any) -> Any {
        guard let string = value as? String else { return value }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let first = trimmed.first,
            (first == "{" || first == "["),
            let data = trimmed.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        else {
            return value
        }
        return json
    }

    nonisolated static func describe(_ value: Any) -> String {
        if value is NSNull { return "null" }
        if let string = value as? String { return "String(\"\(string)\")" }
        if value is [Any] { return "Array" }
        if value is [String: Any] { return "Object" }
        return String(describing: type(of: value))
    }
}
