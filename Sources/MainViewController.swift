import UIKit
import WebKit
import Network
import SafariServices

final class MainViewController: UIViewController {

    // MARK: - UI
    private let topBar = UIView()
    private let barContent = UIView()
    private let menuButton = MainViewController.barButton("line.3.horizontal", "Menu")
    private let qrButton = MainViewController.barButton("qrcode.viewfinder", "Skenovať QR / čiarový kód")
    private let tescoButton = MainViewController.barButton("cart", "Tesco skener cien")
    private let backButton = MainViewController.barButton("chevron.left", "Späť")
    private let forwardButton = MainViewController.barButton("chevron.right", "Dopredu")
    private let reloadButton = MainViewController.barButton("arrow.clockwise", "Obnoviť stránku")
    private let logoView = UIImageView(image: UIImage(named: "Logo"))
    private let progress = UIProgressView(progressViewStyle: .bar)
    private let tabBar = UITabBar()
    private let dimView = UIView()
    private let drawer = DrawerView()
    private let solitaireClose = MainViewController.barButton("xmark", "Zavrieť")
    private var webView: WKWebView!

    private var drawerLeading: NSLayoutConstraint!
    private var webTopToBar: NSLayoutConstraint!
    private var webTopToView: NSLayoutConstraint!
    private var webBottomToTab: NSLayoutConstraint!
    private var webBottomToView: NSLayoutConstraint!
    private let drawerWidth: CGFloat = 320

