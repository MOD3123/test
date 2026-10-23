import UIKit
import AVFoundation

// MARK: - API

struct TescoArticle {
    var name = "Neznámy produkt"
    var price = ""
    var deposit = ""
    var savers = ""
}

final class TescoAPI {
    static let deviceId = "9fc0a464-504b-4681-9721-31817e91ca3d"
    static let clubcard = "634009500000000000"
    static let base = "https://says.tesco-europe.com/api"

    private func postJSON(_ path: String, body: [String: Any], done: @escaping (Data?) -> Void) {
        guard let url = URL(string: TescoAPI.base + path),
              let data = try? JSONSerialization.data(withJSONObject: body) else { done(nil); return }
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        req.httpMethod = "POST"
        req.httpBody = data
        req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        req.setValue("1", forHTTPHeaderField: "X-Client-Version")
        req.setValue("ScanShop/2.9.1 (Android 15; Build/AE3A.240806.043)", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: req) { d, _, _ in done(d) }.resume()
    }

    func start(branchId: String, done: @escaping (String?) -> Void) {
        let payload: [String: Any] = [
            "branchId": branchId,
            "clubCard": TescoAPI.clubcard,
            "payload": [Any](),
            "location": ["lat": 0, "lng": 0],
            "appVersion": "2.9.1",
            "appCode": "2025082503",
            "lang": "UNSET",
        ]
        postJSON("/shopping/start", body: ["deviceId": TescoAPI.deviceId, "data": payload]) { data in
            guard let d = data,
                  let json = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] else { done(nil); return }
            if let t = json["token"] as? String { done(t); return }
            if let inner = json["data"] as? [String: Any], let t = inner["token"] as? String { done(t); return }
            done(nil)
        }
    }

    func article(barcode: String, branchId: String, token: String, done: @escaping (TescoArticle) -> Void) {
        let body: [String: Any] = [
            "deviceId": TescoAPI.deviceId,
            "token": token,
            "data": ["branchId": branchId, "articles": [barcode]],
        ]
        postJSON("/article/", body: body) { data in
            guard let d = data else {
                done(TescoArticle(name: "Chyba siete", price: "", deposit: "", savers: ""))
                return
            }
            done(TescoAPI.parse(d, barcode: barcode))
        }
    }

    // MARK: Parsovanie (tolerantné k rôznym štruktúram odpovede)
    private static func num(_ any: Any?) -> Double? {
        if let n = any as? NSNumber { return n.doubleValue }
        if let s = any as? String { return Double(s) }
        return nil
    }

    private static func findKey(_ key: String, in obj: Any) -> Any? {
        if let d = obj as? [String: Any] {
            if let v = d[key] { return v }
            for (_, v) in d { if let r = findKey(key, in: v) { return r } }
        } else if let a = obj as? [Any] {
            for v in a { if let r = findKey(key, in: v) { return r } }
        }
        return nil
    }

    static func parse(_ data: Data, barcode: String) -> TescoArticle {
        var out = TescoArticle()
        guard let root = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) else { return out }

        var art: [String: Any]?
        if let arr = root as? [Any] {
            art = arr.first as? [String: Any]
        } else if let r = root as? [String: Any] {
            if let a = r["articles"] as? [Any] { art = a.first as? [String: Any] }
            else if let d = r["data"] as? [String: Any], let a = d["articles"] as? [Any] { art = a.first as? [String: Any] }
            else if let a = r[barcode] as? [String: Any] { art = a }
            else { art = r.values.compactMap { $0 as? [String: Any] }.first }
        }
        guard let a = art else { return out }

        if let n = a["name"] as? String { out.name = n }
        if let s = (a["secondName"] as? String)?.trimmingCharacters(in: .whitespaces),
           !s.isEmpty, s.lowercased() != out.name.lowercased() {
            out.name += "\n" + s
        }
        if let t = a["title"] as? String { out.name = t }

        let articlePrice = num(a["articlePrice"])
        if let v = articlePrice, v >= 0 { out.price = formatEuro(v) + " €" }
        if out.price.isEmpty, let p = a["price"] {
            if let po = p as? [String: Any] {
                if let v = num(po["value"]) ?? num(po["amount"]), v >= 0 {
                    out.price = formatEuro(v) + " " + ((po["currency"] as? String) ?? "€")
                }
            } else if let v = num(p) { out.price = formatEuro(v) + " €" }
        }
        if out.price.isEmpty, let cu = a["currentSaleUnitPrice"] as? [String: Any],
           let v = num(cu["price"]) ?? num(cu["value"]) ?? num(cu["amount"]), v >= 0 {
            out.price = formatEuro(v) + " €"
        }

        if let dep = a["depositArticle"] as? [String: Any], let dv = num(dep["articlePrice"]), dv >= 0 {
            let dn = ((dep["name"] as? String) ?? "Záloha").trimmingCharacters(in: .whitespaces)
            out.deposit = "+ " + formatEuro(dv) + " € " + (dn.isEmpty ? "záloha" : dn.lowercased())
        }

        // Savers (akcie / Clubcard)
        let saversAny = a["savers"] ?? findKey("savers", in: root)
        if let list = saversAny as? [Any] {
            var lines: [String] = []
            for item in list {
                guard let s = item as? [String: Any] else { continue }
                let active = (s["active"] as? Bool) ?? ((s["active"] as? String) == "true")
                let ignored = (s["isIgnored"] as? Bool) ?? ((s["isIgnored"] as? String) == "true")
                if !active || ignored { continue }
                let cc = (s["clubCard"] as? Bool) ?? ((s["clubCard"] as? String) == "true")
                let desc = s["description"] as? String
                let rType = Int(num(s["rewardType"]) ?? -1)
                let rVal = num(s["reward"]) ?? -1
                let label = cc ? "🟡 Clubcard" : "🟡 Akcia"
                let ap = articlePrice ?? -1
                var line: String
                if rType == 2 && rVal > 0 {
                    let pct = Int(rVal.rounded())
                    if ap > 0 { line = "\(label) -\(pct)%\nNová cena \(formatEuro(ap * (1 - rVal / 100))) €" }
                    else { line = "\(label) -\(pct)%" }
                } else if rType == 1 && rVal > 0 {
                    if ap > 0 { line = "\(label) -\(formatEuro(rVal)) €\nNová cena \(formatEuro(ap - rVal)) €" }
                    else { line = "\(label) -\(formatEuro(rVal)) €" }
                } else if rType == 3 && rVal > 0 {
                    line = "\(label) \(formatEuro(rVal)) €"
                } else if let d = desc, !d.isEmpty {
                    line = label + " " + d
                } else {
                    line = "\(label) typ=\(rType) r=\(rVal)"
                }
                lines.append(line)
            }
            out.savers = lines.joined(separator: "\n")
        }
        return out
    }
}

