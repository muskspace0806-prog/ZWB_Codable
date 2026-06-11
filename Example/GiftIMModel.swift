import Foundation
import ZWB_Codable

final class GiftIMModel: ZWBCodable {
    var giftId: Int?
    var gift: GiftIMModelGift?
    var giftName: String?
    var isCombo: Bool?

    required init() {}
}

final class GiftIMModelGiftCombo: ZWBCodable {
    var count: Int?

    required init() {}
}

final class GiftIMModelGift: ZWBCodable {
    var combo: GiftIMModelGiftCombo?
    var price: Double?

    required init() {}
}