    // MARK: - Stav
    private var bottomItems = NavCatalog.onlineBottom
    private var drawerItems = NavCatalog.onlineDrawer
    private var offlineMode = false
    private var dialogShowing = false
    private var solitaireMode = false
    private var lastRealUrl: String?
    private var programmaticURL: URL?
    private var overlay: OfflineOverlayView?
    private var drawerOpen = false

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "webcenter.netmonitor")
    private var observers: [NSKeyValueObservation] = []

    private static let tapHighlightJS =
        "var s=document.createElement('style');s.innerHTML='*{-webkit-tap-highlight-color:transparent!important;}';document.head.appendChild(s);"

    private static func barButton(_ symbol: String, _ label: String) -> UIButton {
        let b = UIButton(type: .system)
        b.setImage(sf(symbol, size: 20), for: .normal)
        b.tintColor = Theme.toolbarBtn
        b.accessibilityLabel = label
        b.translatesAutoresizingMaskIntoConstraints = false
        b.widthAnchor.constraint(equalToConstant: 44).isActive = true
        b.heightAnchor.constraint(equalToConstant: 44).isActive = true
        return b
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.bg
        buildWebView()
        buildLayout()
        buildDrawer()
        applyNavSets()
        wireActions()
        startObservers()
        startMonitor()

        if let first = bottomItems.first {
            tabBar.selectedItem = tabBar.items?.first
            drawer.select(index: 0)
            go(first.url)
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return traitCollection.userInterfaceStyle == .dark ? .lightContent : .darkContent
    }
    override var prefersStatusBarHidden: Bool { return solitaireMode }
    override var prefersHomeIndicatorAutoHidden: Bool { return solitaireMode }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        if previous?.userInterfaceStyle != traitCollection.userInterfaceStyle {
            applyColorScheme()
        }
    }

    deinit { monitor.cancel() }

    // MARK: - Build
    private func buildWebView() {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        cfg.preferences.javaScriptCanOpenWindowsAutomatically = true
        cfg.userContentController.addUserScript(
            WKUserScript(source: MainViewController.tapHighlightJS,
                         injectionTime: .atDocumentEnd, forMainFrameOnly: false))
        webView = WKWebView(frame: .zero, configuration: cfg)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = Theme.bg
        webView.scrollView.backgroundColor = Theme.bg
        webView.underPageBackgroundColor = Theme.bg
        webView.translatesAutoresizingMaskIntoConstraints = false
    }

    private func buildLayout() {
        // Horný panel
        topBar.backgroundColor = Theme.bg
        topBar.layer.cornerRadius = 28
        topBar.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        topBar.translatesAutoresizingMaskIntoConstraints = false
        barContent.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(barContent)

        logoView.contentMode = .scaleAspectFit
        logoView.translatesAutoresizingMaskIntoConstraints = false

        let left = UIStackView(arrangedSubviews: [menuButton, qrButton, tescoButton])
        let right = UIStackView(arrangedSubviews: [backButton, forwardButton, reloadButton])
        for s in [left, right] {
            s.axis = .horizontal
            s.spacing = 4
            s.translatesAutoresizingMaskIntoConstraints = false
            barContent.addSubview(s)
        }
        barContent.addSubview(logoView)

        progress.progressTintColor = Theme.accent
        progress.trackTintColor = .clear
        progress.isHidden = true
        progress.translatesAutoresizingMaskIntoConstraints = false

        // Spodná lišta
        tabBar.delegate = self
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        styleTabBar()

        // Solitaire tlačidlo
        solitaireClose.tintColor = .white
        solitaireClose.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        solitaireClose.layer.cornerRadius = 22
        solitaireClose.isHidden = true

        // Dim
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        dimView.alpha = 0
        dimView.isHidden = true
        dimView.translatesAutoresizingMaskIntoConstraints = false
        dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(closeDrawer)))

        drawer.translatesAutoresizingMaskIntoConstraints = false
        solitaireClose.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(webView)
        view.addSubview(progress)
        view.addSubview(topBar)
        view.addSubview(tabBar)
        view.addSubview(solitaireClose)
        view.addSubview(dimView)
        view.addSubview(drawer)

        let safe = view.safeAreaLayoutGuide
        drawerLeading = drawer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -drawerWidth - 20)
        webTopToBar = webView.topAnchor.constraint(equalTo: topBar.bottomAnchor)
        webTopToView = webView.topAnchor.constraint(equalTo: view.topAnchor)
        webBottomToTab = webView.bottomAnchor.constraint(equalTo: tabBar.topAnchor)
        webBottomToView = webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        webTopToView.isActive = false
        webBottomToView.isActive = false

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.bottomAnchor.constraint(equalTo: safe.topAnchor, constant: 56),

            barContent.topAnchor.constraint(equalTo: safe.topAnchor),
            barContent.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            barContent.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
            barContent.heightAnchor.constraint(equalToConstant: 56),

            left.leadingAnchor.constraint(equalTo: barContent.leadingAnchor, constant: 12),
            left.centerYAnchor.constraint(equalTo: barContent.centerYAnchor),
            right.trailingAnchor.constraint(equalTo: barContent.trailingAnchor, constant: -12),
            right.centerYAnchor.constraint(equalTo: barContent.centerYAnchor),
            logoView.centerXAnchor.constraint(equalTo: barContent.centerXAnchor),
            logoView.centerYAnchor.constraint(equalTo: barContent.centerYAnchor),
            logoView.heightAnchor.constraint(equalToConstant: 32),
            logoView.widthAnchor.constraint(equalToConstant: 32),

            progress.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            progress.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progress.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            tabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webTopToBar, webBottomToTab,

            solitaireClose.topAnchor.constraint(equalTo: safe.topAnchor, constant: 16),
            solitaireClose.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),

            dimView.topAnchor.constraint(equalTo: view.topAnchor),
            dimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            dimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            drawer.topAnchor.constraint(equalTo: view.topAnchor),
            drawer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            drawer.widthAnchor.constraint(equalToConstant: drawerWidth),
            drawerLeading,
        ])
    }

    private func styleTabBar() {
        let ap = UITabBarAppearance()
        ap.configureWithOpaqueBackground()
        ap.backgroundColor = Theme.bg
        ap.shadowColor = .clear
        for layout in [ap.stackedLayoutAppearance, ap.inlineLayoutAppearance, ap.compactInlineLayoutAppearance] {
            layout.normal.iconColor = Theme.iconIdle
            layout.normal.titleTextAttributes = [.foregroundColor: Theme.iconIdle]
            layout.selected.iconColor = Theme.iconActive
            layout.selected.titleTextAttributes = [.foregroundColor: Theme.iconActive]
        }
        tabBar.standardAppearance = ap
        tabBar.scrollEdgeAppearance = ap
    }

    private func buildDrawer() {
        drawer.onSelect = { [weak self] index in
            guard let self = self, index < self.drawerItems.count else { return }
            self.closeDrawer()
            self.go(self.drawerItems[index].url)
        }
    }

    private func wireActions() {
        menuButton.addAction(UIAction { [weak self] _ in self?.toggleDrawer() }, for: .touchUpInside)
        backButton.addAction(UIAction { [weak self] _ in self?.webView.goBack() }, for: .touchUpInside)
        forwardButton.addAction(UIAction { [weak self] _ in self?.webView.goForward() }, for: .touchUpInside)
        reloadButton.addAction(UIAction { [weak self] _ in self?.reload() }, for: .touchUpInside)
        qrButton.addAction(UIAction { [weak self] _ in
            let vc = QrScannerViewController()
            vc.modalPresentationStyle = .fullScreen
            self?.present(vc, animated: true)
        }, for: .touchUpInside)
        tescoButton.addAction(UIAction { [weak self] _ in
            let nav = UINavigationController(rootViewController: TescoStorePickerViewController())
            nav.modalPresentationStyle = .fullScreen
            self?.present(nav, animated: true)
        }, for: .touchUpInside)
        solitaireClose.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            if self.webView.canGoBack { self.webView.goBack() }
            else if let first = self.bottomItems.first { self.go(first.url) }
        }, for: .touchUpInside)

        NotificationCenter.default.addObserver(self, selector: #selector(appBecameActive),
                                               name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    private func startObservers() {
        observers.append(webView.observe(\.estimatedProgress, options: [.new]) { [weak self] wv, _ in
            guard let self = self else { return }
            self.progress.setProgress(Float(wv.estimatedProgress), animated: true)
            self.progress.isHidden = !wv.isLoading || self.solitaireMode
        })
        observers.append(webView.observe(\.isLoading, options: [.new]) { [weak self] wv, _ in
            self?.progress.isHidden = !wv.isLoading || (self?.solitaireMode ?? false)
        })
        observers.append(webView.observe(\.canGoBack, options: [.new]) { [weak self] _, _ in self?.updateNavButtons() })
        observers.append(webView.observe(\.canGoForward, options: [.new]) { [weak self] _, _ in self?.updateNavButtons() })
        observers.append(webView.observe(\.url, options: [.new]) { [weak self] wv, _ in
            guard let self = self, let u = wv.url else { return }
            self.urlChanged(u)
        })
    }

    private func updateNavButtons() {
        backButton.isEnabled = webView.canGoBack
        forwardButton.isEnabled = webView.canGoForward
        backButton.alpha = webView.canGoBack ? 1 : 0.4
        forwardButton.alpha = webView.canGoForward ? 1 : 0.4
    }

    // MARK: - Menu / navigácia
    private func applyNavSets() {
        let items = bottomItems.enumerated().map { (i, it) -> UITabBarItem in
            UITabBarItem(title: it.title, image: sf(it.icon, size: 18), tag: i)
        }
        tabBar.setItems(items, animated: false)
        drawer.setItems(drawerItems)
    }

    private func highlight(for url: String) {
        if let i = NavCatalog.match(url, in: bottomItems), let items = tabBar.items, i < items.count {
            tabBar.selectedItem = items[i]
        }
        if let j = NavCatalog.match(url, in: drawerItems) { drawer.select(index: j) }
    }

    private func urlChanged(_ url: URL) {
        if let a = AssetPaths.assetString(for: url) {
            highlight(for: a)
        } else if let s = url.scheme?.lowercased(), s == "http" || s == "https" {
            lastRealUrl = url.absoluteString
            highlight(for: url.absoluteString)
        }
    }

    @objc private func toggleDrawer() { drawerOpen ? closeDrawer() : openDrawer() }

    private func openDrawer() {
        drawerOpen = true
        dimView.isHidden = false
        view.layoutIfNeeded()
        drawerLeading.constant = 0
        UIView.animate(withDuration: 0.28, delay: 0, options: .curveEaseOut) {
            self.dimView.alpha = 1
            self.view.layoutIfNeeded()
        }
    }

    @objc private func closeDrawer() {
        guard drawerOpen else { return }
        drawerOpen = false
        drawerLeading.constant = -drawerWidth - 20
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn, animations: {
            self.dimView.alpha = 0
            self.view.layoutIfNeeded()
        }, completion: { _ in self.dimView.isHidden = true })
    }

    // MARK: - Načítanie
    func go(_ s: String) {
        if AssetPaths.isAsset(s) { loadAsset(s); return }
        if s.hasPrefix("file:") { return }
        lastRealUrl = s
        pingHost { [weak self] online in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if online { self.loadRemote(s) } else { self.showOfflineDialog() }
            }
        }
    }

    private func loadRemote(_ s: String) {
        guard let u = URL(string: s) else { return }
        programmaticURL = u
        webView.load(URLRequest(url: u, cachePolicy: .reloadIgnoringLocalCacheData))
    }

    private func loadAsset(_ s: String) {
        guard let u = AssetPaths.fileURL(for: s) else { return }
        webView.loadFileURL(u, allowingReadAccessTo: AssetPaths.dir)
    }

    private func reload() {
        if offlineMode, let last = lastRealUrl {
            retryConnection(target: last)
        } else if webView.url != nil {
            webView.reload()
        } else if let last = lastRealUrl {
            loadRemote(last)
        }
    }

    // MARK: - Sieť
    private func pingHost(_ done: @escaping (Bool) -> Void) {
        checkGenerate204("https://www.gstatic.com/generate_204") { ok in
            if ok { done(true) }
            else { self.checkGenerate204("https://connectivitycheck.gstatic.com/generate_204", done) }
        }
    }

    private func checkGenerate204(_ s: String, _ done: @escaping (Bool) -> Void) {
        guard let u = URL(string: s) else { done(false); return }
        let req = URLRequest(url: u, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 3)
        URLSession.shared.dataTask(with: req) { _, resp, _ in
            done((resp as? HTTPURLResponse)?.statusCode == 204)
        }.resume()
    }

    private func startMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            DispatchQueue.main.async { self?.pathChanged(online) }
        }
        monitor.start(queue: monitorQueue)
    }

    private func pathChanged(_ online: Bool) {
        if online {
            if offlineMode || overlay != nil {
                pingHost { [weak self] ok in
                    DispatchQueue.main.async { if ok { self?.becameOnline() } }
                }
            }
        } else if !offlineMode && !dialogShowing {
            showOfflineDialog()
        }
    }

    @objc private func appBecameActive() {
        guard dialogShowing else { return }
        pingHost { [weak self] ok in
            DispatchQueue.main.async { if ok { self?.becameOnline() } }
        }
    }

    private func becameOnline() {
        dismissOverlay()
        dialogShowing = false
        if offlineMode { exitOfflineMode() }
        if let last = lastRealUrl { loadRemote(last) }
    }

    private func retryConnection(target: String? = nil) {
        pingHost { [weak self] ok in
            DispatchQueue.main.async {
                guard let self = self, ok else { return }
                self.dismissOverlay()
                self.dialogShowing = false
                if self.offlineMode { self.exitOfflineMode() }
                if let t = target ?? self.lastRealUrl { self.loadRemote(t) }
            }
        }
    }

    // MARK: - Offline režim
    private func showOfflineDialog() {
        guard !dialogShowing, overlay == nil else { return }
        dialogShowing = true
        let ov = OfflineOverlayView()
        ov.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(ov)
        NSLayoutConstraint.activate([
            ov.topAnchor.constraint(equalTo: view.topAnchor),
            ov.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ov.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            ov.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        ov.onStartOffline = { [weak self] in
            guard let self = self else { return }
            self.dismissOverlay()
            self.dialogShowing = false
            self.enterOfflineMode()
            self.loadAsset(AssetPaths.prefix + "index_offline.html")
        }
        ov.onRetry = { [weak self] in self?.retryConnection() }
        ov.onWifi = {
            if let u = URL(string: "App-Prefs:root=WIFI") {
                UIApplication.shared.open(u, options: [:]) { ok in
                    if !ok, let s = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(s)
                    }
                }
            }
        }
        ov.onClose = { exit(0) }
        overlay = ov
        ov.present()
    }

    private func dismissOverlay() {
        overlay?.dismiss()
        overlay = nil
    }

    private func enterOfflineMode() {
        guard !offlineMode else { return }
        offlineMode = true
        bottomItems = NavCatalog.offlineBottom
        drawerItems = NavCatalog.offlineDrawer
        applyNavSets()
        tabBar.selectedItem = tabBar.items?.first
        drawer.select(index: 0)
        [backButton, forwardButton, reloadButton].forEach { $0.isHidden = true }
    }

    private func exitOfflineMode() {
        guard offlineMode else { return }
        offlineMode = false
        bottomItems = NavCatalog.onlineBottom
        drawerItems = NavCatalog.onlineDrawer
        applyNavSets()
        [backButton, forwardButton, reloadButton].forEach { $0.isHidden = false }
    }

    // MARK: - Solitaire (celá obrazovka)
    private func setSolitaire(_ on: Bool) {
        guard solitaireMode != on else { return }
        solitaireMode = on
        topBar.isHidden = on
        tabBar.isHidden = on
        solitaireClose.isHidden = !on
        progress.isHidden = true
        webTopToBar.isActive = !on
        webBottomToTab.isActive = !on
        webTopToView.isActive = on
        webBottomToView.isActive = on
        webView.scrollView.isScrollEnabled = !on
        webView.allowsBackForwardNavigationGestures = !on
        setNeedsStatusBarAppearanceUpdate()
        setNeedsUpdateOfHomeIndicatorAutoHidden()
        view.layoutIfNeeded()
    }

    // MARK: - Téma
    private func applyColorScheme() {
        let scheme = traitCollection.userInterfaceStyle == .dark ? "dark" : "light"
        webView.evaluateJavaScript(
            "(function(){document.documentElement.style.setProperty('color-scheme','\(scheme)');" +
            "var m=document.querySelector('meta[name=color-scheme]');" +
            "if(m){m.content='\(scheme)';}else{var n=document.createElement('meta');n.name='color-scheme';n.content='\(scheme)';document.head.appendChild(n);}})()",
            completionHandler: nil)
        styleTabBar()
        setNeedsStatusBarAppearanceUpdate()
    }

    // MARK: - Externé odkazy
    private static let trustedDomains = ["google.com", "github.io", "bing.com"]

    private func isWhitelisted(_ host: String?) -> Bool {
        guard let h = host?.lowercased() else { return false }
        return MainViewController.trustedDomains.contains { h == $0 || h.hasSuffix("." + $0) }
    }

    private func siteKey(_ host: String?) -> String? {
        guard let parts = host?.lowercased().split(separator: "."), parts.count >= 2 else { return host }
        return parts.suffix(2).joined(separator: ".")
    }

    /// Dôveryhodné = whitelist, alebo rovnaká doména ako práve zobrazená stránka.
    private func isTrusted(_ url: URL) -> Bool {
        if isWhitelisted(url.host) { return true }
        if let cur = webView.url?.host ?? lastRealUrl.flatMap({ URL(string: $0)?.host }),
           siteKey(cur) == siteKey(url.host) { return true }
        return false
    }

    private func openLink(_ url: URL) {
        guard let scheme = url.scheme?.lowercased() else { return }
        switch scheme {
        case "mailto", "tel":
            UIApplication.shared.open(url)
        case "http", "https":
            if isTrusted(url) { loadRemote(url.absoluteString) } else { openSafariSheet(url) }
        default:
            break
        }
    }

    private func openSafariSheet(_ url: URL) {
        let vc = SFSafariViewController(url: url)
        vc.preferredBarTintColor = traitCollection.userInterfaceStyle == .dark
            ? UIColor(hex: 0x0F172A) : UIColor(hex: 0xF1F5F9)
        present(vc, animated: true)
    }

    private func handleNavError(_ error: Error) {
        let ns = error as NSError
        progress.isHidden = true
        if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return }
        if ns.domain == "WebKitErrorDomain" { return }
        pingHost { [weak self] online in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if !online { self.showOfflineDialog() }
                else {
                    let html = "<html><head><meta name='viewport' content='width=device-width,initial-scale=1'></head>" +
                        "<body style='font-family:-apple-system;background:#0F172A;color:#E2E8F0;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;text-align:center'>" +
                        "<div><h2>Stránku sa nepodarilo načítať</h2><p>Skúste obnoviť.</p></div></body></html>"
                    self.webView.loadHTMLString(html, baseURL: nil)
                }
            }
        }
    }
}

