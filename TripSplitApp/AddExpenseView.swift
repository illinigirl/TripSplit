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
    
    // Line items per person
    @State private var personLineItems: [PersistentIdentifier: [TempLineItem]] = [:]
    @State private var sharedItems: [TempSharedItem] = []
    
    // For adding items - using ID instead of Person object
    @State private var selectedPersonID: PersistentIdentifier?
    @State private var showingAddSharedItemSheet = false
    
    let categories = ["Food", "Drinks", "Transportation", "Lodging", "Entertainment", "Miscellaneous"]
    
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
                    .listRowBackground(Color.cardBackground)
                    
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
                    .listRowBackground(Color.cardBackground)
                    
                    Section("Split Type") {
                        Picker("How to split", selection: $splitType) {
                            ForEach(SplitType.allCases, id: \.self) { type in
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
                        itemSection
                    }
                }
                .scrollContentBackground(.hidden)
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
            .sheet(item: $selectedPersonID) { personID in
                if let person = trip.participants.first(where: { $0.persistentModelID == personID }) {
                    AddLineItemSheet(personName: person.name, personColor: person.color) { item in
                        addLineItem(item, forPersonID: personID)
                    }
                }
            }
            .sheet(isPresented: $showingAddSharedItemSheet) {
                AddSharedItemSheet(participants: trip.participants) { item in
                    sharedItems.append(item)
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
                    .font(.subheadline)
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
        .listRowBackground(Color.cardBackground)
    }
    
    private var itemSection: some View {
        Group {
            sharedItemsSection
            individualItemsSection
            summarySection
            finalAmountsSection
        }
    }
    
    private var sharedItemsSection: some View {
        Section {
            Button(action: {
                showingAddSharedItemSheet = true
            }) {
                Label("Add Shared Item", systemImage: "plus.circle.fill")
            }
            
            ForEach(sharedItems) { item in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.name)
                        Spacer()
                        Text("$\(item.amount, specifier: "%.2f")")
                            .fontWeight(.medium)
                    }
                    Text("Split between: \(item.sharedByNames.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("$\(item.amountPerPerson, specifier: "%.2f") each")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onDelete { indexSet in
                sharedItems.remove(atOffsets: indexSet)
            }
        } header: {
            Text("Shared Items (Appetizers, etc.)")
        }
        .listRowBackground(Color.cardBackground)
    }
    
    private var individualItemsSection: some View {
        Section {
            ForEach(trip.participants) { person in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle()
                            .fill(Color(person.color))
                            .frame(width: 25, height: 25)
                        Text(person.name)
                            .fontWeight(.medium)
                        Spacer()
                        Button(action: {
                            selectedPersonID = person.persistentModelID
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                    
                    if let items = personLineItems[person.persistentModelID], !items.isEmpty {
                        ForEach(items) { item in
                            HStack {
                                Text("• \(item.name)")
                                    .font(.subheadline)
                                Spacer()
                                Text("$\(item.amount, specifier: "%.2f")")
                                    .font(.subheadline)
                            }
                            .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Text("Subtotal")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Text("$\(personSubtotal(for: person), specifier: "%.2f")")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Individual Items")
        }
        .listRowBackground(Color.cardBackground)
    }
    
    private var summarySection: some View {
        Section {
            HStack {
                Text("Individual Items")
                Spacer()
                Text("$\(calculateItemsSubtotal(), specifier: "%.2f")")
            }
            
            HStack {
                Text("Shared Items")
                Spacer()
                Text("$\(sharedItems.reduce(0) { $0 + $1.amount }, specifier: "%.2f")")
            }
            
            HStack {
                Text("Subtotal")
                    .fontWeight(.semibold)
                Spacer()
                Text("$\(calculateItemsSubtotal() + sharedItems.reduce(0) { $0 + $1.amount }, specifier: "%.2f")")
                    .fontWeight(.semibold)
            }
            
            if let total = Double(amount) {
                let grandSubtotal = calculateItemsSubtotal() + sharedItems.reduce(0) { $0 + $1.amount }
                if grandSubtotal > 0 {
                    let taxTipFees = total - grandSubtotal
                    HStack {
                        Text("Tax/Tip/Fees")
                        Spacer()
                        Text("$\(taxTipFees, specifier: "%.2f")")
                            .foregroundStyle(taxTipFees >= 0 ? Color.primary : Color.red)
                    }
                }
            }
        } header: {
            Text("Summary")
        }
        .listRowBackground(Color.cardBackground)
    }
    
    private var finalAmountsSection: some View {
        Group {
            if let total = Double(amount) {
                Section {
                    ForEach(trip.participants) { person in
                        if let finalAmount = calculateFinalAmount(for: person, total: total) {
                            HStack {
                                Circle()
                                    .fill(Color(person.color))
                                    .frame(width: 20, height: 20)
                                Text(person.name)
                                Spacer()
                                Text("$\(finalAmount, specifier: "%.2f")")
                                    .fontWeight(.medium)
                            }
                        }
                    }
                } header: {
                    Text("Each Person Owes")
                }
                .listRowBackground(Color.cardBackground)
            }
        }
    }
    
    private func addLineItem(_ item: TempLineItem, forPersonID personID: PersistentIdentifier) {
        if personLineItems[personID] == nil {
            personLineItems[personID] = []
        }
        personLineItems[personID]?.append(item)
        selectedParticipants.insert(personID)
    }
    
    private func personSubtotal(for person: Person) -> Double {
        personLineItems[person.persistentModelID]?.reduce(0) { $0 + $1.amount } ?? 0
    }
    
    private func calculateItemsSubtotal() -> Double {
        personLineItems.values.reduce(0) { total, items in
            total + items.reduce(0) { $0 + $1.amount }
        }
    }
    
    private func calculateFinalAmount(for person: Person, total: Double) -> Double? {
        let itemsSubtotal = personSubtotal(for: person)
        
        let personSharedTotal = sharedItems
            .filter { $0.sharedByIDs.contains(person.persistentModelID) }
            .reduce(0) { $0 + $1.amountPerPerson }
        
        let personSubtotal = itemsSubtotal + personSharedTotal
        
        // If person has no items at all, they don't owe anything
        guard personSubtotal > 0 else { return nil }
        
        // Calculate grand subtotal (all items + all shared)
        let grandSubtotal = calculateItemsSubtotal() + sharedItems.reduce(0) { $0 + $1.amount }
        
        guard grandSubtotal > 0 else { return nil }
        
        // Apply person's percentage to the total (including tax/tip)
        let percentage = personSubtotal / grandSubtotal
        return percentage * total
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
            let hasItems = !personLineItems.isEmpty || !sharedItems.isEmpty
            return hasItems
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
        modelContext.insert(expense)
        trip.expenses.append(expense)
        
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
            for person in trip.participants {
                if let items = personLineItems[person.persistentModelID] {
                    for tempItem in items {
                        let lineItem = LineItem(name: tempItem.name, amount: tempItem.amount)
                        lineItem.person = person
                        lineItem.expense = expense
                        person.lineItems.append(lineItem)
                        modelContext.insert(lineItem)
                    }
                }
            }
            
            for tempShared in sharedItems {
                let sharedItem = SharedItem(name: tempShared.name, amount: tempShared.amount)
                modelContext.insert(sharedItem)
                sharedItem.expense = expense
                
                for personID in tempShared.sharedByIDs {
                    if let person = trip.participants.first(where: { $0.persistentModelID == personID }) {
                        sharedItem.sharedBy.append(person)
                    }
                }
                
                expense.sharedItems.append(sharedItem)
            }
            
            for person in trip.participants {
                if let finalAmount = calculateFinalAmount(for: person, total: amountValue) {
                    let share = ExpenseShare(person: person, amount: finalAmount)
                    share.expense = expense
                    expense.shares.append(share)
                    modelContext.insert(share)
                }
            }
        }
        
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Temporary Models for UI
struct TempLineItem: Identifiable {
    let id = UUID()
    var name: String
    var amount: Double
}

struct TempSharedItem: Identifiable {
    let id = UUID()
    var name: String
    var amount: Double
    var sharedByIDs: [PersistentIdentifier]
    var sharedByNames: [String]
    
    var amountPerPerson: Double {
        guard !sharedByIDs.isEmpty else { return 0 }
        return amount / Double(sharedByIDs.count)
    }
}

// MARK: - Add Line Item Sheet
struct AddLineItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    let personName: String
    let personColor: String
    let onSave: (TempLineItem) -> Void
    
    @State private var itemName = ""
    @State private var itemAmount = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Circle()
                            .fill(Color(personColor))
                            .frame(width: 30, height: 30)
                        Text(personName)
                            .font(.headline)
                    }
                }
                
                Section("Item Details") {
                    TextField("Item name (optional)", text: $itemName)
                    TextField("Amount", text: $itemAmount)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let amount = Double(itemAmount) {
                            let finalName = itemName.isEmpty ? "Item" : itemName
                            onSave(TempLineItem(name: finalName, amount: amount))
                            dismiss()
                        }
                    }
                    .disabled(Double(itemAmount) == nil)
                }
            }
        }
    }
}