// MARK: - Výber obchodu

private let tescoBranches: [(id: String, name: String, city: String)] = [
    ("22001", "OD Bratislava Prior", "Bratislava"),
    ("24156", "EX Bratislava Eurovea", "Bratislava"),
    ("24178", "SM Bratislava Hálova", "Bratislava"),
    ("21019", "HM Bratislava Lamač", "Bratislava"),
    ("24025", "SM Bratislava Blagoevova", "Bratislava"),
    ("21057", "HM Bratislava OC Dubrawa", "Bratislava"),
    ("21101", "HM Podunajské Biskupice", "Bratislava"),
    ("21014", "HM Bratislava Zlaté Piesky", "Bratislava"),
    ("21004", "HM Bratislava Petržalka", "Bratislava"),
    ("24155", "SM Bratislava OC Vajnoria", "Bratislava"),
    ("21052", "HM Devínska Nová Ves", "Bratislava"),
    ("21041", "HM Dunajská Streda", "Dunajská Streda"),
    ("21056", "HM Komárno Abacus", "Komárno"),
    ("21040", "HM Veľký Meder", "Veľký Meder"),
]

final class TescoStorePickerViewController: UITableViewController {
    private var sections: [(city: String, items: [(id: String, name: String)])] = []

    init() { super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Tesco — výber obchodu"
        view.backgroundColor = Theme.bg
        tableView.backgroundColor = Theme.bg
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: sf("xmark", size: 17), style: .plain, target: self, action: #selector(close))
        navigationItem.leftBarButtonItem?.tintColor = Theme.text

        let ap = UINavigationBarAppearance()
        ap.configureWithOpaqueBackground()
        ap.backgroundColor = Theme.surface
        ap.titleTextAttributes = [.foregroundColor: Theme.text]
        navigationController?.navigationBar.standardAppearance = ap
        navigationController?.navigationBar.scrollEdgeAppearance = ap

        for b in tescoBranches {
            if let i = sections.firstIndex(where: { $0.city == b.city }) {
                sections[i].items.append((b.id, b.name))
            } else {
                sections.append((b.city, [(b.id, b.name)]))
            }
        }
    }

