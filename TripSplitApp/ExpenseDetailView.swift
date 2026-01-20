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
    @State private var showingEditExpense = false
    
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [Color.sunsetOrange.opacity(0.35), Color.oceanBlue.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            List {
                Section("Details") {
                    HStack {
                        Image(systemName: "dollarsign.circle.fill")
                            .foregroundStyle(Color.oceanBlue)
                        Text("Amount")
                        Spacer()
                        Text("$\(expense.amount, specifier: "%.2f")")
                            .font(.headline)
                            .foregroundStyle(Color.oceanBlue)
                    }
                    
                    HStack {
                        Image(systemName: categoryIcon(for: expense.category))
                            .foregroundStyle(Color.sunsetOrange)
                        Text("Category")
                        Spacer()
                        Text(expense.category)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(Color.oceanTeal)
                        Text("Date")
                        Spacer()
                        Text(expense.date.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(Color.cardBackground)
                
                Section("Paid By") {
                    if let payer = expense.paidBy {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.participantColors[payer.color] ?? .blue)
                                .frame(width: 40, height: 40)
                            Text(payer.name)
                                .font(.headline)
                            Spacer()
                            Text("$\(expense.amount, specifier: "%.2f")")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listRowBackground(Color.cardBackground)
                
                Section("Split Between \(expense.participantCount) People") {
                    ForEach(expense.getParticipants(from: trip)) { person in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.participantColors[person.color] ?? .blue)
                                .frame(width: 35, height: 35)
                            Text(person.name)
                                .font(.headline)
                            Spacer()
                            if let share = expense.getShare(for: person) {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("$\(share, specifier: "%.2f")")
                                        .font(.headline)
                                    if share != expense.amount / Double(expense.participantCount) {
                                        Text("custom split")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listRowBackground(Color.cardBackground)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(expense.expenseDescription)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingEditExpense = true
                } label: {
                    Text("Edit")
                        .foregroundStyle(Color.oceanBlue)
                        .fontWeight(.semibold)
                }
            }
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    deleteExpense()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(Color.moneyOwed)
                }
            }
        }
        .sheet(isPresented: $showingEditExpense) {
            EditExpenseView(trip: trip, expense: expense)
        }
    }
    
    private func categoryIcon(for category: String) -> String {
        switch category {
        case "Food": return "fork.knife"
        case "Drinks": return "wineglass"
        case "Transportation": return "car.fill"
        case "Lodging": return "bed.double.fill"
        case "Entertainment": return "theatermasks.fill"
        default: return "tag.fill"
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
