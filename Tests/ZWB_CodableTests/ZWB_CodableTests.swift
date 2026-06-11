import XCTest
@testable import ZWB_Codable

final class ZWB_CodableTests: XCTestCase {
    func testStringNumberConvertsToLocalIntType() throws {
        final class LiveCallModel: ZWBCodable {
            var callId: Int?
            required init() {}
        }

        let model = try LiveCallModel.zwbDecode(from: #"{"callId":"123"}"#)

        XCTAssertEqual(model.callId, 123)
    }

    func testBoolFallbacksForDirtyValues() throws {
        final class LiveCreateCheakModel: ZWBCodable {
            var autoIdal: Bool?
            var autoIdalEdit: Bool?
            var autoMsgCheck: Bool?
            var liveCheck: Bool?
            var voiceCheck: Bool?
            required init() {}
        }

        let json = """
        {
            "autoIdal": true,
            "autoIdalEdit": 1,
            "autoMsgCheck": "yes",
            "liveCheck": "",
            "voiceCheck": null
        }
        """

        let model = try LiveCreateCheakModel.zwbDecode(from: json)

        XCTAssertEqual(model.autoIdal, true)
        XCTAssertEqual(model.autoIdalEdit, true)
        XCTAssertEqual(model.autoMsgCheck, true)
        XCTAssertNil(model.liveCheck)
        XCTAssertNil(model.voiceCheck)
    }

    func testNonOptionalUsesTypeDefaultWhenDirty() throws {
        struct RoomModel: ZWBCodable {
            var roomId: Int = 0
            var title: String = ""
            var isLiving: Bool = false
        }

        let model = try RoomModel.zwbDecode(from: #"{"roomId":"abc","title":null,"isLiving":""}"#)

        XCTAssertEqual(model.roomId, 0)
        XCTAssertEqual(model.title, "")
        XCTAssertEqual(model.isLiving, false)
    }

    func testKeyMappingAndNestedPath() throws {
        struct UserModel: ZWBCodable {
            var userId: Int = 0
            var nickName: String = ""

            static var zwbKeyMapping: [String: [String]] {
                [
                    "userId": ["user_id", "uid"],
                    "nickName": ["data.profile.nick"]
                ]
            }
        }

        let json = """
        {
            "uid": "7788",
            "data": {
                "profile": {
                    "nick": 9527
                }
            }
        }
        """

        let model = try UserModel.zwbDecode(from: json)

        XCTAssertEqual(model.userId, 7788)
        XCTAssertEqual(model.nickName, "9527")
    }

    func testObjectCanDecodeFromFirstArrayElement() throws {
        struct Profile: ZWBCodable {
            var name: String = ""
        }

        struct User: ZWBCodable {
            var profile: Profile = .init()
        }

        let model = try User.zwbDecode(from: #"{"profile":[{"name":"Ada"}]}"#)

        XCTAssertEqual(model.profile.name, "Ada")
    }

    func testArrayCanDecodeFromSingleObject() throws {
        struct Gift: ZWBCodable, Equatable {
            var id: Int = 0
        }

        struct Payload: ZWBCodable {
            var gifts: [Gift] = []
        }

        let model = try Payload.zwbDecode(from: #"{"gifts":{"id":"7"}}"#)

        XCTAssertEqual(model.gifts, [Gift(id: 7)])
    }

    func testStringifiedJSONObjectCanDecodeAsModel() throws {
        struct Hobby: ZWBCodable {
            var name: String = ""
        }

        struct User: ZWBCodable {
            var hobby: Hobby?
        }

        let model = try User.zwbDecode(from: #"{"hobby":"{\"name\":\"sleep\"}"}"#)

        XCTAssertEqual(model.hobby?.name, "sleep")
    }

    func testVerboseLogsDescribeFallbacks() throws {
        final class LiveCallModel: ZWBCodable {
            var callId: Int?
            var name: String = ""
            required init() {}
        }

        var logs: [String] = []
        ZWBCodableLogger.mode = .verbose
        ZWBCodableLogger.onLog = { logs.append("\($0.path): \($0.message)") }
        defer {
            ZWBCodableLogger.mode = .none
            ZWBCodableLogger.onLog = nil
        }

        _ = try LiveCallModel.zwbDecode(from: #"{"callId":"123"}"#)

        XCTAssertTrue(logs.contains { $0.contains("callId") && $0.contains("converted") })
        XCTAssertTrue(logs.contains { $0.contains("name") && $0.contains("key not found") })
    }

    func testIMDecoderKeepsRawJSONWhenModelIsPartial() throws {
        final class GiftIMModel: ZWBCodable {
            var giftId: Int?
            required init() {}
        }

        let body = """
        {
            "giftId": "1001",
            "gift": {
                "name": "rose",
                "combo": {
                    "count": "10"
                }
            }
        }
        """

        let message = ZWBIMDecoder.decodeSafely(GiftIMModel.self, from: body)

        XCTAssertEqual(message.model?.giftId, 1001)
        XCTAssertEqual(message.bodyKind, .object)
        XCTAssertEqual(message.rawJSON?["gift"]["name"].stringValue, "rose")
        XCTAssertEqual(message.rawJSON?["gift"]["combo"]["count"].intValue, 10)
    }

    func testIMDecoderTreatsNonJSONBodyAsText() {
        struct EmptyModel: ZWBCodable {}

        let message = ZWBIMDecoder.decodeSafely(EmptyModel.self, from: "hello")

        XCTAssertNil(message.model)
        XCTAssertNil(message.rawJSON)
        XCTAssertEqual(message.bodyKind, .text)
        XCTAssertFalse(message.warnings.isEmpty)
    }

    func testZWBJSONValueCanBeDecodedAsModelProperty() throws {
        struct Envelope: ZWBCodable {
            var raw: ZWBJSONValue?
        }

        let envelope = try Envelope.zwbDecode(from: #"{"raw":{"count":"10","name":"rose"}}"#)

        XCTAssertEqual(envelope.raw?["count"].intValue, 10)
        XCTAssertEqual(envelope.raw?["name"].stringValue, "rose")
    }
}
