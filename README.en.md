<h3 align="left">
  <a href="./README.md">中文</a> | <strong>English</strong>
</h3>

# ZWB_Codable

`ZWB_Codable` is a tolerant layer on top of Swift `Codable`. It is designed for iOS projects where backend JSON may occasionally return inconsistent types, empty strings, `null`, object/array mismatches, renamed fields, or IM payloads encoded as JSON strings.

The current implementation has two layers:

- **SPM macro API**: `@ZWB_Codable`, recommended for Swift/UIKit projects with Xcode 15 / Swift 5.9+.
- **Runtime protocol API**: `ZWBCodable`, compatible with CocoaPods and projects that do not enable macros.

The minimum iOS version is 14.

## Choose An API

| Integration | Recommended API | Notes |
|-------------|-----------------|-------|
| Swift Package Manager | `@ZWB_Codable` | Recommended. Add one line before the model; classes do not need manual `required init() {}`. |
| CocoaPods | `ZWBCodable` | Current Pod integration uses the runtime protocol API and requires classes to define `required init() {}`. |

> `@ZWB_Codable` is a Swift macro and is currently provided through SPM. The CocoaPods version does not expose the macro yet, to avoid build failures caused by macro target / swift-syntax support differences in Pod integrations.

## Installation

Swift Package Manager:

```swift
.package(url: "https://github.com/muskspace0806-prog/ZWB_Codable.git", from: "0.1.0")
```

CocoaPods:

```ruby
pod 'ZWB_Codable', '~> 0.1.0'
```

## Recommended Usage: @ZWB_Codable

With SPM integration, Swift/UIKit projects can add `@ZWB_Codable` directly to model types. It does not conflict with UIKit because the macro only works at Swift model compile time.

```swift
import ZWB_Codable

@ZWB_Codable
final class LiveCallModel {
    var callId: Int?
}

let model = try LiveCallModel.zwbDecode(from: #"{"callId":"123"}"#)
print(model.callId) // Optional(123)
```

The local Swift property type wins. If local code declares `Int?`, a backend string such as `"123"` is converted to `Int`.

The macro automatically adds `ZWBCodable` conformance and the `required init() {}` needed by classes. Existing models can move from:

```swift
class GMDiscoverRankListModel: Codable {
    var headwearUrl: String?
}
```

to:

```swift
@ZWB_Codable
class GMDiscoverRankListModel {
    var headwearUrl: String?
}
```

If the backend returns `nil`, `null`, or an empty string for `headwearUrl`, the value becomes `nil`. If it returns `123`, the value becomes `"123"`.

## CocoaPods / Runtime Usage

CocoaPods currently uses the runtime protocol API and cannot use `@ZWB_Codable` yet:

```swift
import ZWB_Codable

final class LiveCallModel: ZWBCodable {
    var callId: Int?

    required init() {}
}
```

`ZWBCodable` is a protocol, not a base class, so it does not consume your class inheritance slot.

## Dirty Bool Values

```swift
@ZWB_Codable
final class LiveCreateCheakModel {
    var autoIdal: Bool?
    var autoIdalEdit: Bool?
    var autoMsgCheck: Bool?
    var liveCheck: Bool?
    var voiceCheck: Bool?
}
```

Backend JSON:

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

## Key Mapping And Nested Paths

Use `zwbKeyMapping` for renamed fields or nested paths.

```swift
@ZWB_Codable
struct UserModel {
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
@ZWB_Codable
struct Profile {
    var name: String = ""
}

@ZWB_Codable
struct User {
    var profile: Profile = .init()
}

let user = try User.zwbDecode(from: #"{"profile":[{"name":"Ada"}]}"#)
print(user.profile.name) // Ada
```

If a local model expects an array but receives an object, the object is wrapped as a single element by default.

## Debug Logs

Verbose logs show which fields were converted or fell back to defaults. This helps avoid stepping into repeated manual `decodeIfPresent` fallback code during debugging.

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

## IM JSON String Decoding

IM payloads often arrive as JSON strings. `ZWBIMDecoder` parses the string, tries to build the local model, and keeps the raw JSON when the body is valid JSON.

```swift
@ZWB_Codable
final class GiftIMModel {
    var giftId: Int?
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

message.model?.giftId
message.rawJSON?["gift"]["name"].stringValue
message.rawJSON?["gift"]["combo"]["count"].intValue
```

If the body is not JSON, `bodyKind` is `.text` and `rawString` still contains the original IM body.

## Generate IM Models From Samples

The package includes a local generator for development-time model creation.

```bash
swift run zwb-codable-generate --name GiftIMModel --input Example/IMGiftSample.json --class --macro
```

Example output:

```swift
@ZWB_Codable
final class GiftIMModel {
    var gift: GiftIMModelGift?
    var giftId: Int?
    var giftName: String?
    var isCombo: Bool?
}
```

To write or update a file:

```bash
swift run zwb-codable-generate \
  --name GiftIMModel \
  --input Example/IMGiftSample.json \
  --class \
  --macro \
  --output Example/GiftIMModel.swift
```

When the output file already contains `GiftIMModel`, existing properties are kept and only missing properties are appended. This is intentionally a conservative source merge: it does not remove or rewrite your custom code.

If you use CocoaPods or do not enable macros yet, omit `--macro`. The generator will output the `ZWBCodable + required init() {}` style.

## Current Boundary

`@ZWB_Codable` currently adds protocol conformance and an empty initializer. Tolerant decoding is still handled by the runtime decoder, so fallback uses type defaults:

- `Int` -> `0`
- `String` -> `""`
- `Bool` -> `false`
- `Array` -> `[]`
- `Dictionary` -> `[:]`
- `ZWBCodable` model -> `init()`
- optional values -> `nil`

It cannot read a custom property initializer such as `var count: Int = 8` during fallback yet. The current version falls back to type defaults. A future macro enhancement can generate field-level decoding code that preserves exact custom defaults.

The generator is a development tool. It updates Swift source files before building the app; it does not add stored properties to compiled Swift classes at runtime.
