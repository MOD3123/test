import Foundation

struct NavItem {
    let title: String
    let icon: [String]   // SF Symbol kandidáti
    let url: String
}

enum AssetPaths {
    /// Pôvodné Android odkazy v HTML (`file:///android_asset/...`) sa mapujú na bundle.
    static let prefix = "file:///android_asset/"

    static var dir: URL {
        return Bundle.main.resourceURL!.appendingPathComponent("assets", isDirectory: true)
    }

    static func isAsset(_ s: String) -> Bool { return s.hasPrefix(prefix) }

    static func fileURL(for s: String) -> URL? {
        guard isAsset(s) else { return nil }
        let rest = String(s.dropFirst(prefix.count))
        return URL(string: dir.absoluteString + rest)
    }

    /// file:///…/assets/x.html → file:///android_asset/x.html
    static func assetString(for url: URL) -> String? {
        guard url.isFileURL else { return nil }
        let base = dir.standardizedFileURL.path
        let p = url.standardizedFileURL.path
        guard p.hasPrefix(base + "/") else { return nil }
        return prefix + String(p.dropFirst(base.count + 1))
    }
}

enum NavCatalog {
    private static let b = "https://mod3123.github.io/webcenter/"

    static let onlineBottom: [NavItem] = [
        NavItem(title: "Domov",   icon: ["house"], url: b + "online_index"),
        NavItem(title: "Doprava", icon: ["bus"], url: b + "MHD/doprava"),
        NavItem(title: "Správy",  icon: ["newspaper"], url: b + "Spravy/spravysk"),
        NavItem(title: "Počasie", icon: ["cloud.sun", "cloud"], url: b + "Pocasie"),
        NavItem(title: "Weby",    icon: ["globe"], url: b + "Kniznica/weby"),
    ]

    static let onlineDrawer: [NavItem] = [
        NavItem(title: "Domov", icon: ["house"], url: b + "online_index"),
        NavItem(title: "Google", icon: ["magnifyingglass"], url: "https://www.google.com"),
        NavItem(title: "Knižnica webov", icon: ["globe"], url: b + "Kniznica/weby"),
        NavItem(title: "Nástroje", icon: ["wrench.and.screwdriver", "hammer"], url: "https://edgeservices.bing.com/edgesvc/toolbox?darkschemeovr=1"),
        NavItem(title: "Správy", icon: ["newspaper"], url: b + "Spravy/spravysk"),
        NavItem(title: "Spravodajské weby", icon: ["newspaper"], url: b + "Spravy/weby"),
        NavItem(title: "Počasie", icon: ["cloud.sun", "cloud"], url: b + "Pocasie"),
        NavItem(title: "Letáky", icon: ["tag", "cart"], url: "https://mod3123.github.io/letaky/"),
        NavItem(title: "Doprava", icon: ["bus"], url: b + "MHD/doprava"),
        NavItem(title: "Zastávky", icon: ["mappin.and.ellipse", "mappin"], url: b + "MHD/zastavky2"),
        NavItem(title: "Rádio", icon: ["dot.radiowaves.left.and.right", "antenna.radiowaves.left.and.right"], url: b + "Radio"),
        NavItem(title: "Zelená vlna STVR", icon: ["dot.radiowaves.left.and.right"], url: b + "Radio/zelenavlna"),
        NavItem(title: "Slovník", icon: ["character.book.closed", "book"], url: "https://mod3123.github.io/slovnik/"),
        NavItem(title: "SHMÚ.sk", icon: ["cloud.sun", "cloud"], url: "https://www.shmu.sk"),
        NavItem(title: "iMeteo.sk", icon: ["cloud.sun", "cloud"], url: "https://www.imeteo.sk"),
        NavItem(title: "Vyhľadávanie čísiel", icon: ["phone"], url: b + "VyhladavanieCisiel"),
        NavItem(title: "PSČ", icon: ["envelope"], url: b + "PSC/PSC"),
        NavItem(title: "Zoznam pôšt", icon: ["envelope"], url: b + "PSC/posty"),
        NavItem(title: "Konvertor jednotiek", icon: ["plus.forwardslash.minus", "number"], url: b + "Math/converter"),
        NavItem(title: "Periodická tabuľka prvkov", icon: ["atom", "circle.grid.cross"], url: b + "ptp"),
        NavItem(title: "Generátor rovníc", icon: ["plus.forwardslash.minus", "number"], url: b + "Math/rovnice"),
        NavItem(title: "Kalkulačka", icon: ["plus.forwardslash.minus", "number"], url: b + "Math/calc"),
        NavItem(title: "Kalendár", icon: ["calendar"], url: b + "Kalendar/meninykalendar"),
        NavItem(title: "Kvalita ovzdušia", icon: ["wind"], url: "https://dnesdycham.populair.sk/"),
        NavItem(title: "Aspik", icon: ["fork.knife"], url: "https://sites.google.com/view/aspiksk"),
        NavItem(title: "QR generátor", icon: ["qrcode"], url: b + "QR/qrgenerator"),
        NavItem(title: "Rastlinka.sk", icon: ["leaf"], url: "https://sites.google.com/view/rastlinkask/domov"),
        NavItem(title: "Recepty", icon: ["fork.knife"], url: "https://sites.google.com/view/recpty"),
        NavItem(title: "Vrakunské noviny", icon: ["newspaper"], url: "https://www.vrakuna.sk/4806/vrakunske-noviny"),
        NavItem(title: "Solitaire", icon: ["suit.spade", "rectangle.on.rectangle"], url: AssetPaths.prefix + "solitaire.html"),
        NavItem(title: "Zber odpadu Trávnik", icon: ["trash"], url: b + "Obce/ZBERTravnik"),
    ]

