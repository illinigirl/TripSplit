//
//  Models.swift
//  TripSplitApp
//
//  Created by Megan Schott on 1/19/26.
//

import SwiftData
import Foundation

@Model
class Trip: Identifiable {
    var name: String
    var startDate: Date
    var endDate: Date?
    @Relationship(deleteRule: .cascade) var participants: [Person] = []
    @Relationship(deleteRule: .cascade) var expenses: [Expense] = []
    @Relationship(deleteRule: .cascade) var paymentRecords: [PaymentRecord] = []
    
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
class Person: Identifiable {
    var name: String
    var color: String
    var trip: Trip?
    @Relationship(deleteRule: .cascade) var lineItems: [LineItem] = []
    @Relationship(deleteRule: .nullify) var sharedItems: [SharedItem] = []  // ADD THIS LINE
    
    init(name: String, color: String = "blue") {
        self.name = name
        self.color = color
    }
    
    // Get total of individual line items for a specific expense
    func lineItemTotal(for expense: Expense) -> Double {
        lineItems.filter { $0.expense == expense }.reduce(0) { $0 + $1.amount }
    }
    
    // Get share of shared items for a specific expense
    func sharedItemTotal(for expense: Expense) -> Double {
        return expense.sharedItems
            .filter { $0.sharedBy.contains(where: { $0.id == self.id }) }
            .reduce(0) { $0 + $1.amountPerPerson }
    }
    
    func totalPaid(in trip: Trip) -> Double {
        trip.expenses.filter { $0.paidBy == self }.reduce(0) { $0 + $1.amount }
    }
    
    func totalOwed(in trip: Trip) -> Double {
        trip.expenses.reduce(0) { total, expense in
            // For expenses with line items or shared items, calculate from those
            let lineItemTotal = lineItemTotal(for: expense)
            let sharedTotal = sharedItemTotal(for: expense)
            
            // For other split types, use the existing ExpenseShare
            if let share = expense.shares.first(where: { $0.person == self }) {
                // If this is an itemized expense, the share already includes everything
                // Otherwise just use the share amount
                if lineItemTotal > 0 || sharedTotal > 0 {
                    return total + share.amount
                } else {
                    return total + share.amount
                }
            }
            
            return total + lineItemTotal + sharedTotal
        }
    }
    
    func netBalance(in trip: Trip) -> Double {
        totalPaid(in: trip) - totalOwed(in: trip)
    }
}

@Model
class Expense: Identifiable {
    var amount: Double
    var expenseDescription: String
    var date: Date
    var category: String
    var paidBy: Person?
    @Relationship(deleteRule: .cascade, inverse: \ExpenseShare.expense) var shares: [ExpenseShare] = []
    @Relationship(deleteRule: .cascade) var sharedItems: [SharedItem] = []
    var trip: Trip?
    var receiptImageData: Data?  // NEW - stores the receipt image
    
    init(amount: Double, description: String, date: Date = Date(), category: String = "other", paidBy: Person? = nil) {
        self.amount = amount
        self.expenseDescription = description
        self.date = date
        self.category = category
        self.paidBy = paidBy
    }
    
    func getParticipants(from trip: Trip) -> [Person] {
        return shares.compactMap { $0.person }
    }
    
    var participantCount: Int {
        shares.count
    }
    
    func getShare(for person: Person) -> Double? {
        return shares.first(where: { $0.person == person })?.amount
    }
}

@Model
class ExpenseShare: Identifiable {
    var person: Person?
    var amount: Double
    var expense: Expense?
    
    init(person: Person, amount: Double) {
        self.person = person
        self.amount = amount
    }
}

@Model
class LineItem: Identifiable {
    var name: String
    var amount: Double
    var person: Person?
    var expense: Expense?
    
    init(name: String, amount: Double) {
        self.name = name
        self.amount = amount
    }
}

@Model
class SharedItem: Identifiable {
    var name: String
    var amount: Double
    @Relationship(deleteRule: .nullify, inverse: \Person.sharedItems) var sharedBy: [Person] = []
    var expense: Expense?
    
    init(name: String, amount: Double) {
        self.name = name
        self.amount = amount
    }
    
    var amountPerPerson: Double {
        guard !sharedBy.isEmpty else { return 0 }
        return amount / Double(sharedBy.count)
    }
}

@Model
class Friend: Identifiable {
    var name: String
    var color: String
    var email: String?
    var phone: String?
    
    init(name: String, color: String = "blue", email: String? = nil, phone: String? = nil) {
        self.name = name
        self.color = color
        self.email = email
        self.phone = phone
    }
}

@Model
class PaymentRecord: Identifiable {
    var fromPersonName: String
    var toPersonName: String
    var amount: Double
    var date: Date
    var trip: Trip?
    
    init(fromPersonName: String, toPersonName: String, amount: Double, date: Date = Date()) {
        self.fromPersonName = fromPersonName
        self.toPersonName = toPersonName
        self.amount = amount
        self.date = date
    }
}
