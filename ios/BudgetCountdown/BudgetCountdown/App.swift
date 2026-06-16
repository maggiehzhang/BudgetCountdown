import SwiftUI
import SwiftData
import BackgroundTasks
import WidgetKit

let bgTaskID = "com.maggie.budgetcountdown.refresh"

@main
struct BudgetCountdownApp: App {

    init() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: bgTaskID, using: nil) { task in
            handleBackgroundRefresh(task: task as! BGAppRefreshTask)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onReceive(NotificationCenter.default.publisher(
                    for: UIApplication.didEnterBackgroundNotification)) { _ in
                    scheduleBackgroundRefresh()
                }
        }
        .modelContainer(for: PlannedSpend.self)
    }
}

func scheduleBackgroundRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: bgTaskID)
    // Run at 8am the next calendar day
    var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
    components.day! += 1
    components.hour = 8
    components.minute = 0
    request.earliestBeginDate = Calendar.current.date(from: components)
    try? BGTaskScheduler.shared.submit(request)
}

func handleBackgroundRefresh(task: BGAppRefreshTask) {
    scheduleBackgroundRefresh() // reschedule for tomorrow

    let fetchTask = Task {
        let baseURL = UserDefaults.standard.string(forKey: "backendURL") ?? "https://budget-countdown-backend.onrender.com"
        guard let url = URL(string: "\(baseURL)/transactions") else {
            task.setTaskCompleted(success: false)
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(TransactionsResponse.self, from: data)
            SharedDefaults.remainingBudget = SharedDefaults.totalBudget - response.totalSpent
            SharedDefaults.periodStart = response.periodStart
            SharedDefaults.periodEnd = response.periodEnd
            SharedDefaults.lastUpdated = Date()
            WidgetCenter.shared.reloadAllTimelines()
            task.setTaskCompleted(success: true)
        } catch {
            task.setTaskCompleted(success: false)
        }
    }

    task.expirationHandler = {
        fetchTask.cancel()
        task.setTaskCompleted(success: false)
    }
}
