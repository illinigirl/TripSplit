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
    case shares = "By Shares"  // Changed from "custom"
    case item = "By Item"
}

struct AddExpenseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let trip: Trip
    
    @State private var amount = ""
    @State private var description = ""
    @State private var date: Date = Date()
    @State private var category = "Food"
    @State private var selectedPayer: Person?
    @State private var selectedParticipants: Set<PersistentIdentifier> = []
    @State private var splitType: SplitType = .even
    @State private var customShares: [PersistentIdentifier: String] = [:]
    
    // Line items per person
    @State private var personLineItems: [PersistentIdentifier: [TempLineItem]] = [:]
    @State private var sharedItems: [TempSharedItem] = []
    
    // For adding items - using ID instead of Person object
    @State private var selectedPersonID: PersistentIdentifier?
    @State private var showingAddSharedItemSheet = false

    // For editing items
    @State private var editingLineItem: LineItemEditInfo?
    @State private var editingSharedItemIndex: Int?
    
    // For receipt image
    @State private var showingReceiptPicker = false
    @State private var receiptImage: UIImage?
    
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

                        DatePicker("Date", selection: $date, displayedComponents: .date)

                        Picker("Category", selection: $category) {
                            ForEach(categories, id: \.self) { category in
                                Text(category).tag(category)
                            }
                        }
                    }
                    .listRowBackground(Color.cardBackground)
                    
                    Section("Receipt (Optional)") {
                        if let image = receiptImage {
                            HStack {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 100)
                                    .cornerRadius(8)
                                
                                Spacer()
                                
                                Button(action: {
                                    showingReceiptPicker = true
                                }) {
                                    Text("Change")
                                        .foregroundStyle(Color.oceanBlue)
                                }
                                
                                Button(action: {
                                    receiptImage = nil
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundStyle(Color.moneyOwed)
                                }
                            }
                        } else {
                            Button(action: {
                                showingReceiptPicker = true
                            }) {
                                Label("Add Receipt Photo", systemImage: "camera.fill")
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
                    case .shares:  // Changed from .custom
                        sharesSplitSection
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
            .sheet(item: $editingLineItem) { editInfo in
                if let person = trip.participants.first(where: { $0.persistentModelID == editInfo.personID }),
                   let items = personLineItems[editInfo.personID],
                   editInfo.itemIndex < items.count {
                    EditLineItemSheet(
                        personName: person.name,
                        personColor: person.color,
                        item: items[editInfo.itemIndex]
                    ) { updatedItem in
                        personLineItems[editInfo.personID]?[editInfo.itemIndex] = updatedItem
                    }
                }
            }
            .sheet(item: Binding(
                get: { editingSharedItemIndex.map { SharedItemEditWrapper(index: $0) } },
                set: { editingSharedItemIndex = $0?.index }
            )) { wrapper in
                if wrapper.index < sharedItems.count {
                    EditSharedItemSheet(
                        participants: trip.participants,
                        item: sharedItems[wrapper.index]
                    ) { updatedItem in
                        sharedItems[wrapper.index] = updatedItem
                    }
                }
            }
            .sheet(isPresented: $showingReceiptPicker) {
                ImagePickerSheet { image in
                    receiptImage = image
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
    
    private var sharesSplitSection: some View {
        Section {
            ForEach(trip.participants) { person in
                HStack {
                    Circle()
                        .fill(Color(person.color))
                        .frame(width: 25, height: 25)
                    Text(person.name)
                    Spacer()
                    Stepper(
                        value: Binding(
                            get: { Int(customShares[person.persistentModelID] ?? "0") ?? 0 },
                            set: { newValue in
                                customShares[person.persistentModelID] = String(newValue)
                                if newValue > 0 {
                                    selectedParticipants.insert(person.persistentModelID)
                                } else {
                                    selectedParticipants.remove(person.persistentModelID)
                                }
                            }
                        ),
                        in: 0...20
                    ) {
                        Text("\(Int(customShares[person.persistentModelID] ?? "0") ?? 0) share\(Int(customShares[person.persistentModelID] ?? "0") ?? 0 == 1 ? "" : "s")")
                            .frame(width: 80, alignment: .trailing)
                    }
                }
            }
            
            if let total = Double(amount) {
                let totalShares = customShares.values.compactMap { Int($0) }.reduce(0, +)
                
                if totalShares > 0 {
                    Divider()
                    
                    Text("Total: \(totalShares) share\(totalShares == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    ForEach(trip.participants.filter { (Int(customShares[$0.persistentModelID] ?? "0") ?? 0) > 0 }) { person in
                        let shares = Int(customShares[person.persistentModelID] ?? "0") ?? 0
                        let amount = total * Double(shares) / Double(totalShares)
                        HStack {
                            Circle()
                                .fill(Color(person.color))
                                .frame(width: 20, height: 20)
                            Text(person.name)
                            Spacer()
                            Text("$\(amount, specifier: "%.2f")")
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    }
                }
            }
        } header: {
            Text("Assign Shares")
        } footer: {
            Text("Each person's share will be calculated proportionally. For example, 2 shares pays twice as much as 1 share.")
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
            
            ForEach(Array(sharedItems.enumerated()), id: \.element.id) { index, item in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.name)
                        Spacer()
                        Text("$\(item.amount, specifier: "%.2f")")
                            .fontWeight(.medium)
                    }

                    if item.isCustomSplit {
                        // Show custom shares breakdown
                        let breakdown = item.sharedByIDs.compactMap { id -> String? in
                            guard let person = trip.participants.first(where: { $0.persistentModelID == id }) else { return nil }
                            let shares = item.shares[id] ?? 1
                            let amount = item.amountFor(personID: id)
                            return String(format: "%@ (%d×) $%.2f", person.name, shares, amount)
                        }
                        Text(breakdown.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        // Show even split
                        Text("Split between: \(item.sharedByNames.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("$\(item.amountPerPerson, specifier: "%.2f") each")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    editingSharedItemIndex = index
                }
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
                    
                    // Show individual items if they exist
                    if let items = personLineItems[person.persistentModelID], !items.isEmpty {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            HStack {
                                Text("• \(item.name)")
                                    .font(.subheadline)
                                Spacer()
                                Text("$\(item.amount, specifier: "%.2f")")
                                    .font(.subheadline)
                            }
                            .foregroundStyle(.secondary)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingLineItem = LineItemEditInfo(personID: person.persistentModelID, itemIndex: index)
                            }
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
                    
                    // Show shared items portion
                    let hasSharedItems = sharedItems.contains(where: { $0.sharedByIDs.contains(person.persistentModelID) })
                    if hasSharedItems {
                        let personSharedTotal = sharedItems
                            .filter { $0.sharedByIDs.contains(person.persistentModelID) }
                            .reduce(0) { $0 + $1.amountFor(personID: person.persistentModelID) }
                        
                        HStack {
                            Text("+ Share of shared items")
                                .font(.caption)
                            Spacer()
                            Text("$\(personSharedTotal, specifier: "%.2f")")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
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
        
        // Calculate person's share of shared items using new method
        let personSharedTotal = sharedItems
            .filter { $0.sharedByIDs.contains(person.persistentModelID) }
            .reduce(0) { $0 + $1.amountFor(personID: person.persistentModelID) }
        
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
    
    private func adjustSharesForRounding(shares: [(person: Person, amount: Double)], total: Double) -> [(person: Person, amount: Double)] {
        guard !shares.isEmpty else { return shares }
        
        // Round all shares to 2 decimal places
        var adjustedShares = shares.map { (person: $0.person, amount: round($0.amount * 100) / 100) }
        
        // Calculate the difference due to rounding
        let roundedTotal = adjustedShares.reduce(0) { $0 + $1.amount }
        let difference = total - roundedTotal
        
        // Adjust the last person's share to absorb the rounding difference
        if let lastIndex = adjustedShares.indices.last {
            adjustedShares[lastIndex].amount += difference
        }
        
        return adjustedShares
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
        
        switch splitType {
        case .even, .shares:  // Changed from .custom
            guard !selectedParticipants.isEmpty else { return false }
        case .item:
            break
        }
        
        switch splitType {
        case .even:
            return true
        case .shares:  // Changed from .custom
            let totalShares = customShares.values.compactMap { Int($0) }.reduce(0, +)
            return totalShares > 0
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
            date: date,
            category: category,
            paidBy: payer
        )
        
        // Save receipt image if present
        if let image = receiptImage {
            expense.receiptImageData = image.compressedForReceipt()
        }
        
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
            
        case .shares:
            let totalShares = customShares.values.compactMap { Int($0) }.reduce(0, +)
            guard totalShares > 0 else { return }
            
            for person in participantsList {
                if let sharesStr = customShares[person.persistentModelID],
                   let shares = Int(sharesStr), shares > 0 {
                    let shareAmount = amountValue * Double(shares) / Double(totalShares)
                    let share = ExpenseShare(person: person, amount: shareAmount)
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
                sharedItem.isCustomSplit = tempShared.isCustomSplit
                modelContext.insert(sharedItem)
                sharedItem.expense = expense
                
                // Build customShares dictionary with string keys
                var customSharesDict: [String: Int] = [:]
                
                for personID in tempShared.sharedByIDs {
                    if let person = trip.participants.first(where: { $0.persistentModelID == personID }) {
                        sharedItem.sharedBy.append(person)
                        person.sharedItems.append(sharedItem)
                        
                        // Store custom shares using string representation of ID
                        let shares = tempShared.shares[personID] ?? 1
                        customSharesDict[person.name] = shares
                    }
                }
                
                sharedItem.customShares = customSharesDict
                expense.sharedItems.append(sharedItem)
            }
            
            // Calculate shares for each person with items
            var sharesData: [(person: Person, amount: Double)] = []
            for person in trip.participants {
                if let finalAmount = calculateFinalAmount(for: person, total: amountValue) {
                    sharesData.append((person: person, amount: finalAmount))
                }
            }
            
            // Adjust for rounding and create ExpenseShare objects
            let adjustedShares = adjustSharesForRounding(shares: sharesData, total: amountValue)
            for shareData in adjustedShares {
                let share = ExpenseShare(person: shareData.person, amount: shareData.amount)
                share.expense = expense
                expense.shares.append(share)
                modelContext.insert(share)
            }
        }
        
        try? modelContext.save()
        dismiss()
    }
}
