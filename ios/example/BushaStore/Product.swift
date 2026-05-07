import Foundation

struct Product: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let price: String
    let currency: String
    let emoji: String
}

extension Product {
    static let all: [Product] = [
        Product(
            id: "p1",
            name: "Macbook Pro 13\"",
            description: "Apple M3 chip, 16GB unified memory, 512GB SSD storage.",
            price: "20000",
            currency: "NGN",
            emoji: "💻"
        ),
        Product(
            id: "p2",
            name: "iPhone 15 Pro",
            description: "256GB, Titanium. The best iPhone yet.",
            price: "15000",
            currency: "NGN",
            emoji: "📱"
        ),
        Product(
            id: "p3",
            name: "AirPods Pro",
            description: "Active Noise Cancellation, Transparency mode, Adaptive Audio.",
            price: "8500",
            currency: "NGN",
            emoji: "🎧"
        ),
    ]
}
