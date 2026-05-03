import SwiftUI
import LinkKit

// Holds the Plaid handler at app scope so it's never deallocated mid-flow
private var plaidHandler: Handler?

struct SetupView: View {
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @ObservedObject var api: APIClient

    @State private var isLinked = UserDefaults.standard.bool(forKey: "chaseLinked")
    @State private var statusMessage = ""
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: isLinked ? "checkmark.seal.fill" : "link.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(isLinked ? .green : .blue)

                Text(isLinked ? "Chase is connected" : "Connect your Chase account")
                    .font(.title2.bold())

                Text(isLinked
                    ? "Your Chase Sapphire Reserve is linked. Transactions are pulled automatically."
                    : "Link your Chase account once. After that, the app pulls your transactions daily.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .foregroundStyle(.orange)
                        .font(.caption)
                }

                Button(isLinked ? "Re-link Chase" : "Connect Chase") {
                    Task { await startLink() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isLoading)

                if isLoading { ProgressView() }
            }
            .padding(32)
            .navigationTitle("Account Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func startLink() async {
        statusMessage = ""
        isLoading = true
        defer { isLoading = false }

        guard let token = await api.getLinkToken() else {
            statusMessage = "Could not reach backend. Is it running?"
            return
        }

        var config = LinkTokenConfiguration(token: token) { success in
            print("✅ Plaid success: \(success.publicToken)")
            Task { @MainActor in await handleSuccess(publicToken: success.publicToken) }
        }
        config.onExit = { exit in
            print("🚪 Plaid exit: \(String(describing: exit.error))")
        }
        config.onEvent = { event in
            print("📍 Plaid event: \(event.eventName)")
        }

        switch Plaid.create(config) {
        case .success(let handler):
            plaidHandler = handler  // retain at app scope
            guard let rootVC = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
                .first else {
                statusMessage = "Could not find root view controller."
                return
            }
            handler.open(presentUsing: .custom { linkVC in
                linkVC.modalPresentationStyle = .fullScreen
                self.topVC(rootVC).present(linkVC, animated: true)
            })
        case .failure(let error):
            statusMessage = "Plaid setup error: \(error.localizedDescription)"
        }
    }

    private func topVC(_ vc: UIViewController) -> UIViewController {
        if let presented = vc.presentedViewController { return topVC(presented) }
        return vc
    }

    private func handleSuccess(publicToken: String) async {
        let ok = await api.exchangeToken(publicToken)
        if ok {
            isLinked = true
            UserDefaults.standard.set(true, forKey: "chaseLinked")
            statusMessage = ""
        } else {
            statusMessage = "Token exchange failed. Check backend logs."
        }
    }
}
