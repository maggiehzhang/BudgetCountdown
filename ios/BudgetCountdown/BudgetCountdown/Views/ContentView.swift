import SwiftUI
import SwiftData
import WidgetKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var plannedSpends: [PlannedSpend]
    @StateObject private var api = APIClient()
    @AppStorage("monthlyBudget") private var monthlyBudget: Double = 3660
    @AppStorage("cycleDayStart") private var cycleDayStart: Int = 24

    @State private var chaseSpent: Double = 0
    @State private var transactions: [Transaction] = []
    @State private var showAddSpend = false
    @State private var showSettings = false
    @State private var showSetup = false

    private var remaining: Double {
        BudgetCalculator.remaining(budget: monthlyBudget, chaseSpent: chaseSpent, plannedSpends: plannedSpends)
    }

    private var percentUsed: Double {
        BudgetCalculator.percentUsed(budget: monthlyBudget, chaseSpent: chaseSpent, plannedSpends: plannedSpends)
    }

    private var periodStart: Date { BudgetCalculator.currentPeriodStart(cycleDay: cycleDayStart) }
    private var periodEnd: Date { BudgetCalculator.currentPeriodEnd(cycleDay: cycleDayStart) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    periodHeader

                    countdownCard

                    if !plannedSpends.isEmpty {
                        plannedSpendsSection
                    }

                    chaseBreakdown
                }
                .padding()
            }
            .navigationTitle("Budget")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSetup = true } label: {
                        Image(systemName: "link.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showAddSpend) {
                AddSpendView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showSetup) {
                SetupView(api: api)
            }
            .onAppear { syncWidget() }
            .task { await refresh() }
            .refreshable { await refresh() }
        }
    }

    private var periodHeader: some View {
        Text("\(periodStart.formatted(.dateTime.month(.abbreviated).day())) – \(periodEnd.formatted(.dateTime.month(.abbreviated).day()))")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private var countdownCard: some View {
        VStack(spacing: 12) {
            Text(remaining, format: .currency(code: "USD").precision(.fractionLength(0)))
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundStyle(remaining < 0 ? .red : remaining < 500 ? .orange : .primary)
                .contentTransition(.numericText())

            Text("left to spend")
                .font(.title3)
                .foregroundStyle(.secondary)

            ProgressView(value: percentUsed)
                .tint(remaining < 0 ? .red : remaining < 500 ? .orange : .green)
                .scaleEffect(x: 1, y: 2)
                .padding(.top, 4)

            Text("\(monthlyBudget - remaining, specifier: "%.0f") of \(monthlyBudget, specifier: "%.0f") used")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                showAddSpend = true
            } label: {
                Label("Add planned spend", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var plannedSpendsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Planned Spends")
                .font(.headline)

            ForEach(plannedSpends) { spend in
                HStack {
                    Text(spend.name)
                    Spacer()
                    Text(spend.amount, format: .currency(code: "USD").precision(.fractionLength(0)))
                        .foregroundStyle(.red)
                    Button {
                        modelContext.delete(spend)
                        syncWidget()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var chaseBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Chase this period")
                    .font(.headline)
                Spacer()
                Text(chaseSpent, format: .currency(code: "USD"))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if transactions.isEmpty {
                Text("No transactions yet")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(transactions.filter { $0.amount > 0 }) { tx in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tx.name)
                                .font(.subheadline)
                                .lineLimit(1)
                            HStack(spacing: 4) {
                                Text(formattedDate(tx.date))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                if tx.pending {
                                    Text("Pending")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                        Spacer()
                        Text(tx.amount, format: .currency(code: "USD").precision(.fractionLength(2)))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(tx.pending ? .orange : .secondary)
                    }
                    Divider()
                }
            }

            if let updated = SharedDefaults.lastUpdated {
                Text("Updated \(updated.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func formattedDate(_ dateStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateStr) else { return dateStr }
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func refresh() async {
        guard let response = await api.fetchTransactions() else { return }
        withAnimation {
            chaseSpent = response.totalSpent
            transactions = response.transactions.sorted { $0.date > $1.date }
        }
        SharedDefaults.remainingBudget = BudgetCalculator.remaining(
            budget: monthlyBudget, chaseSpent: response.totalSpent, plannedSpends: plannedSpends)
        SharedDefaults.totalBudget = monthlyBudget
        SharedDefaults.periodStart = response.periodStart
        SharedDefaults.periodEnd = response.periodEnd
        SharedDefaults.lastUpdated = Date()
        syncWidget()
    }

    private func syncWidget() {
        SharedDefaults.remainingBudget = BudgetCalculator.remaining(
            budget: monthlyBudget, chaseSpent: chaseSpent, plannedSpends: plannedSpends)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
