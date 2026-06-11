<h3 align="left">
  <strong>中文</strong> | <a href="./README.en.md">English</a>
</h3>

# ZWB_Codable

`ZWB_Codable` 是一个基于 Swift `Codable` 的宽松解析库，用来处理后端 JSON 不稳定导致的解析失败问题，例如字段类型偶发不一致、空字符串、`null`、对象和数组互换、字段改名、IM 消息体是 JSON 字符串等。

当前版本是无第三方依赖的 runtime 解码器，支持 CocoaPods 和 Swift Package Manager，最低支持 iOS 14。

## 安装

Swift Package Manager:

```swift
.package(url: "https://github.com/muskspace0806-prog/ZWB_Codable.git", from: "0.1.0")
```

CocoaPods:

```ruby
pod 'ZWB_Codable', '~> 0.1.0'
```

## 基础用法

```swift
import ZWB_Codable

final class LiveCallModel: ZWBCodable {
    var callId: Int?

    required init() {}
}

let model = try LiveCallModel.zwbDecode(from: #"{"callId":"123"}"#)
print(model.callId) // Optional(123)
```

本地声明的 Swift 类型优先。比如本地是 `Int?`，后端返回 `"123"`，最终会转成 `Int`，不会变成字符串。

## Bool 脏数据兜底

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

后端返回：

```json
{
  "autoIdal": true,
  "autoIdalEdit": 1,
  "autoMsgCheck": "yes",
  "liveCheck": "",
  "voiceCheck": null
}
```

解析结果：

```swift
autoIdal      == true
autoIdalEdit  == true
autoMsgCheck  == true
liveCheck     == nil
voiceCheck    == nil
```

## 字段映射和嵌套路径

字段名偶发变化，或者字段从根节点移动到嵌套结构时，可以使用 `zwbKeyMapping`。

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

## 对象和数组兼容

如果本地模型期望对象，但后端返回数组，默认取数组第一个元素：

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

如果本地期望数组，但后端返回对象，默认会把对象包装成单元素数组。

## 调试日志

开启 verbose 日志后，可以看到哪个字段发生了转换或兜底，减少调试时反复跳进 `decodeIfPresent` 的问题。

```swift
ZWBCodableLogger.mode = .verbose
ZWBCodableLogger.onLog = { log in
    print("\(log.path): \(log.message)")
}
```

示例输出：

```text
callId: expected Int, got String("123"), converted
name: key not found, used type default
```

## IM JSON 字符串解析

IM 消息体经常是 JSON 字符串。`ZWBIMDecoder` 会自动解析字符串，优先生成本地模型，同时保留原始 JSON，避免服务端结构变化时消息直接丢失。

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

message.model?.giftId
message.rawJSON?["gift"]["name"].stringValue
message.rawJSON?["gift"]["combo"]["count"].intValue
```

如果消息体不是 JSON，`bodyKind` 会是 `.text`，原始内容仍然保存在 `rawString`。

## 从样本生成 IM 模型

包内提供一个开发期模型生成工具，可以根据 IM 样本 JSON 推断 Swift 模型。

```bash
swift run zwb-codable-generate --name GiftIMModel --input Example/IMGiftSample.json --class
```

示例输出：

```swift
final class GiftIMModel: ZWBCodable {
    var gift: GiftIMModelGift?
    var giftId: Int?
    var giftName: String?
    var isCombo: Bool?

    required init() {}
}
```

写入或更新已有文件：

```bash
swift run zwb-codable-generate \
  --name GiftIMModel \
  --input Example/IMGiftSample.json \
  --class \
  --output Example/GiftIMModel.swift
```

如果文件中已经有 `GiftIMModel`，工具会保留已有属性，只追加缺失属性。它是保守的源码合并工具，不会删除或重写你的自定义代码。

## 当前边界

runtime 版本兜底使用类型默认值：

- `Int` -> `0`
- `String` -> `""`
- `Bool` -> `false`
- `Array` -> `[]`
- `Dictionary` -> `[:]`
- `ZWBCodable` 模型 -> `init()`
- optional -> `nil`

当前 runtime 版本无法读取 `var count: Int = 8` 这种自定义属性默认值里的 `8`。后续如果增加 macro 层，可以保留这些精确默认值，也可以去掉 class 里手写 `required init() {}` 的要求。

模型生成器是开发期工具，会在 App 编译前更新 Swift 源码；它不会在 App 运行时给已经编译好的 Swift class 动态添加 stored property。
