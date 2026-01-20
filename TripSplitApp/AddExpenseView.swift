//
//  AddExpenseView.swift
//  TripSplitApp
//
//  Created by Megan Schott on 1/19/26.
//import SwiftUIimport SwiftUIimport SwiftUI
import SwiftUI
import SwiftData

enum SplitType: String, CaseIterable {
    case even = "Split Evenly"
    case custom = "Custom Amounts"
    case item = "By Item"
}

struct AddExpenseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let trip: Trip
    
    @State private var amount = ""
    @State private var description = ""
    @State private var category = "Food"
    @State private var selectedPayer: Person?
    @State private var selectedParticipants: Set<PersistentIdentifier> = []
    @State private var splitType: SplitType = .even
    @State private var customAmounts: [PersistentIdentifier: String] = [:]
    @State private var itemAmounts: [PersistentIdentifier: String] = [:]
    @State private var subtotal = ""
    
    let categories = ["Food", "Drinks", "Transportation", "Lodging", "Entertainment", "Miscellaneous"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Expense Details") {
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                        .onChange(of: amount) { oldValue, newValue in
                            amount = filterNumeric(newValue)
                        }
                    TextField("Description", text: $description)
                    
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                }
                
                Section("Who Paid?") {
                    ForEach(trip.participants) { person in
                        HStack {
                            Circle()
                                .fill(Color(person.color))
                                .frame(width: 25, height: 25)
                            Text(person.name)
                            Spacer()
                            if selectedPayer == person {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedPayer = person
                        }
                    }
                }
                
                Section("Split Type") {
                    Picker("How to split", selection: $splitType) {
                        ForEach(SplitType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                switch splitType {
                case .even:
                    evenSplitSection
                case .custom:
                    customAmountsSection
                case .item:
                    itemSection
                }
            }
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveExpense()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
    
    private var evenSplitSection: some View {
        Section("Split Between") {
            ForEach(trip.participants) { person in
                HStack {
                    Circle()
                        .fill(Color(person.color))
                        .frame(width: 25, height: 25)
                    Text(person.name)
                    Spacer()
                    if selectedParticipants.contains(person.persistentModelID) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
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
            
            Button("Select All") {
                selectedParticipants = Set(trip.participants.map { $0.persistentModelID })
            }
            
            if !selectedParticipants.isEmpty, let amountValue = Double(amount) {
                Text("Each person pays: $\(amountValue / Double(selectedParticipants.count), specifier: "%.2f")")
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var customAmountsSection: some View {
        Section("Custom Amounts") {
            ForEach(trip.participants) { person in
                HStack {
                    Circle()
                        .fill(Color(person.color))
                        .frame(width: 25, height: 25)
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
                }
                HStack {
                    Text("Remaining")
                    Spacer()
                    Text("$\(total - assigned, specifier: "%.2f")")
                        .foregroundStyle(abs(total - assigned) < 0.01 ? .green : .red)
                }
            }
        }
    }
    
    private var itemSection: some View {
        Section("By Item") {
            TextField("Subtotal (before tax/tip/fees)", text: $subtotal)
                .keyboardType(.decimalPad)
                .onChange(of: subtotal) { oldValue, newValue in
                    subtotal = filterNumeric(newValue)
                }
            
            ForEach(trip.participants) { person in
                HStack {
                    Circle()
                        .fill(Color(person.color))
                        .frame(width: 25, height: 25)
                    Text(person.name)
                    Spacer()
                    TextField("Item $", text: Binding(
                        get: { itemAmounts[person.persistentModelID] ?? "" },
                        set: {
                            itemAmounts[person.persistentModelID] = $0
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
            
            if let sub = Double(subtotal), sub > 0 {
                let itemTotal = itemAmounts.values.compactMap { Double($0) }.reduce(0, +)
                HStack {
                    Text("Assigned")
                    Spacer()
                    Text("$\(itemTotal, specifier: "%.2f")")
                }
                HStack {
                    Text("Remaining")
                    Spacer()
                    Text("$\(sub - itemTotal, specifier: "%.2f")")
                        .foregroundStyle(abs(sub - itemTotal) < 0.01 ? .green : .red)
                }
            }
            
            if let total = Double(amount), let sub = Double(subtotal), sub > 0 {
                ForEach(trip.participants.filter { itemAmounts[$0.persistentModelID] != nil && Double(itemAmounts[$0.persistentModelID]!) ?? 0 > 0 }) { person in
                    if let item = Double(itemAmounts[person.persistentModelID] ?? "0") {
                        let percentage = (item / sub) * 100
                        let owes = (item / sub) * total
                        HStack {
                            Text(person.name)
                            Spacer()
                            Text("\(percentage, specifier: "%.1f")% → $\(owes, specifier: "%.2f")")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
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
            guard let sub = Double(subtotal), sub > 0 else { return false }
            let itemTotal = itemAmounts.values.compactMap { Double($0) }.reduce(0, +)
            return abs(itemTotal - sub) < 0.01
        }
    }
    
    private func saveExpense() {
        guard let amountValue = Double(amount),
              let payer = selectedPayer else { return }
        
        let expense = Expense(
            amount: amountValue,
            description: description,
            category: category,
            paidBy: payer
        )
        
        expense.trip = trip
        
        // Insert expense first
        modelContext.insert(expense)
        trip.expenses.append(expense)
        
        // Create ExpenseShare objects for each participant
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
            if let sub = Double(subtotal), sub > 0 {
                for person in participantsList {
                    if let itemStr = itemAmounts[person.persistentModelID],
                       let itemAmount = Double(itemStr) {
                        let percentage = itemAmount / sub
                        let owedAmount = percentage * amountValue
                        let share = ExpenseShare(person: person, amount: owedAmount)
                        share.expense = expense
                        expense.shares.append(share)
                        modelContext.insert(share)
                    }
                }
            }
        }
        
        try? modelContext.save()
        
        dismiss()
    }
}
