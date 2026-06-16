import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("monthlyBudget") private var monthlyBudget: Double = 3660
    @AppStorage("cycleDayStart") private var cycleDayStart: Int = 24
    @AppStorage("backendURL") private var backendURL: String = "https://budget-countdown-backend.onrender.com"

    @State private var budgetText = ""
    @State private var cycleDayText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Budget") {
                    HStack {
                        Text("Monthly budget")
                        Spacer()
                        TextField("3660", text: $budgetText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    Text("Your take-home minus rent. Default: $3,660.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Billing Cycle") {
                    HStack {
                        Text("Cycle starts on day")
                        Spacer()
                        TextField("24", text: $cycleDayText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                    Text("Your Chase billing cycle starts on the 24th of each month.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Backend") {
                    TextField("https://budget-countdown-backend.onrender.com", text: $backendURL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    Text("URL of your Node.js backend. Use http://localhost:3000 while developing locally.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .onAppear {
                budgetText = String(format: "%.0f", monthlyBudget)
                cycleDayText = "\(cycleDayStart)"
            }
        }
    }

    private func save() {
        if let v = Double(budgetText), v > 0 { monthlyBudget = v }
        if let v = Int(cycleDayText), v >= 1 && v <= 28 { cycleDayStart = v }
        dismiss()
    }
}
