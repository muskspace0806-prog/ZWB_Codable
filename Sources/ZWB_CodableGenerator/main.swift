import Foundation

struct GeneratorOptions {
    var rootName = "ZWBGeneratedModel"
    var inputPath: String?
    var outputPath: String?
    var classModels = false
}

enum GeneratorError: Error, CustomStringConvertible {
    case missingInput
    case unreadableInput(String)
    case invalidJSON
    case writeFailed(String)

    var description: String {
        switch self {
        case .missingInput:
            return "Missing --input <path>. Use --input sample.json or pipe JSON through stdin."
        case .unreadableInput(let path):
            return "Could not read input file: \(path)"
        case .invalidJSON:
            return "Input is not valid JSON object or array."
        case .writeFailed(let path):
            return "Could not write output file: \(path)"
        }
    }
}

indirect enum InferredType: Equatable {
    case string
    case int
    case double
    case bool
    case object(String, [Field])
    case array(InferredType)
    case json

    var swiftType: String {
        switch self {
        case .string:
            return "String?"
        case .int:
            return "Int?"
        case .double:
            return "Double?"
        case .bool:
            return "Bool?"
        case .object(let name, _):
            return "\(name)?"
        case .array(let element):
            return "[\(element.optionalUnwrappedSwiftType)]"
        case .json:
            return "ZWBJSONValue?"
        }
    }

    private var optionalUnwrappedSwiftType: String {
        let type = swiftType
        return type.hasSuffix("?") ? String(type.dropLast()) : type
    }
}

struct Field: Equatable {
    let name: String
    let type: InferredType
}

do {
    try run()
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(1)
}

func run() throws {
    let options = try parseOptions()
    let input = try readInput(options)
    let json = try parseJSON(input)
    let rootObject = normalizeRootObject(json)
    let fields = inferFields(from: rootObject, modelName: options.rootName)
    let code = renderCode(rootName: options.rootName, fields: fields, classModels: options.classModels)
    try writeOutput(code: code, rootName: options.rootName, fields: fields, options: options)
}

func parseOptions() throws -> GeneratorOptions {
    var options = GeneratorOptions()
    var iterator = CommandLine.arguments.dropFirst().makeIterator()

    while let argument = iterator.next() {
        switch argument {
        case "--name":
            if let value = iterator.next() {
                options.rootName = sanitizeTypeName(value)
            }
        case "--input":
            options.inputPath = iterator.next()
        case "--output":
            options.outputPath = iterator.next()
        case "--class":
            options.classModels = true
        case "--struct":
            options.classModels = false
        case "--help", "-h":
            printUsageAndExit()
        default:
            break
        }
    }

    return options
}

func writeOutput(code: String, rootName: String, fields: [Field], options: GeneratorOptions) throws {
    guard let outputPath = options.outputPath else {
        FileHandle.standardOutput.write(Data(code.utf8))
        return
    }

    let manager = FileManager.default
    if !manager.fileExists(atPath: outputPath) {
        guard (try? code.write(toFile: outputPath, atomically: true, encoding: .utf8)) != nil else {
            throw GeneratorError.writeFailed(outputPath)
        }
        print("Generated \(outputPath)")
        return
    }

    guard let existing = try? String(contentsOfFile: outputPath, encoding: .utf8) else {
        throw GeneratorError.unreadableInput(outputPath)
    }
    let merged = mergeGeneratedCode(existing: existing, generated: code, rootName: rootName, fields: fields)
    guard (try? merged.write(toFile: outputPath, atomically: true, encoding: .utf8)) != nil else {
        throw GeneratorError.writeFailed(outputPath)
    }
    print("Updated \(outputPath)")
}

func readInput(_ options: GeneratorOptions) throws -> String {
    if let path = options.inputPath {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
            throw GeneratorError.unreadableInput(path)
        }
        return text
    }

    let data = FileHandle.standardInput.readDataToEndOfFile()
    guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else {
        throw GeneratorError.missingInput
    }
    return text
}

func parseJSON(_ input: String) throws -> Any {
    guard let data = input.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
        throw GeneratorError.invalidJSON
    }
    return json
}

func normalizeRootObject(_ json: Any) -> [String: Any] {
    if let object = json as? [String: Any] {
        return object
    }
    if let array = json as? [Any], let first = array.first as? [String: Any] {
        return first
    }
    return ["value": json]
}

