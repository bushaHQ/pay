import BushaPay
import SwiftUI

@main
struct BushaStoreApp: App {
    init() {
        // The public key is supplied at build time via the
        // BUSHA_PUBLIC_KEY user-defined build setting (see README).
        let publicKey = Bundle.main.object(forInfoDictionaryKey: "BushaPublicKey") as? String ?? ""
        BushaPay.initialize(publicKey: publicKey, environment: .sandbox)
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .onOpenURL { url in
                    // Forward incoming URLs so the SDK can resolve checkout
                    // callbacks. Returns true when consumed; we don't have
                    // any other deep-link handling in this example.
                    BushaPay.handleDeepLink(url)
                }
        }
    }
}
