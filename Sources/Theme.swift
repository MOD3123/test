import UIKit

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }

    static func dynamic(dark: UInt32, light: UInt32,
                        darkAlpha: CGFloat = 1, lightAlpha: CGFloat = 1) -> UIColor {
        return UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(hex: dark, alpha: darkAlpha)
                : UIColor(hex: light, alpha: lightAlpha)
        }
    }
}

/// Farby prevzaté z Android verzie (tmavý / svetlý režim podľa systému).
enum Theme {
    static let bg          = UIColor.dynamic(dark: 0x0F172A, light: 0xF1F5F9)
    static let surface     = UIColor.dynamic(dark: 0x1E293B, light: 0xFFFFFF)
    static let text        = UIColor.dynamic(dark: 0xF1F5F9, light: 0x0F172A)
    static let textMuted   = UIColor.dynamic(dark: 0x94A3B8, light: 0x64748B)
    static let drawerText  = UIColor.dynamic(dark: 0xE2E8F0, light: 0x334155)
    static let iconActive  = UIColor.dynamic(dark: 0xFFFFFF, light: 0x1E3A5F)
    static let iconIdle    = UIColor.dynamic(dark: 0x94A3B8, light: 0x475569)
    static let accent      = UIColor.dynamic(dark: 0x60A5FA, light: 0x1D4ED8)
    static let indicator   = UIColor.dynamic(dark: 0x60A5FA, light: 0x1D4ED8, darkAlpha: 0.19, lightAlpha: 0.25)
    static let toolbarBtn  = UIColor.dynamic(dark: 0xCAC3CB, light: 0x1E293B)
    static let danger      = UIColor.dynamic(dark: 0xFF6B6B, light: 0xB91C1C)
    static let offlineRed  = UIColor(hex: 0xE05555)
    static let savers      = UIColor.dynamic(dark: 0xFDE047, light: 0xD97706)
    static let scrim       = UIColor.dynamic(dark: 0x060B18, light: 0xE8EEF7)
}

/// SF Symbol s fallbackmi (ak symbol na iOS 15 neexistuje, skúsi sa ďalší).
func sf(_ names: [String], size: CGFloat = 20, weight: UIImage.SymbolWeight = .regular) -> UIImage? {
    let cfg = UIImage.SymbolConfiguration(pointSize: size, weight: weight)
    for n in names {
        if let img = UIImage(systemName: n, withConfiguration: cfg) { return img }
    }
    return UIImage(systemName: "square.grid.2x2", withConfiguration: cfg)
}

func sf(_ name: String, size: CGFloat = 20, weight: UIImage.SymbolWeight = .regular) -> UIImage? {
    return sf([name], size: size, weight: weight)
}

/// Zaoblené tlačidlo (iOS 15 UIButton.Configuration).
func makeButton(_ title: String, filled: Bool = false, color: UIColor = Theme.accent,
                symbol: String? = nil) -> UIButton {
    var cfg = filled ? UIButton.Configuration.filled() : UIButton.Configuration.tinted()
    cfg.title = title
    cfg.baseForegroundColor = filled ? .white : color
    cfg.baseBackgroundColor = color
    cfg.cornerStyle = .capsule
    cfg.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18)
    if let s = symbol {
        cfg.image = sf(s, size: 15)
        cfg.imagePadding = 8
    }
    return UIButton(configuration: cfg, primaryAction: nil)
}

func formatEuro(_ v: Double) -> String {
    return String(format: "%.2f", v).replacingOccurrences(of: ".", with: ",")
}
