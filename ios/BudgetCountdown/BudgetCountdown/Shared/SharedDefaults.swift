import Foundation

// App Group identifier — must match what you configure in Xcode for both targets
let appGroupID = "group.com.maggie.budgetcountdown"

struct SharedDefaults {
    private static var suite: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }
    
    static var remainingBudget: Double {
        get { suite.double(forKey: "remainingBudget") }
        set { suite.set(newValue, forKey: "remainingBudget") }
    }
    
    static var totalBudget: Double {
        get {
            let v = suite.double(forKey: "totalBudget")
            return v == 0 ? 3660 : v
        }
        set { suite.set(newValue, forKey: "totalBudget") }
    }
    
    static var periodStart: String {
        get { suite.string(forKey: "periodStart") ?? "" }
        set { suite.set(newValue, forKey: "periodStart") }
    }
    
    static var periodEnd: String {
        get { suite.string(forKey: "periodEnd") ?? "" }
        set { suite.set(newValue, forKey: "periodEnd") }
    }
    
    static var lastUpdated: Date? {
        get { suite.object(forKey: "lastUpdated") as? Date }
        set { suite.set(newValue, forKey: "lastUpdated") }
    }
    
}
