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
    @State private var showingFullReceipt = false
    
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
                
                // Receipt section
                if let imageData = expense.receiptImageData,
                   let image = UIImage(data: imageData) {
                    Section("Receipt") {
                        Button(action: {
                            showingFullReceipt = true
                        }) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    .listRowBackground(Color.cardBackground)
                }
                
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
        .sheet(isPresented: $showingFullReceipt) {
            if let imageData = expense.receiptImageData,
               let image = UIImage(data: imageData) {
                FullScreenImageView(image: image)
            }
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
            // Shared Items - force load the relationship
            // Shared Items - force load the relationship
            // Shared Items - force load the relationship
            if !expense.sharedItems.isEmpty {
                Section("Shared Items") {
                    ForEach(expense.sharedItems) { sharedItem in
                        let sharedByPeople = sharedItem.sharedBy // Force load
                        let sharedByCount = sharedByPeople.count
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(sharedItem.name)
                                    .font(.headline)
                                Spacer()
                                Text("$\(sharedItem.amount, specifier: "%.2f")")
                                    .font(.headline)
                            }
                            
                            // DEBUG INFO
                            Text("DEBUG: Count = \(sharedByCount)")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                            
                            if sharedByCount > 0 {
                                Text("Split between \(sharedByCount): \(sharedByPeople.map { $0.name }.joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("$\(sharedItem.amountPerPerson, specifier: "%.2f") each")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Count is 0 - relationship not saved")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listRowBackground(Color.cardBackground)
            }
                   
            
            // Individual Items by Person
            // Individual Items by Person
            Section("Individual Items") {
                ForEach(trip.participants) { person in
                    // Check if person has any items OR shared items
                    let lineItems = person.lineItems.filter { $0.expense == expense }
                    let hasLineItems = !lineItems.isEmpty
                    let relevantSharedItems = expense.sharedItems.filter { sharedItem in
                        sharedItem.sharedBy.contains(where: { $0.id == person.id })
                    }
                    let hasSharedItems = !relevantSharedItems.isEmpty
                    
                    if hasLineItems || hasSharedItems {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Circle()
                                    .fill(Color.participantColors[person.color] ?? .blue)
                                    .frame(width: 30, height: 30)
                                Text(person.name)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            
                            // Show individual items if they exist
                            if hasLineItems {
                                ForEach(lineItems) { item in
                                    HStack {
                                        Text("• \(item.name)")
                                            .font(.subheadline)
                                        Spacer()
                                        Text("$\(item.amount, specifier: "%.2f")")
                                            .font(.subheadline)
                                    }
                                    .foregroundStyle(.secondary)
                                }
                                
                                let lineItemTotal = lineItems.reduce(0) { $0 + $1.amount }
                                
                                HStack {
                                    Text("Subtotal")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text("$\(lineItemTotal, specifier: "%.2f")")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                            }
                            
                            // Show shared items portion
                            if hasSharedItems {
                                let sharedTotal = relevantSharedItems.reduce(0) { $0 + $1.amountPerPerson }
                                
                                HStack {
                                    Text(hasLineItems ? "+ Share of shared items" : "Share of shared items")
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
            }
            .listRowBackground(Color.cardBackground)
            
            // Summary with Tax/Tip breakdown
            Section("Breakdown") {
                let itemsSubtotal = trip.participants.reduce(0.0) { total, person in
                    total + person.lineItems.filter { $0.expense == expense }.reduce(0) { $0 + $1.amount }
                }
                let sharedSubtotal = expense.sharedItems.reduce(0) { $0 + $1.amount }
                let subtotal = itemsSubtotal + sharedSubtotal
                let taxTipFees = expense.amount - subtotal
                
                HStack {
                    Text("Items Subtotal")
                    Spacer()
                    Text("$\(subtotal, specifier: "%.2f")")
                }
                
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.sunsetOrange)
                        .font(.caption)
                    Text("Tax + Tip + Fees")
                    Spacer()
                    Text("$\(taxTipFees, specifier: "%.2f")")
                        .foregroundStyle(taxTipFees >= 0 ? Color.oceanTeal : Color.moneyOwed)
                }
                
                Divider()
                
                HStack {
                    Text("Total")
                        .fontWeight(.semibold)
                    Spacer()
                    Text("$\(expense.amount, specifier: "%.2f")")
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.oceanBlue)
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

// MARK: - Full Screen Image View
struct FullScreenImageView: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = lastScale * value
                            }
                            .onEnded { _ in
                                lastScale = scale
                                if scale < 1.0 {
                                    withAnimation {
                                        scale = 1.0
                                        lastScale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                    }
                                }
                            }
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }
}
