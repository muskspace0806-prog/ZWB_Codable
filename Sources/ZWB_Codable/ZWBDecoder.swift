import Foundation

final class _ZWBDecoder: Decoder {
    let value: Any
    let context: ZWBDecodingContext
    let codingPath: [CodingKey]
    let keyMapping: [String: [String]]

    var userInfo: [CodingUserInfoKey: Any] { [:] }

    init(value: Any, context: ZWBDecodingContext, codingPath: [CodingKey], keyMapping: [String: [String]] = [:]) {
        if context.options.parsesStringifiedJSON {
            self.value = ZWBValueConverter.parseStringifiedJSON(value)
        } else {
            self.value = value
        }
        self.context = context
        self.codingPath = codingPath
        self.keyMapping = keyMapping
    }

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key: CodingKey {
        let dictionary = normalizedDictionary(from: value)
        let container = ZWBKeyedDecodingContainer<Key>(
            dictionary: dictionary,
            context: context,
            codingPath: codingPath,
            keyMapping: keyMapping
        )
        return KeyedDecodingContainer(container)
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        let array = normalizedArray(from: value)
        return ZWBUnkeyedDecodingContainer(
            array: array,
            context: context,
            codingPath: codingPath
        )
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        ZWBSingleValueDecodingContainer(
            value: value,
            context: context,
            codingPath: codingPath
        )
    }

    private func normalizedDictionary(from value: Any) -> [String: Any] {
        if let dictionary = value as? [String: Any] {
            return dictionary
        }
        if let array = value as? [Any] {
            switch context.options.objectFromArrayFallback {
            case .firstElement:
                if let dictionary = array.first as? [String: Any] {
                    context.log(path: codingPath, "expected Object, got Array, used first element")
                    return dictionary
                }
            case .emptyObject:
                context.log(path: codingPath, "expected Object, got Array, used empty object")
                return [:]
            case .fail:
                break
            }
        }
        if ZWBValueConverter.isNullLike(value) {
            return [:]
        }
        context.log(path: codingPath, "expected Object, got \(ZWBValueConverter.describe(value)), used empty object")
        return [:]
    }

    private func normalizedArray(from value: Any) -> [Any] {
        if let array = value as? [Any] {
            return array
        }
        if context.options.arrayFromObjectFallback, value is [String: Any] {
            context.log(path: codingPath, "expected Array, got Object, wrapped as single element")
            return [value]
        }
        if ZWBValueConverter.isNullLike(value) {
            return []
        }
        context.log(path: codingPath, "expected Array, got \(ZWBValueConverter.describe(value)), used empty array")
        return []
    }

    static func unbox<T>(_ type: T.Type, from value: Any, context: ZWBDecodingContext, codingPath: [CodingKey]) throws -> T where T: Decodable {
        let parsedValue = context.options.parsesStringifiedJSON ? ZWBValueConverter.parseStringifiedJSON(value) : value

        if let convertibleType = T.self as? _ZWBAnyValueDecodable.Type {
            guard let converted = try convertibleType._zwbDecodeAny(parsedValue, context: context, codingPath: codingPath) as? T else {
                throw ZWBDecodingError.unsupportedValue("Could not convert \(ZWBValueConverter.describe(parsedValue)) to \(T.self)")
            }
            return converted
        }

        do {
            let mapping = (T.self as? any ZWBCodable.Type)?.zwbKeyMapping ?? [:]
            return try T(from: _ZWBDecoder(value: parsedValue, context: context, codingPath: codingPath, keyMapping: mapping))
        } catch {
            if let modelType = T.self as? any ZWBCodable.Type, let fallback = modelType.init() as? T {
                context.log(path: codingPath, "decode \(T.self) failed, used empty model")
                return fallback
            }
            throw error
        }
    }

    static func defaultValue<T>(_ type: T.Type, context: ZWBDecodingContext, codingPath: [CodingKey]) -> T? where T: Decodable {
        if let convertibleType = T.self as? _ZWBAnyValueDecodable.Type,
           let value = convertibleType._zwbDefaultAny(context: context, codingPath: codingPath) as? T {
            return value
        }
        if let modelType = T.self as? any ZWBCodable.Type, let value = modelType.init() as? T {
            return value
        }
        return nil
    }
}

struct ZWBKeyedDecodingContainer<Key>: KeyedDecodingContainerProtocol where Key: CodingKey {
    let dictionary: [String: Any]
    let context: ZWBDecodingContext
    let codingPath: [CodingKey]
    let keyMapping: [String: [String]]

    var allKeys: [Key] {
        dictionary.keys.compactMap { Key(stringValue: $0) }
    }

    func contains(_ key: Key) -> Bool {
        rawValue(for: key) != nil
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        guard let raw = rawValue(for: key) else { return true }
        return raw is NSNull
    }

