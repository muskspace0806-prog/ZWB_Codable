# ZWB_Codable

`ZWB_Codable` is a tolerant layer on top of Swift `Codable`. It is designed for iOS projects where backend JSON may occasionally return inconsistent types, empty strings, `null`, object/array mismatches, or renamed fields.

The first implementation is a dependency-free runtime decoder that supports CocoaPods and Swift Package Manager with iOS 14+.

## Installation

### Swift Package Manager

```swift
.package(url: "https://github.com/muskspace0806-prog/ZWB_Codable.git", from: "0.1.0")
```

### CocoaPods

```ruby
pod 'ZWB_Codable', '~> 0.1.0'
```

## Basic Usage

```swift
import ZWB_Codable

final class LiveCallModel: ZWBCodable {
    var callId: Int?

    required init() {}
}

let model = try LiveCallModel.zwbDecode(from: #"{"callId":"123"}"#)
print(model.callId) // Optional(123)
```

The Swift property type wins. If local code declares `Int?`, a backend string such as `"123"` is converted to `Int`.

## Dirty Bool Values

```swift
final class LiveCreateCheakModel: ZWBCodable {
    var autoIdal: Bool?
    var autoIdalEdit: Bool?
    var autoMsgCheck: Bool?
    var liveCheck: Bool?
    var voiceCheck: Bool?

    required init() {}
}
```

```json
{
  "autoIdal": true,
  "autoIdalEdit": 1,
  "autoMsgCheck": "yes",
  "liveCheck": "",
  "voiceCheck": null
}
```

Result:

```swift
autoIdal      == true
autoIdalEdit  == true
autoMsgCheck  == true
liveCheck     == nil
voiceCheck    == nil
```

## Key Mapping

Use `zwbKeyMapping` for renamed fields or nested paths.

```swift
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
```

## Object And Array Compatibility

If a local model expects an object but the backend returns an array, the default strategy uses the first element:

```swift
struct Profile: ZWBCodable {
    var name: String = ""
}

struct User: ZWBCodable {
    var profile: Profile = .init()
}

let user = try User.zwbDecode(from: #"{"profile":[{"name":"Ada"}]}"#)
print(user.profile.name) // Ada
```

If a local model expects an array but receives an object, the object is wrapped as a single element by default.

## Debug Logs

```swift
ZWBCodableLogger.mode = .verbose
ZWBCodableLogger.onLog = { log in
    print("\(log.path): \(log.message)")
}
```

Example output:

```text
callId: expected Int, got String("123"), converted
name: key not found, used type default
```

This is meant to avoid stepping into repeated manual `decodeIfPresent` fallback code during debugging.

## IM JSON String Decoding

IM payloads often arrive as JSON strings. `ZWBIMDecoder` parses the string, tries to build the local model, and always keeps the raw JSON when the body is valid JSON.

```swift
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

message.model?.giftId                      // Optional(1001)
message.rawJSON?["gift"]["name"].stringValue
message.rawJSON?["gift"]["combo"]["count"].intValue
```

If the body is not JSON, `bodyKind` is `.text` and `rawString` still contains the original IM body.

## Generate IM Models From Samples

The package includes a local generator for development-time model creation.

```bash
swift run zwb-codable-generate --name GiftIMModel --input Example/IMGiftSample.json --class
```

Example output:

```swift
final class GiftIMModel: ZWBCodable {
    var gift: GiftIMModelGift?
    var giftId: Int?
    var giftName: String?
    var isCombo: Bool?

    required init() {}
}
```

To write or update a file:

```bash
swift run zwb-codable-generate \
  --name GiftIMModel \
  --input Example/IMGiftSample.json \
  --class \
  --output Example/GiftIMModel.swift
```

When the output file already contains `GiftIMModel`, existing properties are kept and only missing properties are appended. This is intentionally a conservative source merge: it does not remove or rewrite your custom code.

## Current Boundary

This first runtime version falls back to type defaults:

- `Int` -> `0`
- `String` -> `""`
- `Bool` -> `false`
- `Array` -> `[]`
- `Dictionary` -> `[:]`
- `ZWBCodable` model -> `init()`
- optional values -> `nil`

It cannot read a custom property initializer such as `var count: Int = 8` during runtime fallback. A future macro layer can generate code that preserves those exact initializer defaults and can also remove the need for `required init() {}` on classes.

The generator is a development tool. It updates Swift source files before building the app; it does not add stored properties to compiled Swift classes at runtime.
