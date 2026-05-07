import SwiftUI
import UIKit

/// Hosts ``ChooserView`` and resolves to a `PaymentMethod?` (`nil` =
/// dismissed). Backdrop is rendered by setting
/// `modalPresentationStyle = .overFullScreen` so the merchant's view stays
/// visible behind a translucent layer.
final class ChooserViewController: UIViewController {
    private let config: BushaPayConfig
    private let allowedPaymentMethods: [PaymentMethod]?
    private let merchantNameLoader: () async -> String?
    private let completion: (PaymentMethod?) -> Void

    private(set) var didComplete = false
    private var hostingController: UIHostingController<AnyView>?

    init(
        config: BushaPayConfig,
        allowedPaymentMethods: [PaymentMethod]?,
        merchantNameLoader: @escaping () async -> String?,
        completion: @escaping (PaymentMethod?) -> Void
    ) {
        self.config = config
        self.allowedPaymentMethods = allowedPaymentMethods
        self.merchantNameLoader = merchantNameLoader
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .overFullScreen
        self.modalTransitionStyle = .crossDissolve
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)

        let backdropTap = UITapGestureRecognizer(target: self, action: #selector(handleBackdropTap))
        view.addGestureRecognizer(backdropTap)

        renderHosting(merchantName: nil)

        Task { [weak self] in
            guard let self else { return }
            let name = await self.merchantNameLoader()
            await MainActor.run {
                guard !self.didComplete else { return }
                self.renderHosting(merchantName: name)
            }
        }
    }

    @objc func handleBackdropTap() { resolve(with: nil) }

    /// Resolves the chooser. Internal so tests can drive it directly
    /// without simulating a backdrop tap or SwiftUI button press.
    func resolve(with method: PaymentMethod?) {
        guard !didComplete else { return }
        didComplete = true
        let cb = completion
        if presentingViewController != nil {
            dismiss(animated: true) { cb(method) }
        } else {
            cb(method)
        }
    }

    private func renderHosting(merchantName: String?) {
        let body = ChooserView(
            config: config,
            merchantName: merchantName,
            allowedPaymentMethods: allowedPaymentMethods,
            onChoose: { [weak self] method in self?.resolve(with: method) },
            onDismiss: { [weak self] in self?.resolve(with: nil) }
        )

        // Block backdrop taps that hit the dialog itself.
        let dialog = body.background(Color.clear).contentShape(Rectangle())
            .onTapGesture { /* swallow */ }

        if let hostingController {
            hostingController.rootView = AnyView(dialog)
            return
        }

        let host = UIHostingController(rootView: AnyView(dialog))
        host.view.backgroundColor = .clear
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        host.didMove(toParent: self)
        hostingController = host
    }
}
