//
//  ExpenseDetailView.swift
//  TripSplitApp
//
//  Created by Megan Schott on 1/19/26.
//
import SwiftUI
import SwiftData

struct ExpenseDetailView: View {
    let expense: Expense
    let trip: Trip
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            Section("Details") {
                HStack {
                    Text("Amount")
                    Spacer()
                    Text("$\(expense.amount, specifier: "%.2f")")
                        .font(.headline)
                }
                
                HStack {
                    Text("Category")
                    Spacer()
                    Text(expense.category)
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("Date")
                    Spacer()
                    Text(expense.date.formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(.secondary)
                }
            }
            
            Section("Paid By") {
                if let payer = expense.paidBy {
                    HStack {
                        Circle()
                            .fill(Color(payer.color))
                            .frame(width: 30, height: 30)
                        Text(payer.name)
                        Spacer()
                        Text("$\(expense.amount, specifier: "%.2f")")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Section("Split Between \(expense.participantCount) People") {
                ForEach(expense.getParticipants(from: trip)) { person in
                    HStack {
                        Circle()
                            .fill(Color(person.color))
                            .frame(width: 30, height: 30)
                        Text(person.name)
                        Spacer()
                        if let share = expense.participantShares["\(person.persistentModelID)"] {
                            Text("$\(share, specifier: "%.2f")")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(expense.expenseDescription)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    deleteExpense()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
    
    private func deleteExpense() {
        modelContext.delete(expense)
        if let index = trip.expenses.firstIndex(where: { $0.id == expense.id }) {
            trip.expenses.remove(at: index)
        }
        dismiss()
    }
}