// MARK: - UITabBarDelegate
extension MainViewController: UITabBarDelegate {
    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        guard item.tag < bottomItems.count else { return }
        go(bottomItems[item.tag].url)
        drawer.select(index: NavCatalog.match(bottomItems[item.tag].url, in: drawerItems))
    }
}

// MARK: - WKNavigationDelegate / WKUIDelegate
extension MainViewController: WKNavigationDelegate, WKUIDelegate {

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        let s = url.absoluteString
        let isMain = navigationAction.targetFrame?.isMainFrame ?? true
        let scheme = url.scheme?.lowercased() ?? ""

        // Staré Android odkazy v HTML
        if AssetPaths.isAsset(s) {
            decisionHandler(.cancel)
            if isMain { loadAsset(s) }
            return
        }

        switch scheme {
        case "file":
            decisionHandler(url.standardizedFileURL.path.hasPrefix(AssetPaths.dir.standardizedFileURL.path) ? .allow : .cancel)
        case "about", "blob", "data":
            decisionHandler(.allow)
        case "http", "https":
            if !isMain { decisionHandler(.allow); return }
            if let p = programmaticURL, p == url {
                programmaticURL = nil
                decisionHandler(.allow)
                return
            }
            switch navigationAction.navigationType {
            case .linkActivated:
                decisionHandler(.cancel)
                openLink(url)
            case .other:
                if isTrusted(url) { decisionHandler(.allow) }
                else { decisionHandler(.cancel); openSafariSheet(url) }
            default:
                decisionHandler(.allow)
            }
        case "mailto", "tel":
            decisionHandler(.cancel)
            UIApplication.shared.open(url)
        default:
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        progress.isHidden = true
        updateNavButtons()
        if let url = webView.url {
            if url.isFileURL, url.lastPathComponent == "solitaire.html" {
                setSolitaire(true)
            } else {
                setSolitaire(false)
            }
        }
        applyColorScheme()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleNavError(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleNavError(error)
    }

    // Popup okná (window.open / target=_blank)
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url { openLink(url) }
        return nil
    }
}
