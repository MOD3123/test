import UIKit
import AVFoundation

/// Hľadáčik s tmavým okolím a animovanou čiarou (port z QrScannerActivity.ViewfinderView).
final class ViewfinderView: UIView {
    private let lineLayer = CAGradientLayer()
    private let corners = CAShapeLayer()
    private var frameRect: CGRect = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        lineLayer.colors = [UIColor.clear.cgColor, UIColor(hex: 0x60A5FA).cgColor, UIColor.clear.cgColor]
        lineLayer.startPoint = CGPoint(x: 0, y: 0.5)
        lineLayer.endPoint = CGPoint(x: 1, y: 0.5)
        layer.addSublayer(lineLayer)
        corners.strokeColor = UIColor.white.cgColor
        corners.fillColor = UIColor.clear.cgColor
        corners.lineWidth = 4
        corners.lineCap = .round
        layer.addSublayer(corners)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let side = min(bounds.width, bounds.height) * 0.6
        frameRect = CGRect(x: bounds.midX - side / 2, y: bounds.midY - side / 2 - 30, width: side, height: side)
        setNeedsDisplay()

        let l: CGFloat = 36
        let r = frameRect
        let p = UIBezierPath()
        for (cx, cy, dx, dy) in [(r.minX, r.minY, 1.0, 1.0), (r.maxX, r.minY, -1.0, 1.0),
                                 (r.minX, r.maxY, 1.0, -1.0), (r.maxX, r.maxY, -1.0, -1.0)] {
            p.move(to: CGPoint(x: cx + CGFloat(dx) * l, y: cy))
            p.addLine(to: CGPoint(x: cx, y: cy))
            p.addLine(to: CGPoint(x: cx, y: cy + CGFloat(dy) * l))
        }
        corners.path = p.cgPath

        lineLayer.frame = CGRect(x: r.minX + 8, y: r.minY, width: r.width - 16, height: 3)
        lineLayer.removeAllAnimations()
        let a = CABasicAnimation(keyPath: "position.y")
        a.fromValue = r.minY + 4
        a.toValue = r.maxY - 4
        a.duration = 1.8
        a.autoreverses = true
        a.repeatCount = .infinity
        a.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        lineLayer.add(a, forKey: "scan")
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.setFillColor(UIColor.black.withAlphaComponent(0.55).cgColor)
        ctx.fill(rect)
        ctx.setBlendMode(.clear)
        UIBezierPath(roundedRect: frameRect, cornerRadius: 20).fill()
    }
}

