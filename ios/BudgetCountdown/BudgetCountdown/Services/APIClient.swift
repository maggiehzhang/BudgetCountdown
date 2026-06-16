import Foundation

struct Transaction: Codable, Identifiable {
    let id: String
    let date: String
    let name: String
    let amount: Double
    let category: String?
    let pending: Bool
}

struct TransactionsResponse: Codable {
    let periodStart: String
    let periodEnd: String
    let transactions: [Transaction]
    let totalSpent: Double
}

@MainActor
class APIClient: ObservableObject {
    static var baseURL: String {
        UserDefaults.standard.string(forKey: "backendURL") ?? "https://budget-countdown-backend.onrender.com"
    }

    @Published var isLoading = false
    @Published var error: String?

    func fetchTransactions() async -> TransactionsResponse? {
        guard let url = URL(string: "\(Self.baseURL)/transactions") else { return nil }
        isLoading = true
        defer { isLoading = false }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode(TransactionsResponse.self, from: data)
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    func getLinkToken() async -> String? {
        guard let url = URL(string: "\(Self.baseURL)/link-token") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try JSONDecoder().decode([String: String].self, from: data)
            return json["link_token"]
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    func exchangeToken(_ publicToken: String) async -> Bool {
        guard let url = URL(string: "\(Self.baseURL)/exchange-token") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["public_token": publicToken])

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
