import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationView {
            List(Product.all) { product in
                NavigationLink(destination: ProductDetailView(product: product)) {
                    HStack(spacing: 16) {
                        Text(product.emoji)
                            .font(.system(size: 40))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(product.name)
                                .font(.headline)
                            Text("₦\(product.price)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Busha Store")
        }
        .navigationViewStyle(.stack)
    }
}
