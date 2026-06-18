import Foundation

public enum ZWBLogMode: Sendable {
    case none
    case verbose
}

public struct ZWBDecodingLog: Sendable {
    public let path: String
    public let message: String
}

public enum ZWBCodableLogger {
    public static var mode: ZWBLogMode = .none
    public static var onLog: ((ZWBDecodingLog) -> Void)?

    static func emit(_ logs: [ZWBDecodingLog]) {
        guard mode == .verbose else { return }
        for log in logs {
            if let onLog {
                onLog(log)
            } else {
                print("[ZWB_Codable] \(log.path): \(log.message)")
            }
        }
    }
}

final class ZWBDecodingContext {
    let options: ZWBDecodingOptions
    private var logs: [ZWBDecodingLog] = []

    init(options: ZWBDecodingOptions) {
        self.options = options
    }

    func log(path: [CodingKey], _ message: String) {
        let pathText = path.map(\.stringValue).joined(separator: ".")
        logs.append(ZWBDecodingLog(path: pathText.isEmpty ? "<root>" : pathText, message: message))
    }

    func flushLogs() {
        ZWBCodableLogger.emit(logs)
    }
}