// MARK: - Add Shared Item Sheet
struct AddSharedItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    let participants: [Person]
    let onSave: (TempSharedItem) -> Void
    
    @State private var itemName = ""
    @State private var itemAmount = ""
    @State private var selectedPeople: Set<PersistentIdentifier> = []
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Item Details") {
                    TextField("Item name (optional)", text: $itemName)
                    TextField("Total amount", text: $itemAmount)
                        .keyboardType(.decimalPad)
                }
                
                Section("Split Between") {
                    ForEach(participants) { person in
                        HStack {
                            Circle()
                                .fill(Color(person.color))
                                .frame(width: 25, height: 25)
                            Text(person.name)
                            Spacer()
                            if selectedPeople.contains(person.persistentModelID) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(.gray)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedPeople.contains(person.persistentModelID) {
                                selectedPeople.remove(person.persistentModelID)
                            } else {
                                selectedPeople.insert(person.persistentModelID)
                            }
                        }
                    }
                    
                    Button("Select All") {
                        selectedPeople = Set(participants.map { $0.persistentModelID })
                    }
                }
                
                if !selectedPeople.isEmpty, let amount = Double(itemAmount) {
                    Section {
                        Text("Each person pays: $\(amount / Double(selectedPeople.count), specifier: "%.2f")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Add Shared Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let amount = Double(itemAmount), !selectedPeople.isEmpty {
                            let finalName = itemName.isEmpty ? "Item" : itemName
                            let names = participants
                                .filter { selectedPeople.contains($0.persistentModelID) }
                                .map { $0.name }
                            
                            onSave(TempSharedItem(
                                name: finalName,
                                amount: amount,
                                sharedByIDs: Array(selectedPeople),
                                sharedByNames: names
                            ))
                            dismiss()
                        }
                    }
                    .disabled(Double(itemAmount) == nil || selectedPeople.isEmpty)
                }
            }
        }
    }
}

// Make PersistentIdentifier Identifiable for sheet presentation
extension PersistentIdentifier: @retroactive Identifiable {
    public var id: Self { self }
}
