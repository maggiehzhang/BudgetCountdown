import Foundation

struct BudgetCalculator {
    static func currentPeriodStart(cycleDay: Int = 24) -> Date {
        let cal = Calendar.current
        let today = Date()
        let day = cal.component(.day, from: today)
        let year = cal.component(.year, from: today)
        let month = cal.component(.month, from: today)

        if day >= cycleDay {
            return cal.date(from: DateComponents(year: year, month: month, day: cycleDay))!
        } else {
            let prevComponents = cal.dateComponents([.year, .month], from: cal.date(byAdding: .month, value: -1, to: today)!)
            return cal.date(from: DateComponents(year: prevComponents.year, month: prevComponents.month, day: cycleDay))!
        }
    }

    static func currentPeriodEnd(cycleDay: Int = 24) -> Date {
        let start = currentPeriodStart(cycleDay: cycleDay)
        let cal = Calendar.current
        // End is the 23rd of the month following the start
        let nextMonth = cal.date(byAdding: .month, value: 1, to: start)!
        let components = cal.dateComponents([.year, .month], from: nextMonth)
        return cal.date(from: DateComponents(year: components.year, month: components.month, day: 23))!
    }

    static func remaining(budget: Double, chaseSpent: Double, plannedSpends: [PlannedSpend]) -> Double {
        let planned = plannedSpends.reduce(0) { $0 + $1.amount }
        return budget - chaseSpent - planned
    }

    static func percentUsed(budget: Double, chaseSpent: Double, plannedSpends: [PlannedSpend]) -> Double {
        let spent = chaseSpent + plannedSpends.reduce(0) { $0 + $1.amount }
        guard budget > 0 else { return 0 }
        return min(spent / budget, 1.0)
    }
}