    @objc private func close() { dismiss(animated: true) }

    override func numberOfSections(in tableView: UITableView) -> Int { sections.count }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { sections[section].items.count }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].city.uppercased()
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = sections[indexPath.section].items[indexPath.row].name
        cell.textLabel?.textColor = Theme.text
        cell.textLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        cell.backgroundColor = Theme.surface
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let b = sections[indexPath.section].items[indexPath.row]
        navigationController?.pushViewController(
            TescoScannerViewController(branchId: b.id, branchName: b.name), animated: true)
    }
}

// MARK: - Skener cien

final class TescoScannerViewController: CameraScannerViewController {
    private let branchId: String
    private let branchName: String
    private let api = TescoAPI()
    private var token: String?

    private var resultCard: UIView!
    private let nameLabel = UILabel()
    private let priceLabel = UILabel()
    private let depositLabel = UILabel()
    private let saversLabel = UILabel()

    init(branchId: String, branchName: String) {
        self.branchId = branchId
        self.branchName = branchName
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var codeTypes: [AVMetadataObject.ObjectType] {
        return [.ean13, .ean8, .upce, .code128, .code39]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        _ = makeTopBar(title: branchName, showBack: true)
        buildCard()
        statusLabel.text = "Získavam token pre \(branchName)…"
        api.start(branchId: branchId) { [weak self] t in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let t = t {
                    self.token = t
                    self.statusLabel.text = "Naskenujte čiarový kód produktu"
                    self.startCamera()
                } else {
                    self.statusLabel.text = "Chyba: nepodarilo sa získať token. Skúste znova."
                }
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent { navigationController?.setNavigationBarHidden(false, animated: false) }
    }

    private func buildCard() {
        let c = makeResultCard()
        nameLabel.font = .systemFont(ofSize: 17, weight: .medium)
        nameLabel.textColor = Theme.text
        nameLabel.numberOfLines = 3
        priceLabel.font = .systemFont(ofSize: 32, weight: .bold)
        priceLabel.textColor = Theme.accent
        depositLabel.font = .systemFont(ofSize: 13, weight: .medium)
        depositLabel.textColor = Theme.textMuted
        saversLabel.font = .systemFont(ofSize: 15, weight: .medium)
        saversLabel.textColor = Theme.savers
        saversLabel.numberOfLines = 0
        let rescan = makeButton("Skenovať znova", filled: true)
        rescan.addAction(UIAction { [weak self] _ in self?.rescan() }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [nameLabel, priceLabel, depositLabel, saversLabel, rescan])
        stack.axis = .vertical
        stack.spacing = 8
        stack.setCustomSpacing(16, after: saversLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        c.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: c.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: c.bottomAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -20),
        ])
        resultCard = c
    }

    override func didDetect(code: String, type: AVMetadataObject.ObjectType) {
        statusLabel.text = "Načítavam: \(code)…"
        guard let t = token else {
            statusLabel.text = "Chyba: žiadny token. Vráťte sa a vyberte obchod."
            return
        }
        api.article(barcode: code, branchId: branchId, token: t) { [weak self] art in
            DispatchQueue.main.async { self?.show(art) }
        }
    }

    private func show(_ a: TescoArticle) {
        nameLabel.text = a.name
        priceLabel.text = a.price.isEmpty ? "Cena nedostupná" : a.price
        depositLabel.text = a.deposit
        depositLabel.isHidden = a.deposit.isEmpty
        saversLabel.text = a.savers
        saversLabel.isHidden = a.savers.isEmpty
        statusLabel.text = "Naskenovaný produkt"
        showCard(resultCard)
    }

    private func rescan() {
        hideCard(resultCard)
        statusLabel.text = "Naskenujte ďalší produkt"
        resumeScanning()
    }

    override func closeTapped() {
        navigationController?.popViewController(animated: true)
    }
}
