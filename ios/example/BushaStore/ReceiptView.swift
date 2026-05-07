import BushaPay
import SwiftUI

struct ReceiptView: View {
    let product: Product
    let result: BushaPayResult
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        let info = receiptInfo(for: result)

        VStack(spacing: 0) {
            VStack(spacing: 16) {
                Image(systemName: info.systemImage)
                    .font(.system(size: 80))
                    .foregroundColor(info.color)
                Text(info.title)
                    .font(.title2)
                    .bold()
                    .foregroundColor(info.color)
            }
            .padding(.top, 32)

            Spacer().frame(height: 24)

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Text(product.emoji)
                        .font(.system(size: 32))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.name)
                            .font(.headline)
                        Text("₦\(product.price)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Divider()
                Text(info.details)
                    .font(.system(size: 12, design: .monospaced))
            }
            .padding(16)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.separator), lineWidth: 1)
            )

            Spacer()

            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Text("Back to store")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.separator), lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .navigationTitle("Receipt")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ReceiptInfo {
    let systemImage: String
    let color: Color
    let title: String
    let details: String
}

private func receiptInfo(for result: BushaPayResult) -> ReceiptInfo {
    switch result {
    case .success(let payment):
        return ReceiptInfo(
            systemImage: "checkmark.circle.fill",
            color: .green,
            title: "Payment successful",
            details: "Payment ID: \(payment.paymentId)\nStatus: \(payment.status)"
        )
    case .cancelled:
        return ReceiptInfo(
            systemImage: "xmark.circle",
            color: .orange,
            title: "Payment cancelled",
            details: "You cancelled the payment."
        )
    case .error(let err):
        let codeLine = err.code.map { "\nCode: \($0)" } ?? ""
        return ReceiptInfo(
            systemImage: "exclamationmark.triangle.fill",
            color: .red,
            title: "Payment failed",
            details: "Error: \(err.message)\(codeLine)"
        )
    }
}