func inferFields(from object: [String: Any], modelName: String) -> [Field] {
    object.keys.sorted().map { key in
        let fieldName = sanitizePropertyName(key)
        let childName = sanitizeTypeName(modelName + "_" + fieldName)
        return Field(name: fieldName, type: inferType(from: object[key] ?? NSNull(), suggestedName: childName))
    }
}

func inferType(from value: Any, suggestedName: String) -> InferredType {
    if value is NSNull {
        return .json
    }
    if value is Bool {
        return .bool
    }
    if let number = value as? NSNumber {
        let double = number.doubleValue
        return floor(double) == double ? .int : .double
    }
    if let string = value as? String {
        if Int(string.trimmingCharacters(in: .whitespacesAndNewlines)) != nil {
            return .int
        }
        if Double(string.trimmingCharacters(in: .whitespacesAndNewlines)) != nil {
            return .double
        }
        if ["true", "false", "yes", "no", "1", "0"].contains(string.lowercased()) {
            return .bool
        }
        if let data = string.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) {
            return inferType(from: json, suggestedName: suggestedName)
        }
        return .string
    }
    if let object = value as? [String: Any] {
        return .object(suggestedName, inferFields(from: object, modelName: suggestedName))
    }
    if let array = value as? [Any] {
        return inferArrayType(from: array, suggestedName: suggestedName + "Item")
    }
    return .json
}

func inferArrayType(from array: [Any], suggestedName: String) -> InferredType {
    guard let first = array.first else {
        return .array(.json)
    }
    return .array(inferType(from: first, suggestedName: suggestedName))
}

func renderCode(rootName: String, fields: [Field], classModels: Bool) -> String {
    var rendered: [String] = ["import Foundation", "import ZWB_Codable", ""]
    var emitted = Set<String>()

    func emitModel(name: String, fields: [Field]) {
        guard emitted.insert(name).inserted else { return }

        for field in fields {
            collectNestedModels(from: field.type)
        }

        if classModels {
            rendered.append("final class \(name): ZWBCodable {")
        } else {
            rendered.append("struct \(name): ZWBCodable {")
        }

        for field in fields {
            rendered.append("    var \(field.name): \(field.type.swiftType)")
        }

        if classModels {
            if !fields.isEmpty { rendered.append("") }
            rendered.append("    required init() {}")
        }

        rendered.append("}")
        rendered.append("")
    }

    func collectNestedModels(from type: InferredType) {
        switch type {
        case .object(let name, let childFields):
            emitModel(name: name, fields: childFields)
        case .array(let element):
            collectNestedModels(from: element)
        default:
            break
        }
    }

    emitModel(name: rootName, fields: fields)
    return rendered.joined(separator: "\n")
}

func mergeGeneratedCode(existing: String, generated: String, rootName: String, fields: [Field]) -> String {
    var result = existing
    let existingFieldNames = Set(extractPropertyNames(from: existing))
    let missingFields = fields.filter { !existingFieldNames.contains($0.name.trimmingCharacters(in: CharacterSet(charactersIn: "`"))) }

    if !missingFields.isEmpty, let range = findTypeBodyRange(in: result, typeName: rootName) {
        let insertionIndex = findPropertyInsertionIndex(in: result, bodyRange: range) ?? range.upperBound
        let fieldLines = missingFields
            .map { "    var \($0.name): \($0.type.swiftType)" }
            .joined(separator: "\n")
        let prefix = insertionIndex > result.startIndex && result[result.index(before: insertionIndex)] != "\n" ? "\n" : ""
        result.insert(contentsOf: prefix + fieldLines + "\n", at: insertionIndex)
    }

    for block in extractTypeBlocks(from: generated) where !typeExists(in: result, typeName: block.name) {
        if !result.hasSuffix("\n") { result.append("\n") }
        result.append("\n")
        result.append(block.code)
        if !result.hasSuffix("\n") { result.append("\n") }
    }

    if !result.contains("import ZWB_Codable") {
        result = "import ZWB_Codable\n" + result
    }
    return result
}

