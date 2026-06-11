//
//  ViewController.swift
//  ZWB_Codable
//
//  Created by hule on 2026/6/11.
//

import UIKit

final class ViewController: UIViewController {
    private let stackView = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "ZWB_Codable"
        buildDemo()
    }

    private func buildDemo() {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        stackView.axis = .vertical
        stackView.spacing = 14
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 18),
            stackView.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -18),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20)
        ])

        stackView.addArrangedSubview(titleView())
        stackView.addArrangedSubview(sectionView(title: "类型兜底", body: decodeBasicExample()))
        stackView.addArrangedSubview(sectionView(title: "IM JSON 字符串", body: decodeIMExample()))
        stackView.addArrangedSubview(sectionView(title: "模型生成命令", body: generatorExample()))
    }

    private func titleView() -> UIView {
        let label = UILabel()
        label.numberOfLines = 0
        label.text = "ZWB_Codable Demo\n直接看脏 JSON 如何解析成安全模型"
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = .label
        return label
    }

    private func sectionView(title: String, body: String) -> UIView {
        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 8
        container.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .label

        let bodyLabel = UILabel()
        bodyLabel.numberOfLines = 0
        bodyLabel.text = body
        bodyLabel.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        bodyLabel.textColor = .secondaryLabel

        let innerStack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel])
        innerStack.axis = .vertical
        innerStack.spacing = 10
        innerStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(innerStack)

        NSLayoutConstraint.activate([
            innerStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            innerStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            innerStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            innerStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14)
        ])

        return container
    }

    private func decodeBasicExample() -> String {
        final class LiveCallModel: ZWBCodable {
            var callId: Int?
            var isBusy: Bool?
            var title: String = ""

            required init() {}
        }

        let json = #"{"callId":"123","isBusy":"yes","title":null}"#
        do {
            let model = try LiveCallModel.zwbDecode(from: json)
            return """
            JSON:
            \(json)

            callId -> \(model.callId.map(String.init) ?? "nil")  Int?
            isBusy -> \(model.isBusy.map(String.init) ?? "nil")  Bool?
            title  -> "\(model.title)"  String
            """
        } catch {
            return "解析失败: \(error)"
        }
    }

    private func decodeIMExample() -> String {
        final class GiftIMModel: ZWBCodable {
            var giftId: Int?
            required init() {}
        }

        let body = """
        {"giftId":"1001","gift":{"name":"rose","combo":{"count":"10"}}}
        """
        let message = ZWBIMDecoder.decodeSafely(GiftIMModel.self, from: body)
        return """
        IM body:
        \(body)

        model.giftId -> \(message.model?.giftId.map(String.init) ?? "nil")
        raw.gift.name -> \(message.rawJSON?["gift"]["name"].stringValue ?? "nil")
        raw.combo.count -> \(message.rawJSON?["gift"]["combo"]["count"].intValue.map(String.init) ?? "nil")
        """
    }

    private func generatorExample() -> String {
        """
        swift run zwb-codable-generate \\
          --name GiftIMModel \\
          --input Example/IMGiftSample.json \\
          --class \\
          --output Example/GiftIMModel.swift

        已有字段保留，缺失字段自动追加。
        """
    }
}
