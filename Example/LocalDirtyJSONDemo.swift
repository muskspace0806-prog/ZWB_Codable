import Foundation
import ZWB_Codable

final class LiveCallModel: ZWBCodable {
    var callId: Int?
    required init() {}
}

final class LiveCreateCheakModel: ZWBCodable {
    var autoIdal: Bool?
    var autoIdalEdit: Bool?
    var autoMsgCheck: Bool?
    var liveCheck: Bool?
    var voiceCheck: Bool?

    required init() {}
}

struct UserProfile: ZWBCodable {
    var name: String = ""
}

struct LiveRoomModel: ZWBCodable {
    var roomId: Int = 0
    var profile: UserProfile = .init()

    static var zwbKeyMapping: [String: [String]] {
        [
            "roomId": ["room_id", "data.room.id"],
            "profile": ["profiles"]
        ]
    }
}

ZWBCodableLogger.mode = .verbose

let call = try LiveCallModel.zwbDecode(from: #"{"callId":"123"}"#)
print("callId:", call.callId as Any)

let check = try LiveCreateCheakModel.zwbDecode(from: """
{
    "autoIdal": true,
    "autoIdalEdit": 1,
    "autoMsgCheck": "yes",
    "liveCheck": "",
    "voiceCheck": null
}
""")
print("autoMsgCheck:", check.autoMsgCheck as Any)

let room = try LiveRoomModel.zwbDecode(from: """
{
    "data": {
        "room": {
            "id": "9527"
        }
    },
    "profiles": [
        {
            "name": 12345
        }
    ]
}
""")
print("roomId:", room.roomId)
print("profile.name:", room.profile.name)

let imBody = """
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

final class GiftIMRuntimeModel: ZWBCodable {
    var giftId: Int?
    required init() {}
}

let imMessage = ZWBIMDecoder.decodeSafely(GiftIMRuntimeModel.self, from: imBody)
print("im.giftId:", imMessage.model?.giftId as Any)
print("im.raw.gift.name:", imMessage.rawJSON?["gift"]["name"].stringValue as Any)
print("im.raw.gift.combo.count:", imMessage.rawJSON?["gift"]["combo"]["count"].intValue as Any)