/// Spoločný základ pre QR a Tesco skener (AVFoundation).
class CameraScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    let statusLabel = UILabel()
    let viewfinder = ViewfinderView()

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "webcenter.camera")
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var configured = false
    private var paused = false

    /// Podtrieda určí typy kódov.
    var codeTypes: [AVMetadataObject.ObjectType] { return [] }

    /// Volá sa na hlavnom vlákne po prvom detegovanom kóde.
    func didDetect(code: String, type: AVMetadataObject.ObjectType) {}

    override var preferredStatusBarStyle: UIStatusBarStyle { return .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        viewfinder.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(viewfinder)

        statusLabel.textColor = .white
        statusLabel.font = .systemFont(ofSize: 15, weight: .medium)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.layer.shadowColor = UIColor.black.cgColor
        statusLabel.layer.shadowOpacity = 0.8
        statusLabel.layer.shadowRadius = 3
        statusLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            viewfinder.topAnchor.constraint(equalTo: view.topAnchor),
            viewfinder.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            viewfinder.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            viewfinder.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
        updateOrientation()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopCamera()
    }

    private func updateOrientation() {
        guard let conn = previewLayer.connection, conn.isVideoOrientationSupported,
              let o = AVCaptureVideoOrientation(rawValue:
                (view.window?.windowScene?.interfaceOrientation
                    ?? UIApplication.shared.statusBarOrientation).rawValue) else { return }
        conn.videoOrientation = o
    }

    // MARK: Kamera
    func startCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            runSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.runSession() } else { self?.cameraDenied() }
                }
            }
        default:
            cameraDenied()
        }
    }

    private func cameraDenied() {
        statusLabel.text = "Prístup ku kamere je zakázaný. Povoľte ho v Nastaveniach."
    }

    private func runSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.configured {
                self.session.beginConfiguration()
                self.session.sessionPreset = .high
                guard let dev = AVCaptureDevice.default(for: .video),
                      let input = try? AVCaptureDeviceInput(device: dev),
                      self.session.canAddInput(input) else {
                    self.session.commitConfiguration()
                    DispatchQueue.main.async { self.statusLabel.text = "Chyba kamery: nedostupná" }
                    return
                }
                self.session.addInput(input)
                let out = AVCaptureMetadataOutput()
                if self.session.canAddOutput(out) {
                    self.session.addOutput(out)
                    out.setMetadataObjectsDelegate(self, queue: .main)
                    let wanted = self.codeTypes
                    let avail = out.availableMetadataObjectTypes
                    out.metadataObjectTypes = wanted.filter { avail.contains($0) }
                }
                self.session.commitConfiguration()
                self.configured = true
                // Plynulé ostrenie pri blízkych kódoch
                if (try? dev.lockForConfiguration()) != nil {
                    if dev.isFocusModeSupported(.continuousAutoFocus) { dev.focusMode = .continuousAutoFocus }
                    dev.unlockForConfiguration()
                }
            }
            if !self.session.isRunning { self.session.startRunning() }
            DispatchQueue.main.async { self.paused = false }
        }
    }

    func stopCamera() {
        sessionQueue.async { [weak self] in
            if self?.session.isRunning == true { self?.session.stopRunning() }
        }
    }

    func resumeScanning() { paused = false }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !paused else { return }
        for o in objects {
            if let code = o as? AVMetadataMachineReadableCodeObject, let value = code.stringValue, !value.isEmpty {
                paused = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                didDetect(code: value, type: code.type)
                return
            }
        }
    }

    // MARK: Pomocné
    func makeTopBar(title: String, showBack: Bool) -> UIView {
        let bar = UIView()
        bar.translatesAutoresizingMaskIntoConstraints = false
        let close = UIButton(type: .system)
        close.setImage(sf(showBack ? "chevron.left" : "xmark", size: 20), for: .normal)
        close.tintColor = .white
        close.translatesAutoresizingMaskIntoConstraints = false
        close.addAction(UIAction { [weak self] _ in self?.closeTapped() }, for: .touchUpInside)
        let t = UILabel()
        t.text = title
        t.textColor = .white
        t.font = .systemFont(ofSize: 17, weight: .semibold)
        t.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(close)
        bar.addSubview(t)
        view.addSubview(bar)
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bar.heightAnchor.constraint(equalToConstant: 60),
            close.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 12),
            close.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            close.widthAnchor.constraint(equalToConstant: 44),
            close.heightAnchor.constraint(equalToConstant: 44),
            t.leadingAnchor.constraint(equalTo: close.trailingAnchor, constant: 8),
            t.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
        ])
        return bar
    }

    /// Predvolene: zatvoriť obrazovku.
    func closeTapped() {
        if let nav = navigationController, nav.viewControllers.count > 1 {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    /// Spodná karta s výsledkom (max. šírka pre iPad).
    func makeResultCard() -> UIView {
        let card = UIView()
        card.backgroundColor = Theme.surface
        card.layer.cornerRadius = 24
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.3
        card.layer.shadowRadius = 12
        card.isHidden = true
        card.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(card)
        let fill = card.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -32)
        fill.priority = .defaultHigh
        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            card.widthAnchor.constraint(lessThanOrEqualToConstant: 600),
            fill,
            card.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])
        return card
    }

    func showCard(_ card: UIView) {
        card.isHidden = false
        view.layoutIfNeeded()
        card.transform = CGAffineTransform(translationX: 0, y: card.bounds.height + 200)
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) { card.transform = .identity }
    }

    func hideCard(_ card: UIView) {
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn, animations: {
            card.transform = CGAffineTransform(translationX: 0, y: card.bounds.height + 200)
        }, completion: { _ in card.isHidden = true })
    }
}
