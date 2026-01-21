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
                
                // Show itemized breakdown if it exists
                if hasItemizedSplit {
                    itemizedBreakdownSection
                } else {
                    standardSplitSection
                }
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
    
    private var hasItemizedSplit: Bool {
        // Check if this expense has line items or shared items
        let hasLineItems = trip.participants.contains { person in
            !person.lineItems.filter { $0.expense == expense }.isEmpty
        }
        let hasSharedItems = !expense.sharedItems.isEmpty
        return hasLineItems || hasSharedItems
    }
    
    private var itemizedBreakdownSection: some View {
        Group {
      
            // Shared Items
            if !expense.sharedItems.isEmpty {
                Section("Shared Items") {
                    ForEach(expense.sharedItems) { sharedItem in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(sharedItem.name)
                                    .font(.headline)
                                Spacer()
                                Text("$\(sharedItem.amount, specifier: "%.2f")")
                                    .font(.headline)
                            }
                            Text("Split between \(sharedItem.sharedBy.count): \(sharedItem.sharedBy.map { $0.name }.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("$\(sharedItem.amountPerPerson, specifier: "%.2f") each")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listRowBackground(Color.cardBackground)
            }
                            
                    
            // Individual Items by Person
            Section("Individual Items") {
                ForEach(trip.participants.filter { person in
                    !person.lineItems.filter { $0.expense == expense }.isEmpty
                }) { person in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Circle()
                                .fill(Color.participantColors[person.color] ?? .blue)
                                .frame(width: 30, height: 30)
                            Text(person.name)
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        
                        ForEach(person.lineItems.filter { $0.expense == expense }) { item in
                            HStack {
                                Text("• \(item.name)")
                                    .font(.subheadline)
                                Spacer()
                                Text("$\(item.amount, specifier: "%.2f")")
                                    .font(.subheadline)
                            }
                            .foregroundStyle(.secondary)
                        }
                        
                        // Person's subtotal including their share of shared items
                        let lineItemTotal = person.lineItems.filter { $0.expense == expense }.reduce(0) { $0 + $1.amount }
                        let sharedTotal = expense.sharedItems
                            .filter { $0.sharedBy.contains(where: { $0.id == person.id }) }
                            .reduce(0) { $0 + $1.amountPerPerson }
                        
                        HStack {
                            Text("Subtotal")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Text("$\(lineItemTotal, specifier: "%.2f")")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        if sharedTotal > 0 {
                            HStack {
                                Text("+ Share of shared items")
                                    .font(.caption)
                                Spacer()
                                Text("$\(sharedTotal, specifier: "%.2f")")
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listRowBackground(Color.cardBackground)
            
            // Final totals
            Section("Final Split") {
                ForEach(expense.getParticipants(from: trip)) { person in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.participantColors[person.color] ?? .blue)
                            .frame(width: 35, height: 35)
                        Text(person.name)
                            .font(.headline)
                        Spacer()
                        if let share = expense.getShare(for: person) {
                            Text("$\(share, specifier: "%.2f")")
                                .font(.headline)
                                .foregroundStyle(Color.oceanBlue)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listRowBackground(Color.cardBackground)
        }
    }
    
    private var standardSplitSection: some View {
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
