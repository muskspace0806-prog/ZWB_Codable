import Foundation
import ZWB_Codable

@ZWB_Codable
final class GiftIMModel {
    var giftId: Int?
    var gift: GiftIMModelGift?
    var giftName: String?
    var isCombo: Bool?
}

@ZWB_Codable
final class GiftIMModelGiftCombo {
    var count: Int?
}

@ZWB_Codable
final class GiftIMModelGift {
    var combo: GiftIMModelGiftCombo?
    var price: Double?
}