    static let offlineBottom: [NavItem] = [
        NavItem(title: "Domov", icon: ["house"], url: AssetPaths.prefix + "index_offline.html"),
        NavItem(title: "Konvertor", icon: ["plus.forwardslash.minus", "number"], url: AssetPaths.prefix + "converter.html"),
        NavItem(title: "Kalkulačka", icon: ["plus.forwardslash.minus", "number"], url: AssetPaths.prefix + "calc.html"),
        NavItem(title: "Kalendár", icon: ["calendar"], url: AssetPaths.prefix + "kalendar.html"),
        NavItem(title: "Rovnice", icon: ["plus.forwardslash.minus", "number"], url: AssetPaths.prefix + "rovnice.html"),
    ]

    static let offlineDrawer: [NavItem] = [
        NavItem(title: "Domov", icon: ["house"], url: AssetPaths.prefix + "index_offline.html"),
        NavItem(title: "Vyhľadávanie čísiel", icon: ["phone"], url: AssetPaths.prefix + "cisla.html"),
        NavItem(title: "PSČ", icon: ["envelope"], url: AssetPaths.prefix + "psc.html"),
        NavItem(title: "Konvertor jednotiek", icon: ["plus.forwardslash.minus", "number"], url: AssetPaths.prefix + "converter.html"),
        NavItem(title: "Periodická tabuľka prvkov", icon: ["atom", "circle.grid.cross"], url: AssetPaths.prefix + "ptp.html"),
        NavItem(title: "Generátor rovníc", icon: ["plus.forwardslash.minus", "number"], url: AssetPaths.prefix + "rovnice.html"),
        NavItem(title: "Kalkulačka", icon: ["plus.forwardslash.minus", "number"], url: AssetPaths.prefix + "calc.html"),
        NavItem(title: "Kalendár", icon: ["calendar"], url: AssetPaths.prefix + "kalendar.html"),
        NavItem(title: "QR generátor", icon: ["qrcode"], url: AssetPaths.prefix + "qrgenerator.html"),
        NavItem(title: "Solitaire", icon: ["suit.spade", "rectangle.on.rectangle"], url: AssetPaths.prefix + "solitaire.html"),
        NavItem(title: "Zber odpadu Trávnik", icon: ["trash"], url: AssetPaths.prefix + "ZBERTravnik.html"),
    ]

    // MARK: Zhoda URL → položka menu (rovnaká logika ako v Android verzii)

    static func normalize(_ url: String) -> String {
        var s = url.lowercased().trimmingCharacters(in: .whitespaces)
        if s.hasSuffix("/") { s.removeLast() }
        if let q = s.firstIndex(of: "?") { s = String(s[..<q]) }
        if let h = s.firstIndex(of: "#") { s = String(s[..<h]) }
        return s
    }

    static func match(_ url: String, in items: [NavItem]) -> Int? {
        let lower = url.lowercased().trimmingCharacters(in: .whitespaces)
        if let i = items.firstIndex(where: { $0.url.lowercased() == lower }) { return i }
        let n = normalize(lower)
        if let i = items.firstIndex(where: { normalize($0.url) == n }) { return i }
        var best: Int?
        var bestLen = 0
        for (i, it) in items.enumerated() {
            let m = normalize(it.url)
            if m.isEmpty { continue }
            if n.hasPrefix(m) && m.count > bestLen { best = i; bestLen = m.count }
        }
        return best
    }
}
