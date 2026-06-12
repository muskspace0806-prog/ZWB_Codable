<h3 align="left">
  <strong>中文</strong> | <a href="./README.en.md">English</a>
</h3>

# ZWB_Codable

`ZWB_Codable` 是一个基于 Swift `Codable` 的宽松解析库，用来处理后端 JSON 不稳定导致的解析失败问题，例如字段类型偶发不一致、空字符串、`null`、对象和数组互换、字段改名、IM 消息体是 JSON 字符串等。

当前版本包含两层能力：

- **SPM macro 用法**：`@ZWB_Codable`，推荐 Swift/UIKit 项目使用，Xcode 15 / Swift 5.9+。
- **runtime 协议用法**：`ZWBCodable`，兼容 CocoaPods 和不方便启用 macro 的项目。

iOS 最低支持 14。

## 使用方式选择

| 集成方式 | 推荐写法 | 说明 |
|----------|----------|------|
| Swift Package Manager | `@ZWB_Codable` | 推荐。模型前加一行，class 不需要手写 `required init() {}`。 |
| CocoaPods | `ZWBCodable` | 当前 Pod 先走 runtime 协议版，需要 class 手写 `required init() {}`。 |

> `@ZWB_Codable` 是 Swift macro，当前通过 SPM 提供。CocoaPods 版本暂时不暴露 macro，避免 Pod 集成时因为 macro target / swift-syntax 支持不稳定导致编译失败。

## 安装

Swift Package Manager:

```swift
.package(url: "https://github.com/muskspace0806-prog/ZWB_Codable.git", from: "0.1.0")
```

CocoaPods:

```ruby
pod 'ZWB_Codable', '~> 0.1.0'
```

## 推荐用法：@ZWB_Codable

通过 SPM 集成时，Swift/UIKit 项目可以直接在模型前加 `@ZWB_Codable`。它和 UIKit 没有冲突，因为 macro 只作用在 Swift 模型编译阶段。

```swift
import ZWB_Codable

@ZWB_Codable
final class LiveCallModel {
    var callId: Int?
}

let model = try LiveCallModel.zwbDecode(from: #"{"callId":"123"}"#)
print(model.callId) // Optional(123)
```

本地声明的 Swift 类型优先。比如本地是 `Int?`，后端返回 `"123"`，最终会转成 `Int`，不会变成字符串。

macro 会自动补上 `ZWBCodable` 协议和 class 所需的 `required init() {}`。所以你的老模型可以从：

```swift
class GMDiscoverRankListModel: Codable {
    var headwearUrl: String?
}
```

改成：

```swift
@ZWB_Codable
class GMDiscoverRankListModel {
    var headwearUrl: String?
}
```

如果 `headwearUrl` 后端返回 `nil`、`null`、空字符串，会解析成 `nil`；如果返回 `123`，会解析成 `"123"`。

## CocoaPods / runtime 用法

CocoaPods 当前先使用 runtime 协议版，暂时不能用 `@ZWB_Codable`：

```swift
import ZWB_Codable

final class LiveCallModel: ZWBCodable {
    var callId: Int?

    required init() {}
}
```

`ZWBCodable` 是协议，不是继承基类，不会占用你的 class 继承位。

## Bool 脏数据兜底

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

## 对象和数组兼容

如果本地模型期望对象，但后端返回数组，默认取数组第一个元素：

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

如果消息体不是 JSON，`bodyKind` 会是 `.text`，原始内容仍然保存在 `rawString`。

## 从样本生成 IM 模型

包内提供一个开发期模型生成工具，可以根据 IM 样本 JSON 推断 Swift 模型。

```bash
swift run zwb-codable-generate --name GiftIMModel --input Example/IMGiftSample.json --class --macro
```

示例输出：

```swift
@ZWB_Codable
final class GiftIMModel {
    var gift: GiftIMModelGift?
    var giftId: Int?
    var giftName: String?
    var isCombo: Bool?
}
```

写入或更新已有文件：

```bash
swift run zwb-codable-generate \
  --name GiftIMModel \
  --input Example/IMGiftSample.json \
  --class \
  --macro \
  --output Example/GiftIMModel.swift
```

如果文件中已经有 `GiftIMModel`，工具会保留已有属性，只追加缺失属性。它是保守的源码合并工具，不会删除或重写你的自定义代码。

如果你使用 CocoaPods 或暂时不启用 macro，可以去掉 `--macro`，生成器会输出 `ZWBCodable + required init() {}` 风格。

## 当前边界

`@ZWB_Codable` 当前负责自动补协议和空初始化，实际宽松解析仍由 runtime decoder 完成。因此兜底使用类型默认值：

- `Int` -> `0`
- `String` -> `""`
- `Bool` -> `false`
- `Array` -> `[]`
- `Dictionary` -> `[:]`
- `ZWBCodable` 模型 -> `init()`
- optional -> `nil`

当前版本暂时无法读取 `var count: Int = 8` 这种自定义属性默认值里的 `8`，兜底会使用类型默认值。后续可以继续增强 macro，让它生成更精确的字段级默认值解码代码。

模型生成器是开发期工具，会在 App 编译前更新 Swift 源码；它不会在 App 运行时给已经编译好的 Swift class 动态添加 stored property。
