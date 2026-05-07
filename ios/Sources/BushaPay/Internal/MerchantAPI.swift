import Foundation

enum MerchantAPI {
    static func fetchName(
        publicKey: String,
        platformUrl: String,
        session: URLSession = .shared
    ) async -> String? {
        guard var components = URLComponents(string: platformUrl) else { return nil }
        components.path = "/v1/merchants"
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 5)
        request.setValue(publicKey, forHTTPHeaderField: "X-BU-PUBLIC-KEY")
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            guard
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let payload = json["data"] as? [String: Any],
                let name = payload["username"] as? String,
                !name.isEmpty
            else {
                return nil
            }
            return name
        } catch {
            return nil
        }
    }
}
