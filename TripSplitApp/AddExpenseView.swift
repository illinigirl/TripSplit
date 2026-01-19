//
//  AddExpenseView.swift
//  TripSplitApp
//
//  Created by Megan Schott on 1/19/26.
//
import SwiftUI
import SwiftData

enum SplitType: String, CaseIterable {
    case even = "Split Evenly"
    case custom = "Custom Amounts"
    case entree = "By Entree"
}

struct AddExpenseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let trip: Trip
    
    @State private var amount = ""
    @State private var description = ""
    @State private var category = "Food"
    @State private var selectedPayer: Person?
    @State private var selectedParticipants: Set<Person> = []
    @State private var splitType: SplitType = .even
    @State private var customAmounts: [Person: String] = [:]
    @State private var entreeAmounts: [Person: String] = [:]
    @State private var subtotal = ""
    
    let categories = ["Food", "Drinks", "Transportation", "Lodging", "Entertainment", "Miscellaneous"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Expense Details") {
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
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
                case .entree:
                    entreeSection
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
                    if selectedParticipants.contains(person) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                    } else {
                        Image(systemName: "circle")
                            .foregroundStyle(.gray)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if selectedParticipants.contains(person) {
                        selectedParticipants.remove(person)
                    } else {
                        selectedParticipants.insert(person)
                    }
                }
            }
            
            Button("Select All") {
                selectedParticipants = Set(trip.participants)
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
                        get: { customAmounts[person] ?? "" },
                        set: {
                            customAmounts[person] = $0
                            if Double($0) ?? 0 > 0 {
                                selectedParticipants.insert(person)
                            } else {
                                selectedParticipants.remove(person)
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
    
    private var entreeSection: some View {
        Section("By Entree") {
            TextField("Subtotal (before tax/tip)", text: $subtotal)
                .keyboardType(.decimalPad)
            
            ForEach(trip.participants) { person in
                HStack {
                    Circle()
                        .fill(Color(person.color))
                        .frame(width: 25, height: 25)
                    Text(person.name)
                    Spacer()
                    TextField("Entree $", text: Binding(
                        get: { entreeAmounts[person] ?? "" },
                        set: {
                            entreeAmounts[person] = $0
                            if Double($0) ?? 0 > 0 {
                                selectedParticipants.insert(person)
                            } else {
                                selectedParticipants.remove(person)
                            }
                        }
                    ))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                }
            }
            
            if let sub = Double(subtotal), sub > 0 {
                let entreeTotal = entreeAmounts.values.compactMap { Double($0) }.reduce(0, +)
                HStack {
                    Text("Assigned")
                    Spacer()
                    Text("$\(entreeTotal, specifier: "%.2f")")
                }
                HStack {
                    Text("Remaining")
                    Spacer()
                    Text("$\(sub - entreeTotal, specifier: "%.2f")")
                        .foregroundStyle(abs(sub - entreeTotal) < 0.01 ? .green : .red)
                }
            }
            
            if let total = Double(amount), let sub = Double(subtotal), sub > 0 {
                ForEach(trip.participants.filter { entreeAmounts[$0] != nil && Double(entreeAmounts[$0]!) ?? 0 > 0 }) { person in
                    if let entree = Double(entreeAmounts[person] ?? "0") {
                        let percentage = (entree / sub) * 100
                        let owes = (entree / sub) * total
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
        case .entree:
            guard let sub = Double(subtotal), sub > 0 else { return false }
            let entreeTotal = entreeAmounts.values.compactMap { Double($0) }.reduce(0, +)
            return abs(entreeTotal - sub) < 0.01
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
        expense.participants = Array(selectedParticipants)
        
        modelContext.insert(expense)
        trip.expenses.append(expense)
        
        dismiss()
    }
}
