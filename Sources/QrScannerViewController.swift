import UIKit
import AVFoundation
import SafariServices

final class QrScannerViewController: CameraScannerViewController {

    private let resultLabel = UILabel()
    private let typeLabel = UILabel()
    private var openButton: UIButton!
    private var shareButton: UIButton!
    private var lastRaw: String?

    override var codeTypes: [AVMetadataObject.ObjectType] {
        return [.qr, .ean13, .ean8, .upce, .code128, .code39, .code93,
                .pdf417, .aztec, .dataMatrix, .itf14, .interleaved2of5]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        statusLabel.text = "Naskenujte QR alebo čiarový kód"
        _ = makeTopBar(title: "Skener", showBack: false)
        buildCard()
        startCamera()
    }

    private func buildCard() {
        let c = makeResultCard()
        let wrap = c

        typeLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        typeLabel.textColor = Theme.textMuted
        typeLabel.text = "VÝSLEDOK SKENOVANIA"

        resultLabel.font = .systemFont(ofSize: 17, weight: .medium)
        resultLabel.textColor = Theme.text
        resultLabel.numberOfLines = 6
        resultLabel.lineBreakMode = .byTruncatingTail

        let copy = makeButton("Kopírovať", symbol: "doc.on.doc")
        openButton = makeButton("Otvoriť", symbol: "safari")
        let google = makeButton("Google", symbol: "magnifyingglass")
        shareButton = makeButton("Zdieľať", symbol: "square.and.arrow.up")
        let rescan = makeButton("Skenovať znova", filled: true)

        copy.addAction(UIAction { [weak self] _ in self?.copyRaw() }, for: .touchUpInside)
        openButton.addAction(UIAction { [weak self] _ in self?.openRaw() }, for: .touchUpInside)
        google.addAction(UIAction { [weak self] _ in self?.searchGoogle() }, for: .touchUpInside)
        shareButton.addAction(UIAction { [weak self] _ in self?.shareRaw() }, for: .touchUpInside)
        rescan.addAction(UIAction { [weak self] _ in self?.rescan() }, for: .touchUpInside)

        let row1 = UIStackView(arrangedSubviews: [copy, openButton, google, shareButton])
        row1.axis = .horizontal
        row1.spacing = 8
        row1.distribution = .fillProportionally

        let stack = UIStackView(arrangedSubviews: [typeLabel, resultLabel, row1, rescan])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        wrap.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: wrap.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: wrap.bottomAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: wrap.trailingAnchor, constant: -20),
        ])
        resultCard = wrap
    }

    private var resultCard: UIView!

    override func didDetect(code: String, type: AVMetadataObject.ObjectType) {
        lastRaw = code
        resultLabel.text = code
        typeLabel.text = "VÝSLEDOK SKENOVANIA · " + type.rawValue
            .replacingOccurrences(of: "org.iso.", with: "")
            .replacingOccurrences(of: "org.gs1.", with: "")
            .replacingOccurrences(of: "com.apple.", with: "")
            .uppercased()
        openButton.isHidden = !isUrl(code)
        statusLabel.text = "Naskenované"
        showCard(resultCard)
    }

    private func isUrl(_ s: String) -> Bool {
        let l = s.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return l.hasPrefix("http://") || l.hasPrefix("https://")
    }

    private func copyRaw() {
        guard let r = lastRaw else { return }
        UIPasteboard.general.string = r
        statusLabel.text = "Skopírované do schránky"
    }

    private func openRaw() {
        guard let r = lastRaw?.trimmingCharacters(in: .whitespacesAndNewlines),
              isUrl(r), let u = URL(string: r) else { return }
        UIApplication.shared.open(u)
    }

    private func searchGoogle() {
        guard let r = lastRaw,
              let q = r.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let u = URL(string: "https://www.google.com/search?q=" + q) else { return }
        UIApplication.shared.open(u)
    }

    private func shareRaw() {
        guard let r = lastRaw else { return }
        let vc = UIActivityViewController(activityItems: [r], applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = shareButton
        vc.popoverPresentationController?.sourceRect = shareButton.bounds
        present(vc, animated: true)
    }

    private func rescan() {
        hideCard(resultCard)
        statusLabel.text = "Naskenujte QR alebo čiarový kód"
        resumeScanning()
    }
}
