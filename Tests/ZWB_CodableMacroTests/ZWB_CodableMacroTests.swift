import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
@testable import ZWB_CodableMacros

final class ZWB_CodableMacroTests: XCTestCase {
    private let macros: [String: Macro.Type] = [
        "ZWB_Codable": ZWBCodableMacro.self
    ]

    func testClassAddsConformanceAndRequiredInit() {
        assertMacroExpansion(
            """
            @ZWB_Codable
            final class LiveCallModel {
                var callId: Int?
            }
            """,
            expandedSource:
            """
            final class LiveCallModel {
                var callId: Int?

                required init() {
                }
            }

            extension LiveCallModel: ZWBCodable {
            }
            """,
            macros: macros
        )
    }

    func testStructAddsConformanceOnly() {
        assertMacroExpansion(
            """
            @ZWB_Codable
            struct LiveCallModel {
                var callId: Int?
            }
            """,
            expandedSource:
            """
            struct LiveCallModel {
                var callId: Int?
            }

            extension LiveCallModel: ZWBCodable {
            }
            """,
            macros: macros
        )
    }
}
