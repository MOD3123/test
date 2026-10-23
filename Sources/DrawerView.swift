import UIKit

final class DrawerCell: UITableViewCell {
    private let pill = UIView()
    private let iconView = UIImageView()
    private let label = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none

        pill.backgroundColor = Theme.indicator
        pill.isHidden = true
        pill.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(pill)

        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconView)
        contentView.addSubview(label)

        NSLayoutConstraint.activate([
            pill.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            pill.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            pill.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            pill.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),
            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
        applyStyle(selected: false)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        pill.layer.cornerRadius = pill.bounds.height / 2
    }

    func configure(_ item: NavItem) {
        iconView.image = sf(item.icon, size: 18)
        label.text = item.title
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        applyStyle(selected: selected)
    }

    private func applyStyle(selected: Bool) {
        pill.isHidden = !selected
        label.textColor = selected ? Theme.iconActive : Theme.drawerText
        iconView.tintColor = selected ? Theme.accent : Theme.iconIdle
    }
}

final class DrawerView: UIView, UITableViewDataSource, UITableViewDelegate {
    var onSelect: ((Int) -> Void)?
    private var items: [NavItem] = []
    private let table = UITableView(frame: .zero, style: .plain)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.bg
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.35
        layer.shadowRadius = 16
        layer.shadowOffset = CGSize(width: 4, height: 0)

        let header = UIView()
        header.translatesAutoresizingMaskIntoConstraints = false
        let logo = UIImageView(image: UIImage(named: "Logo"))
        logo.contentMode = .scaleAspectFit
        logo.translatesAutoresizingMaskIntoConstraints = false
        let title = UILabel()
        title.text = "WebCenter"
        title.font = .systemFont(ofSize: 22, weight: .bold)
        title.textColor = Theme.text
        title.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(logo)
        header.addSubview(title)
        addSubview(header)

        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.rowHeight = 52
        table.dataSource = self
        table.delegate = self
        table.register(DrawerCell.self, forCellReuseIdentifier: "cell")
        table.translatesAutoresizingMaskIntoConstraints = false
        addSubview(table)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            header.leadingAnchor.constraint(equalTo: leadingAnchor),
            header.trailingAnchor.constraint(equalTo: trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 80),
            logo.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 24),
            logo.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            logo.heightAnchor.constraint(equalToConstant: 44),
            logo.widthAnchor.constraint(equalToConstant: 44),
            title.leadingAnchor.constraint(equalTo: logo.trailingAnchor, constant: 14),
            title.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            table.topAnchor.constraint(equalTo: header.bottomAnchor),
            table.leadingAnchor.constraint(equalTo: leadingAnchor),
            table.trailingAnchor.constraint(equalTo: trailingAnchor),
            table.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setItems(_ newItems: [NavItem]) {
        items = newItems
        table.reloadData()
    }

    func select(index: Int?) {
        if let i = index, i < items.count {
            table.selectRow(at: IndexPath(row: i, section: 0), animated: false, scrollPosition: .none)
        } else if let sel = table.indexPathForSelectedRow {
            table.deselectRow(at: sel, animated: false)
        }
    }

    // MARK: Table
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { items.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! DrawerCell
        cell.configure(items[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        onSelect?(indexPath.row)
    }
}
