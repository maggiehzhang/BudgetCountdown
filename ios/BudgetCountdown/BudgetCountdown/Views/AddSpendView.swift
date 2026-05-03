import SwiftUI
import SwiftData
import WidgetKit

struct AddSpendView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var plannedSpends: [PlannedSpend]
    @AppStorage("monthlyBudget") private var monthlyBudget: Double = 3660

    @State private var name = ""
    @State private var amountText = ""

    private var amount: Double { Double(amountText) ?? 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section("What are you planning to spend on?") {
                    TextField("e.g. Dinner with friends", text: $name)
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                }

                if amount > 0 {
                    Section("Impact") {
                        let newRemaining = SharedDefaults.remainingBudget - amount
                        HStack {
                            Text("Remaining after")
                            Spacer()
                            Text(newRemaining, format: .currency(code: "USD").precision(.fractionLength(0)))
                                .foregroundStyle(newRemaining < 0 ? .red : .primary)
                                .bold()
                        }
                    }
                }
            }
            .navigationTitle("Add Planned Spend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .disabled(name.isEmpty || amount <= 0)
                }
            }
        }
    }

    private func save() {
        let spend = PlannedSpend(name: name, amount: amount)
        modelContext.insert(spend)
        SharedDefaults.remainingBudget -= amount
        WidgetCenter.shared.reloadAllTimelines()
        dismiss()
    }
}
