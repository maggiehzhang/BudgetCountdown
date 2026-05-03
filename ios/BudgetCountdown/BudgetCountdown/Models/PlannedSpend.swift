import Foundation
import SwiftData

@Model
final class PlannedSpend {
    var id: UUID
    var name: String
    var amount: Double
    var createdAt: Date

    init(name: String, amount: Double) {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.createdAt = Date()
    }
}
