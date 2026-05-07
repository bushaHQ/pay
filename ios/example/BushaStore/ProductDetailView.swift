import BushaPay
import SwiftUI
import UIKit

struct ProductDetailView: View {
    let product: Product
    @State private var isProcessing = false
    @State private var receipt: BushaPayResult?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 16) {
                Text(product.emoji)
                    .font(.system(size: 120))
                Text(product.name)
                    .font(.title)
                    .bold()
                Text("₦\(product.price)")
                    .font(.title2)
                    .foregroundColor(.secondary)
                Text(product.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 32)

            Spacer()

            Button(action: handleBuy) {
                HStack {
                    Spacer()
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Buy for ₦\(product.price)")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                .padding(.vertical, 16)
                .background(Color(red: 0, green: 200/255, blue: 83/255))
                .cornerRadius(8)
            }
            .disabled(isProcessing)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .navigationTitle(product.name)
        .navigationBarTitleDisplayMode(.inline)
        .background(
            NavigationLink(
                destination: receipt.map { ReceiptView(product: product, result: $0) },
                isActive: Binding(get: { receipt != nil }, set: { if !$0 { receipt = nil } })
            ) { EmptyView() }
        )
    }

    private func handleBuy() {
        guard let presenter = topViewController() else { return }
        isProcessing = true
        BushaPay.checkout(
            config: BushaPayConfig(
                quoteAmount: product.price,
                quoteCurrency: product.currency,
                targetCurrency: "USDT",
                sourceCurrency: "USDT",
                reference: "ORDER_\(product.id)_\(Int(Date().timeIntervalSince1970 * 1000))",
                metaName: "Test Customer",
                metaEmail: "test@example.com"
            ),
            from: presenter
        ) { result in
            isProcessing = false
            receipt = result
        }
    }
}

private func topViewController() -> UIViewController? {
    let scene = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first(where: { $0.activationState == .foregroundActive })
    let root = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
    var top = root
    while let presented = top?.presentedViewController {
        top = presented
    }
    return top
}
