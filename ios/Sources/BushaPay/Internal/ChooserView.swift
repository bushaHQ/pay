import SwiftUI

/// SwiftUI body of the chooser. Hosted via `UIHostingController` from
/// ``ChooserPresenter``.
struct ChooserView: View {
    let config: BushaPayConfig
    let merchantName: String?
    let allowedPaymentMethods: [PaymentMethod]?
    let onChoose: (PaymentMethod) -> Void
    let onDismiss: () -> Void

    func shows(_ method: PaymentMethod) -> Bool {
        guard let allowed = allowedPaymentMethods, !allowed.isEmpty else { return true }
        return allowed.contains(method)
    }

    var body: some View {
        let showsBusha = shows(.bushaApp)
        let showsStablecoins = shows(.stablecoins)

        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text("Pay \(formatAmount(config.quoteAmount)) \(config.quoteCurrency)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(textHigh)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(textHigh)
                }
                .accessibilityLabel("Close")
            }

            if let name = merchantName {
                Text("To \(name)")
                    .font(.system(size: 16))
                    .foregroundColor(textMid)
                    .padding(.top, 8)
            }

            Spacer().frame(height: 32)

            Text("Choose a payment method")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(textHigh)

            Spacer().frame(height: 12)

            if showsBusha {
                MethodTile(
                    name: "Busha",
                    description: "Make payment directly from your busha account",
                    iconAsset: "busha",
                    onTap: { onChoose(.bushaApp) }
                )
            }
            if showsBusha && showsStablecoins {
                Spacer().frame(height: 16)
            }
            if showsStablecoins {
                MethodTile(
                    name: "Stablecoins",
                    description: "Make payment from an external wallet",
                    iconAsset: "wallet-outline",
                    onTap: { onChoose(.stablecoins) }
                )
            }

            Spacer().frame(height: 32)

            HStack(spacing: 8) {
                Spacer()
                Text("Secured by")
                    .font(.system(size: 12))
                    .foregroundColor(textMid)
                Image("busha-logo", bundle: .module)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 14)
                Spacer()
            }
        }
        .padding(20)
        .background(containmentPrimary)
        .cornerRadius(20)
        .padding(.horizontal, 16)
    }
}

private struct MethodTile: View {
    let name: String
    let description: String
    let iconAsset: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(containmentSecondary)
                        .frame(width: 40, height: 40)
                    Image(iconAsset, bundle: .module)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .foregroundColor(textHigh)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(textHigh)
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(textMid)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(textMid)
            }
            .padding(16)
            .background(containmentTertiary)
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
    }
}

func formatAmount(_ amount: String) -> String {
    let trimmed = amount.trimmingCharacters(in: .whitespaces)
    guard let n = Double(trimmed) else { return amount }
    let hasDecimals = n.truncatingRemainder(dividingBy: 1) != 0
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.usesGroupingSeparator = true
    formatter.groupingSeparator = ","
    formatter.decimalSeparator = "."
    formatter.minimumFractionDigits = hasDecimals ? 2 : 0
    formatter.maximumFractionDigits = hasDecimals ? 2 : 0
    return formatter.string(from: NSNumber(value: n)) ?? amount
}

private let textHigh = Color(red: 0, green: 0, blue: 0)
private let textMid = Color(red: 88 / 255, green: 101 / 255, blue: 88 / 255)
private let containmentPrimary = Color(red: 237 / 255, green: 242 / 255, blue: 237 / 255)
private let containmentSecondary = Color(red: 209 / 255, green: 217 / 255, blue: 209 / 255)
private let containmentTertiary = Color(red: 1, green: 1, blue: 1)
