//
//  Models.swift
//  TripSplitApp
//
//  Created by Megan Schott on 1/19/26.
//

import SwiftData
import Foundation

@Model
class Trip {
    var name: String
    var startDate: Date
    var endDate: Date?
    @Relationship(deleteRule: .cascade) var participants: [Person] = []
    @Relationship(deleteRule: .cascade) var expenses: [Expense] = []
    
    init(name: String, startDate: Date, endDate: Date? = nil) {
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
    }
    
    var totalSpent: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }
}

@Model
class Person {
    var name: String
    var color: String
    var trip: Trip?
    
    init(name: String, color: String = "blue") {
        self.name = name
        self.color = color
    }
    
    func totalPaid(in trip: Trip) -> Double {
        trip.expenses.filter { $0.paidBy == self }.reduce(0) { $0 + $1.amount }
    }
    
    func totalOwed(in trip: Trip) -> Double {
        trip.expenses.filter { $0.participants.contains(self) }
            .reduce(0) { $0 + ($1.amount / Double($1.participants.count)) }
    }
    
    func netBalance(in trip: Trip) -> Double {
        totalPaid(in: trip) - totalOwed(in: trip)
    }
}

@Model
class Expense {
    var amount: Double
    var expenseDescription: String
    var date: Date
    var category: String
    var paidBy: Person?
    @Relationship var participants: [Person] = []
    var trip: Trip?
    
    init(amount: Double, description: String, date: Date = Date(), category: String = "other", paidBy: Person? = nil) {
        self.amount = amount
        self.expenseDescription = description
        self.date = date
        self.category = category
        self.paidBy = paidBy
    }
}
