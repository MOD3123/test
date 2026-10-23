import UIKit

/// Celoobrazovkový overlay "Ste offline" (port z MainActivity.showOfflineOverlay).
final class OfflineOverlayView: UIView {
    var onStartOffline: (() -> Void)?
    var onRetry: (() -> Void)?
    var onWifi: (() -> Void)?
    var onClose: (() -> Void)?

    private let card = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.scrim
        alpha = 0

        card.backgroundColor = Theme.bg
        card.layer.cornerRadius = 28
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)

        let icon = UIImageView(image: sf(["wifi.exclamationmark", "wifi.slash"], size: 56, weight: .light))
        icon.tintColor = Theme.text
        icon.contentMode = .scaleAspectFit

        let title = UILabel()
        title.text = "Ste offline"
        title.font = .systemFont(ofSize: 26, weight: .bold)
        title.textColor = Theme.text
        title.textAlignment = .center

        let body = UILabel()
        body.text = "Aplikácia nemá prístup na internet."
        body.font = .systemFont(ofSize: 15)
        body.textColor = Theme.textMuted
        body.textAlignment = .center
        body.numberOfLines = 0

        let primary = makeButton("Spustiť offline režim", filled: true, color: Theme.offlineRed)
        let retry = makeButton("Obnoviť", color: Theme.accent)
        let wifi = makeButton("Nastavenia WiFi", color: Theme.textMuted)
        let close = makeButton("Zavrieť aplikáciu", color: Theme.danger)

        primary.addAction(UIAction { [weak self] _ in self?.onStartOffline?() }, for: .touchUpInside)
        retry.addAction(UIAction { [weak self] _ in self?.onRetry?() }, for: .touchUpInside)
        wifi.addAction(UIAction { [weak self] _ in self?.onWifi?() }, for: .touchUpInside)
        close.addAction(UIAction { [weak self] _ in self?.onClose?() }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [icon, title, body, primary, retry, wifi, close])
        stack.axis = .vertical
        stack.spacing = 12
        stack.setCustomSpacing(20, after: icon)
        stack.setCustomSpacing(28, after: body)
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        let wMax = card.widthAnchor.constraint(lessThanOrEqualToConstant: 440)
        let wFill = card.widthAnchor.constraint(equalTo: widthAnchor, constant: -64)
        wFill.priority = .defaultHigh
        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: centerXAnchor),
            card.centerYAnchor.constraint(equalTo: centerYAnchor),
            wMax, wFill,
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 36),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -32),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -32),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func present() {
        card.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        card.alpha = 0
        UIView.animate(withDuration: 0.26) { self.alpha = 1 }
        UIView.animate(withDuration: 0.38, delay: 0.06, usingSpringWithDamping: 0.8,
                       initialSpringVelocity: 0, options: []) {
            self.card.transform = .identity
            self.card.alpha = 1
        }
    }

    func dismiss() {
        UIView.animate(withDuration: 0.2, animations: {
            self.alpha = 0
            self.card.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }, completion: { _ in self.removeFromSuperview() })
    }
}
