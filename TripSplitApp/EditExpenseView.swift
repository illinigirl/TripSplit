//
//  EditExpenseView.swift
//  TripSplitApp
//
//  Created by Megan Schott on 1/19/26.
//
import SwiftUI
import SwiftData

struct EditExpenseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let trip: Trip
    let expense: Expense
    
    @State private var amount: String
    @State private var description: String
    @State private var category: String
    @State private var selectedPayer: Person?
    @State private var selectedParticipants: Set<PersistentIdentifier> = []
    @State private var splitType: SplitType = .even
    @State private var customAmounts: [PersistentIdentifier: String] = [:]
    
    let categories = ["Food", "Drinks", "Transportation", "Lodging", "Entertainment", "Miscellaneous"]
    
    // Check if this is an itemized expense
    private var isItemizedExpense: Bool {
        let hasLineItems = trip.participants.contains { person in
            !person.lineItems.filter { $0.expense == expense }.isEmpty
        }
        let hasSharedItems = !expense.sharedItems.isEmpty
        return hasLineItems || hasSharedItems
    }
    
    init(trip: Trip, expense: Expense) {
        self.trip = trip
        self.expense = expense
        
        // Pre-populate fields
        _amount = State(initialValue: String(expense.amount))
        _description = State(initialValue: expense.expenseDescription)
        _category = State(initialValue: expense.category)
        _selectedPayer = State(initialValue: expense.paidBy)
        
        // Determine split type and populate accordingly
        let participants = expense.getParticipants(from: trip)
        let participantIDs = Set(participants.map { $0.persistentModelID })
        _selectedParticipants = State(initialValue: participantIDs)
        
        // Check if it's an even split
        let shares = expense.shares
        let amounts = shares.map { $0.amount }
        let isEven = amounts.allSatisfy { abs($0 - amounts[0]) < 0.01 }
        
        if isEven {
            _splitType = State(initialValue: .even)
        } else {
            // Treat non-even as custom
            _splitType = State(initialValue: .custom)
            var customAmts: [PersistentIdentifier: String] = [:]
            for participant in participants {
                if let share = expense.getShare(for: participant) {
                    customAmts[participant.persistentModelID] = String(format: "%.2f", share)
                }
            }
            _customAmounts = State(initialValue: customAmts)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Gradient background
                LinearGradient(
                    colors: [Color.sunsetOrange.opacity(0.35), Color.oceanBlue.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                if isItemizedExpense {
                    // Show message for itemized expenses
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.sunsetOrange)
                        
                        Text("Itemized Expenses Cannot Be Edited")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                        
                        Text("This expense was split by individual items. Editing itemized expenses is not currently supported.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Text("You can delete this expense and create a new one if needed.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                } else {
                    Form {
                        Section("Expense Details") {
                            HStack {
                                Image(systemName: "dollarsign.circle.fill")
                                    .foregroundStyle(Color.oceanBlue)
                                TextField("Amount", text: $amount)
                                    .keyboardType(.decimalPad)
                                    .onChange(of: amount) { oldValue, newValue in
                                        amount = filterNumeric(newValue)
                                    }
                            }
                            
                            HStack {
                                Image(systemName: "text.alignleft")
                                    .foregroundStyle(Color.sunsetOrange)
                                TextField("Description", text: $description)
                            }
                            
                            HStack {
                                Image(systemName: categoryIcon(for: category))
                                    .foregroundStyle(Color.oceanTeal)
                                Picker("Category", selection: $category) {
                                    ForEach(categories, id: \.self) { category in
                                        Text(category).tag(category)
                                    }
                                }
                            }
                        }
                        .listRowBackground(Color.cardBackground)
                        
                        Section("Who Paid?") {
                            ForEach(trip.participants) { person in
                                HStack {
                                    Circle()
                                        .fill(Color.participantColors[person.color] ?? .blue)
                                        .frame(width: 30, height: 30)
                                    Text(person.name)
                                    Spacer()
                                    if selectedPayer == person {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.oceanBlue)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedPayer = person
                                }
                            }
                        }
                        .listRowBackground(Color.cardBackground)
                        
                        Section("Split Type") {
                            Picker("How to split", selection: $splitType) {
                                ForEach(SplitType.allCases.filter { $0 != .item }, id: \.self) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .listRowBackground(Color.cardBackground)
                        
                        switch splitType {
                        case .even:
                            evenSplitSection
                        case .custom:
                            customAmountsSection
                        case .item:
                            EmptyView()
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Edit Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.moneyOwed)
                }
                if !isItemizedExpense {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            saveExpense()
                        }
                        .foregroundStyle(Color.oceanBlue)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                    }
                }
            }
        }
    }
    
    private var evenSplitSection: some View {
        Section("Split Between") {
            ForEach(trip.participants) { person in
                HStack {
                    Circle()
                        .fill(Color.participantColors[person.color] ?? .blue)
                        .frame(width: 30, height: 30)
                    Text(person.name)
                    Spacer()
                    if selectedParticipants.contains(person.persistentModelID) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.oceanBlue)
                    } else {
                        Image(systemName: "circle")
                            .foregroundStyle(.gray)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if selectedParticipants.contains(person.persistentModelID) {
                        selectedParticipants.remove(person.persistentModelID)
                    } else {
                        selectedParticipants.insert(person.persistentModelID)
                    }
                }
            }
            
            Button {
                selectedParticipants = Set(trip.participants.map { $0.persistentModelID })
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.oceanBlue)
                    Text("Select All")
                        .foregroundStyle(Color.oceanBlue)
                }
            }
            
            if !selectedParticipants.isEmpty, let amountValue = Double(amount) {
                HStack {
                    Image(systemName: "equal.circle.fill")
                        .foregroundStyle(Color.sunsetOrange)
                    Text("Each person pays:")
                    Spacer()
                    Text("$\(amountValue / Double(selectedParticipants.count), specifier: "%.2f")")
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.oceanBlue)
                }
                .foregroundStyle(.secondary)
            }
        }
        .listRowBackground(Color.cardBackground)
    }
    
    private var customAmountsSection: some View {
        Section("Custom Amounts") {
            ForEach(trip.participants) { person in
                HStack {
                    Circle()
                        .fill(Color.participantColors[person.color] ?? .blue)
                        .frame(width: 30, height: 30)
                    Text(person.name)
                    Spacer()
                    TextField("$0.00", text: Binding(
                        get: { customAmounts[person.persistentModelID] ?? "" },
                        set: {
                            customAmounts[person.persistentModelID] = $0
                            if Double($0) ?? 0 > 0 {
                                selectedParticipants.insert(person.persistentModelID)
                            } else {
                                selectedParticipants.remove(person.persistentModelID)
                            }
                        }
                    ))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                }
            }
            
            if let total = Double(amount) {
                let assigned = customAmounts.values.compactMap { Double($0) }.reduce(0, +)
                HStack {
                    Text("Assigned")
                    Spacer()
                    Text("$\(assigned, specifier: "%.2f")")
                        .fontWeight(.semibold)
                }
                HStack {
                    Text("Remaining")
                    Spacer()
                    Text("$\(total - assigned, specifier: "%.2f")")
                        .fontWeight(.semibold)
                        .foregroundStyle(abs(total - assigned) < 0.01 ? Color.moneyOwing : Color.moneyOwed)
                }
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
    
    private func filterNumeric(_ value: String) -> String {
        let filtered = value.filter { "0123456789.".contains($0) }
        let parts = filtered.split(separator: ".")
        if parts.count > 2 {
            return String(parts[0]) + "." + parts[1...].joined()
        }
        return filtered
    }
    
    private var canSave: Bool {
        guard let amountValue = Double(amount), amountValue > 0 else { return false }
        guard !description.isEmpty else { return false }
        guard selectedPayer != nil else { return false }
        guard !selectedParticipants.isEmpty else { return false }
        
        switch splitType {
        case .even:
            return true
        case .custom:
            let assigned = customAmounts.values.compactMap { Double($0) }.reduce(0, +)
            return abs(assigned - amountValue) < 0.01
        case .item:
            return false
        }
    }
    
    private func saveExpense() {
        guard let amountValue = Double(amount),
              let payer = selectedPayer else { return }
        
        // Update existing expense
        expense.amount = amountValue
        expense.expenseDescription = description
        expense.category = category
        expense.paidBy = payer
        expense.date = Date()
        
        // Delete old shares
        for share in expense.shares {
            modelContext.delete(share)
        }
        expense.shares.removeAll()
        
        // Create new shares
        let participantsList = trip.participants.filter { selectedParticipants.contains($0.persistentModelID) }
        
        switch splitType {
        case .even:
            let shareAmount = amountValue / Double(selectedParticipants.count)
            for person in participantsList {
                let share = ExpenseShare(person: person, amount: shareAmount)
                share.expense = expense
                expense.shares.append(share)
                modelContext.insert(share)
            }
            
        case .custom:
            for person in participantsList {
                if let amountStr = customAmounts[person.persistentModelID],
                   let customAmount = Double(amountStr) {
                    let share = ExpenseShare(person: person, amount: customAmount)
                    share.expense = expense
                    expense.shares.append(share)
                    modelContext.insert(share)
                }
            }
            
        case .item:
            break // Not supported
        }
        
        try? modelContext.save()
        
        dismiss()
    }
}