func extractPropertyNames(from source: String) -> [String] {
    let pattern = #"\bvar\s+(`?[A-Za-z_][A-Za-z0-9_]*`?)\s*:"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
    let range = NSRange(source.startIndex..<source.endIndex, in: source)
    return regex.matches(in: source, range: range).compactMap { match in
        guard let swiftRange = Range(match.range(at: 1), in: source) else { return nil }
        return String(source[swiftRange]).trimmingCharacters(in: CharacterSet(charactersIn: "`"))
    }
}

func findTypeBodyRange(in source: String, typeName: String) -> Range<String.Index>? {
    guard let declaration = source.range(of: #"(final\s+class|class|struct)\s+\#(typeName)\b[^{]*\{"#, options: .regularExpression) else {
        return nil
    }
    var depth = 1
    let bodyStart = declaration.upperBound
    var index = declaration.upperBound
    while index < source.endIndex {
        let character = source[index]
        if character == "{" {
            depth += 1
        } else if character == "}" {
            depth -= 1
            if depth == 0 {
                return bodyStart..<index
            }
        }
        index = source.index(after: index)
    }
    return nil
}

func findPropertyInsertionIndex(in source: String, bodyRange: Range<String.Index>) -> String.Index? {
    let body = source[bodyRange]
    if let requiredInit = body.range(of: #"\n\s*required\s+init\s*\("#, options: .regularExpression) {
        return requiredInit.lowerBound
    }
    return bodyRange.upperBound
}

func typeExists(in source: String, typeName: String) -> Bool {
    source.range(of: #"(final\s+class|class|struct)\s+\#(typeName)\b"#, options: .regularExpression) != nil
}

func extractTypeBlocks(from source: String) -> [(name: String, code: String)] {
    let pattern = #"(final\s+class|class|struct)\s+([A-Za-z_][A-Za-z0-9_]*)\b"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
    let nsRange = NSRange(source.startIndex..<source.endIndex, in: source)
    return regex.matches(in: source, range: nsRange).compactMap { match in
        guard let nameRange = Range(match.range(at: 2), in: source),
              let startRange = Range(match.range(at: 0), in: source) else { return nil }
        let name = String(source[nameRange])
        guard let bodyRange = findTypeBodyRange(in: source, typeName: name) else { return nil }
        let blockStart = startRange.lowerBound
        let blockEnd = source.index(after: bodyRange.upperBound)
        return (name, String(source[blockStart..<blockEnd]))
    }
}

func sanitizeTypeName(_ value: String) -> String {
    let parts = splitIdentifier(value)
    let name = parts.map { String($0.prefix(1)).uppercased() + String($0.dropFirst()) }.joined()
    return name.isEmpty ? "ZWBGeneratedModel" : name
}

func sanitizePropertyName(_ value: String) -> String {
    let parts = splitIdentifier(value)
    guard let first = parts.first else { return "value" }
    let tail = parts.dropFirst().map { String($0.prefix(1)).uppercased() + String($0.dropFirst()) }.joined()
    let name = first + tail
    if SwiftKeywords.all.contains(name) {
        return "`\(name)`"
    }
    if name.first?.isNumber == true {
        return "value\(String(name.prefix(1)).uppercased() + String(name.dropFirst()))"
    }
    return name
}

func splitIdentifier(_ value: String) -> [String] {
    value
        .replacingOccurrences(of: "-", with: "_")
        .replacingOccurrences(of: ".", with: "_")
        .split(separator: "_")
        .map { part in
            part.filter { $0.isLetter || $0.isNumber }
        }
        .filter { !$0.isEmpty }
        .map { String($0.prefix(1)).lowercased() + String($0.dropFirst()) }
}

func printUsageAndExit() -> Never {
    print("""
    Usage:
      swift run zwb-codable-generate --name GiftIMModel --input sample.json
      swift run zwb-codable-generate --name GiftIMModel --input sample.json --class

    Options:
      --name <TypeName>    Root Swift model name. Default: ZWBGeneratedModel
      --input <path>       JSON sample file. If omitted, stdin is used.
      --output <path>      Write or merge generated model into a Swift file.
      --class              Generate final class models with required init().
      --struct             Generate struct models. This is the default.
    """)
    exit(0)
}

enum SwiftKeywords {
    static let all: Set<String> = [
        "class", "struct", "enum", "protocol", "extension", "func", "let", "var",
        "import", "switch", "case", "default", "where", "for", "while", "if",
        "else", "return", "true", "false", "nil", "self", "Self", "Type"
    ]
}
