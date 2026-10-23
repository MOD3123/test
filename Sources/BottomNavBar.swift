import UIKit

/// Vlastná spodná navigácia (UITabBar na iPade skracuje názvy).
final class BottomNavBar: UIView {
    var onSelect: ((Int) -> Void)?
    private var buttons: [UIButton] = []
    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.bg
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            stack.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -6),
            stack.heightAnchor.constraint(equalToConstant: 56),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setItems(_ items: [NavItem]) {
        buttons.forEach { $0.removeFromSuperview() }
        buttons = []
        for (i, it) in items.enumerated() {
            var cfg = UIButton.Configuration.plain()
            cfg.image = sf(it.icon, size: 20)
            cfg.title = it.title
            cfg.imagePlacement = .top
            cfg.imagePadding = 3
            cfg.titleLineBreakMode = .byClipping
            cfg.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 2, bottom: 4, trailing: 2)
            cfg.background.cornerRadius = 16
            cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { c in
                var c = c
                c.font = UIFont.systemFont(ofSize: 12, weight: .medium)
                return c
            }
            let b = UIButton(configuration: cfg, primaryAction: nil)
            b.configurationUpdateHandler = { btn in
                var c = btn.configuration
                c?.baseForegroundColor = btn.isSelected ? Theme.iconActive : Theme.iconIdle
                c?.background.backgroundColor = btn.isSelected ? Theme.indicator : .clear
                btn.configuration = c
            }
            b.addAction(UIAction { [weak self] _ in
                self?.select(index: i)
                self?.onSelect?(i)
            }, for: .touchUpInside)
            stack.addArrangedSubview(b)
            buttons.append(b)
        }
    }

    func select(index: Int?) {
        for (i, b) in buttons.enumerated() { b.isSelected = (i == index) }
    }
}
