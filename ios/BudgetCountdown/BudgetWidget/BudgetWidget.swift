import WidgetKit
import SwiftUI

struct BudgetEntry: TimelineEntry {
    let date: Date
    let remaining: Double
    let total: Double
    let periodStart: String
    let periodEnd: String
}

struct BudgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> BudgetEntry {
        BudgetEntry(date: .now, remaining: 2140, total: 3660, periodStart: "Apr 24", periodEnd: "May 23")
    }

    func getSnapshot(in context: Context, completion: @escaping (BudgetEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BudgetEntry>) -> Void) {
        let entries = [entry()]
        // Refresh every hour
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
        completion(Timeline(entries: entries, policy: .after(nextUpdate)))
    }

    private func entry() -> BudgetEntry {
        BudgetEntry(
            date: .now,
            remaining: SharedDefaults.remainingBudget,
            total: SharedDefaults.totalBudget,
            periodStart: SharedDefaults.periodStart,
            periodEnd: SharedDefaults.periodEnd
        )
    }
}

struct SmallWidgetView: View {
    let entry: BudgetEntry

    var body: some View {
        VStack(spacing: 4) {
            Text(entry.remaining, format: .currency(code: "USD").precision(.fractionLength(0)))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(entry.remaining < 0 ? .red : entry.remaining < 500 ? .orange : .primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text("left this cycle")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Gauge(value: max(0, entry.total - entry.remaining), in: 0...entry.total) {}
                .gaugeStyle(.linearCapacity)
                .tint(entry.remaining < 0 ? .red : entry.remaining < 500 ? .orange : .green)
        }
        .padding(12)
        .containerBackground(.regularMaterial, for: .widget)
    }
}

struct MediumWidgetView: View {
    let entry: BudgetEntry

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.remaining, format: .currency(code: "USD").precision(.fractionLength(0)))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(entry.remaining < 0 ? .red : entry.remaining < 500 ? .orange : .primary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Text("left to spend")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Gauge(value: max(0, entry.total - entry.remaining), in: 0...entry.total) {}
                    .gaugeStyle(.linearCapacity)
                    .tint(entry.remaining < 0 ? .red : entry.remaining < 500 ? .orange : .green)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Label("Cycle", systemImage: "calendar")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if !entry.periodStart.isEmpty {
                    Text("\(entry.periodStart) –")
                        .font(.caption)
                    Text(entry.periodEnd)
                        .font(.caption)
                }

                Spacer()

                Text("\(entry.total - entry.remaining, specifier: "%.0f") spent")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 100, alignment: .leading)
        }
        .padding(16)
        .containerBackground(.regularMaterial, for: .widget)
    }
}

@main
struct BudgetWidget: Widget {
    let kind = "BudgetCountdownWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BudgetProvider()) { entry in
            Group {
                if #available(iOS 17, *) {
                    SmallWidgetView(entry: entry)
                } else {
                    SmallWidgetView(entry: entry)
                }
            }
        }
        .configurationDisplayName("Budget Countdown")
        .description("Shows how much you have left to spend this Chase billing cycle.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct BudgetWidget_Previews: PreviewProvider {
    static var previews: some View {
        let entry = BudgetEntry(date: .now, remaining: 2140, total: 3660, periodStart: "Apr 24", periodEnd: "May 23")
        SmallWidgetView(entry: entry).previewContext(WidgetPreviewContext(family: .systemSmall))
        MediumWidgetView(entry: entry).previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