    func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T: Decodable {
        try decodeGeneric(type, forKey: key)
    }

    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        try decodeGeneric(type, forKey: key)
    }

    func decode(_ type: String.Type, forKey key: Key) throws -> String {
        try decodeGeneric(type, forKey: key)
    }

    func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
        try decodeGeneric(type, forKey: key)
    }

    func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
        try decodeGeneric(type, forKey: key)
    }

    func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
        try decodeGeneric(type, forKey: key)
    }

    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
        try decodeGeneric(type, forKey: key)
    }

    func decodeIfPresent<T>(_ type: T.Type, forKey key: Key) throws -> T? where T: Decodable {
        try decodeIfPresentGeneric(type, forKey: key)
    }

    func decodeIfPresent(_ type: Bool.Type, forKey key: Key) throws -> Bool? {
        try decodeIfPresentGeneric(type, forKey: key)
    }

    func decodeIfPresent(_ type: String.Type, forKey key: Key) throws -> String? {
        try decodeIfPresentGeneric(type, forKey: key)
    }

    func decodeIfPresent(_ type: Double.Type, forKey key: Key) throws -> Double? {
        try decodeIfPresentGeneric(type, forKey: key)
    }

    func decodeIfPresent(_ type: Float.Type, forKey key: Key) throws -> Float? {
        try decodeIfPresentGeneric(type, forKey: key)
    }

    func decodeIfPresent(_ type: Int.Type, forKey key: Key) throws -> Int? {
        try decodeIfPresentGeneric(type, forKey: key)
    }

    func decodeIfPresent(_ type: Int64.Type, forKey key: Key) throws -> Int64? {
        try decodeIfPresentGeneric(type, forKey: key)
    }

    private func decodeGeneric<T>(_ type: T.Type, forKey key: Key) throws -> T where T: Decodable {
        let keyPath = codingPath + [key]
        guard let raw = rawValue(for: key) else {
            if let fallback = _ZWBDecoder.defaultValue(T.self, context: context, codingPath: keyPath) {
                context.log(path: keyPath, "key not found, used type default")
                return fallback
            }
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: keyPath, debugDescription: "No value associated with key \(key.stringValue)."))
        }
        return try _ZWBDecoder.unbox(T.self, from: raw, context: context, codingPath: keyPath)
    }

    private func decodeIfPresentGeneric<T>(_ type: T.Type, forKey key: Key) throws -> T? where T: Decodable {
        let keyPath = codingPath + [key]
        guard let raw = rawValue(for: key) else {
            context.log(path: keyPath, "key not found, fallback nil")
            return nil
        }
        if ZWBValueConverter.isNullLike(raw) {
            context.log(path: keyPath, "got null-like value, fallback nil")
            return nil
        }
        do {
            return try _ZWBDecoder.unbox(T.self, from: raw, context: context, codingPath: keyPath)
        } catch {
            context.log(path: keyPath, "decode failed, fallback nil")
            return nil
        }
    }

    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
        let raw = rawValue(for: key) ?? [String: Any]()
        let decoder = _ZWBDecoder(value: raw, context: context, codingPath: codingPath + [key])
        return try decoder.container(keyedBy: type)
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        let raw = rawValue(for: key) ?? [Any]()
        let decoder = _ZWBDecoder(value: raw, context: context, codingPath: codingPath + [key])
        return try decoder.unkeyedContainer()
    }

    func superDecoder() throws -> Decoder {
        _ZWBDecoder(value: dictionary, context: context, codingPath: codingPath)
    }

    func superDecoder(forKey key: Key) throws -> Decoder {
        _ZWBDecoder(value: rawValue(for: key) ?? [String: Any](), context: context, codingPath: codingPath + [key])
    }

    private func rawValue(for key: Key) -> Any? {
        let keys = candidateKeys(for: key)
        for candidate in keys {
            if let value = value(at: candidate) {
                return value
            }
        }
        return nil
    }

    private func candidateKeys(for key: Key) -> [String] {
        var keys = [key.stringValue]

        if let aliases = keyMapping[key.stringValue] {
            keys.append(contentsOf: aliases)
        }

        return Array(Set(keys))
    }

    private func value(at keyPath: String) -> Any? {
        if !keyPath.contains(".") {
            return dictionary[keyPath]
        }

        var current: Any? = dictionary
        for component in keyPath.split(separator: ".").map(String.init) {
            guard let dict = current as? [String: Any] else { return nil }
            current = dict[component]
        }
        return current
    }
}

struct ZWBUnkeyedDecodingContainer: UnkeyedDecodingContainer {
    let array: [Any]
    let context: ZWBDecodingContext
    let codingPath: [CodingKey]
    var currentIndex: Int = 0

    var count: Int? { array.count }
    var isAtEnd: Bool { currentIndex >= array.count }

    mutating func decodeNil() throws -> Bool {
        guard !isAtEnd else { return true }
        if array[currentIndex] is NSNull {
            currentIndex += 1
            return true
        }
        return false
    }

    mutating func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        let index = currentIndex
        currentIndex += 1
        let itemPath = codingPath + [ZWBAnyCodingKey(intValue: index)]
        return try _ZWBDecoder.unbox(T.self, from: array[index], context: context, codingPath: itemPath)
    }

    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
        let index = currentIndex
        currentIndex += 1
        let decoder = _ZWBDecoder(value: array[index], context: context, codingPath: codingPath + [ZWBAnyCodingKey(intValue: index)])
        return try decoder.container(keyedBy: type)
    }

    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        let index = currentIndex
        currentIndex += 1
        let decoder = _ZWBDecoder(value: array[index], context: context, codingPath: codingPath + [ZWBAnyCodingKey(intValue: index)])
        return try decoder.unkeyedContainer()
    }

    mutating func superDecoder() throws -> Decoder {
        let index = currentIndex
        currentIndex += 1
        return _ZWBDecoder(value: array[index], context: context, codingPath: codingPath + [ZWBAnyCodingKey(intValue: index)])
    }
}

struct ZWBSingleValueDecodingContainer: SingleValueDecodingContainer {
    let value: Any
    let context: ZWBDecodingContext
    let codingPath: [CodingKey]

    func decodeNil() -> Bool {
        value is NSNull
    }

    func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        try _ZWBDecoder.unbox(T.self, from: value, context: context, codingPath: codingPath)
    }
}

public final class ZWBGlobalKeyMapping {
    public static let shared = ZWBGlobalKeyMapping()
    public var mapping: [String: [String: [String]]] = [:]

    private init() {}
}
