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
    @State private var date: Date
    @State private var category: String
    @State private var selectedPayer: Person?
    @State private var selectedParticipants: Set<PersistentIdentifier> = []
    @State private var splitType: SplitType = .even
    @State private var customShares: [PersistentIdentifier: String] = [:]  // Changed from customAmounts
    
    // Line items per person
    @State private var personLineItems: [PersistentIdentifier: [TempLineItem]] = [:]
    @State private var sharedItems: [TempSharedItem] = []
    
    // For adding items
    @State private var selectedPersonID: PersistentIdentifier?
    @State private var showingAddSharedItemSheet = false
    
    // For receipt image
    @State private var showingReceiptPicker = false
    @State private var receiptImage: UIImage?
    
    let categories = ["Food", "Drinks", "Transportation", "Lodging", "Entertainment", "Miscellaneous"]
    
    init(trip: Trip, expense: Expense) {
        self.trip = trip
        self.expense = expense
        
        // Pre-populate fields
        _amount = State(initialValue: String(expense.amount))
        _description = State(initialValue: expense.expenseDescription)
        _date = State(initialValue: expense.date)
        _category = State(initialValue: expense.category)
        _selectedPayer = State(initialValue: expense.paidBy)
        
        // Load existing receipt image
        if let imageData = expense.receiptImageData,
           let image = UIImage(data: imageData) {
            _receiptImage = State(initialValue: image)
        }
        
        // Determine split type and populate accordingly
        let participants = expense.getParticipants(from: trip)
        let participantIDs = Set(participants.map { $0.persistentModelID })
        _selectedParticipants = State(initialValue: participantIDs)
        
        // Check if this is an itemized expense
        let hasLineItems = trip.participants.contains { person in
            !person.lineItems.filter { $0.expense == expense }.isEmpty
        }
        let hasSharedItems = !expense.sharedItems.isEmpty
        
        if hasLineItems || hasSharedItems {
            // Load itemized data
            _splitType = State(initialValue: .item)
            
            // Load line items
            var loadedLineItems: [PersistentIdentifier: [TempLineItem]] = [:]
            for person in trip.participants {
                let items = person.lineItems.filter { $0.expense == expense }
                if !items.isEmpty {
                    loadedLineItems[person.persistentModelID] = items.map {
                        TempLineItem(name: $0.name, amount: $0.amount)
                    }
                }
            }
            _personLineItems = State(initialValue: loadedLineItems)
            
            // Load shared items
            var loadedSharedItems: [TempSharedItem] = []
            for sharedItem in expense.sharedItems {
                let sharedByIDs = sharedItem.sharedBy.map { $0.persistentModelID }
                let sharedByNames = sharedItem.sharedBy.map { $0.name }
                
                // Load custom shares from the database
                var shares: [PersistentIdentifier: Int] = [:]
                for person in sharedItem.sharedBy {
                    let shareCount = sharedItem.customShares[person.name] ?? 1
                    shares[person.persistentModelID] = shareCount
                }
                
                loadedSharedItems.append(TempSharedItem(
                    name: sharedItem.name,
                    amount: sharedItem.amount,
                    sharedByIDs: sharedByIDs,
                    sharedByNames: sharedByNames,
                    shares: shares,
                    isCustomSplit: sharedItem.isCustomSplit
                ))
            }
            _sharedItems = State(initialValue: loadedSharedItems)
        } else {
            // Check if it's an even split
            let shares = expense.shares
            let amounts = shares.map { $0.amount }
            let isEven = amounts.allSatisfy { abs($0 - amounts[0]) < 0.01 }
            
            if isEven {
                _splitType = State(initialValue: .even)
            } else {
                // Treat non-even as shares
                _splitType = State(initialValue: .shares)
                var customShrs: [PersistentIdentifier: String] = [:]
                
                // Try to reverse-engineer the shares from the amounts
                let minAmount = amounts.min() ?? 1.0
                
                for participant in participants {
                    if let shareAmount = expense.getShare(for: participant) {
                        // Calculate shares as ratio to minimum
                        let shares = Int(round(shareAmount / minAmount))
                        customShrs[participant.persistentModelID] = String(shares)
                    }
                }
                _customShares = State(initialValue: customShrs)
            }
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
                            Image(systemName: "calendar")
                                .foregroundStyle(Color.oceanTeal)
                            DatePicker("Date", selection: $date, displayedComponents: .date)
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
                    case .shares:
                        sharesSplitSection
                    case .item:
                        itemSection
                    }
                }
                .scrollContentBackground(.hidden)
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
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveExpense()
                    }
                    .foregroundStyle(Color.oceanBlue)
                    .fontWeight(.semibold)
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
    
    private var sharesSplitSection: some View {
        Section {
            ForEach(trip.participants) { person in
                HStack {
                    Circle()
                        .fill(Color.participantColors[person.color] ?? .blue)
                        .frame(width: 30, height: 30)
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
                        
                        Button(action: {
                            sharedItems.remove(at: index)
                        }) {
                            Image(systemName: "trash.circle.fill")
                                .foregroundStyle(.red)
                                .font(.body)
                        }
                        .buttonStyle(.plain)
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
            }
        } header: {
            Text("Shared Items (Appetizers, etc.)")
        }
        .listRowBackground(Color.cardBackground)
    }
    
    private var individualItemsSection: some View {
        Section {
            ForEach(trip.participants) { person in
                // Check if person has any items OR shared items
                let hasLineItems = personLineItems[person.persistentModelID] != nil && !personLineItems[person.persistentModelID]!.isEmpty
                let hasSharedItems = sharedItems.contains(where: { $0.sharedByIDs.contains(person.persistentModelID) })
                
                if hasLineItems || hasSharedItems {
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
                                    
                                    Button(action: {
                                        personLineItems[person.persistentModelID]?.remove(at: index)
                                        if personLineItems[person.persistentModelID]?.isEmpty == true {
                                            personLineItems[person.persistentModelID] = nil
                                        }
                                    }) {
                                        Image(systemName: "trash.circle.fill")
                                            .foregroundStyle(.red)
                                            .font(.body)
                                    }
                                    .buttonStyle(.plain)
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
                        
                        // Show shared items portion
                        if hasSharedItems {
                            let personSharedTotal = sharedItems
                                .filter { $0.sharedByIDs.contains(person.persistentModelID) }
                                .reduce(0) { $0 + $1.amountFor(personID: person.persistentModelID) }
                            
                            HStack {
                                Text(hasLineItems ? "+ Share of shared items" : "Share of shared items")
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
        
        guard personSubtotal > 0 else { return nil }
        
        let grandSubtotal = calculateItemsSubtotal() + sharedItems.reduce(0) { $0 + $1.amount }
        
        guard grandSubtotal > 0 else { return nil }
        
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
        
        switch splitType {
        case .even, .shares:
            guard !selectedParticipants.isEmpty else { return false }
        case .item:
            break
        }
        
        switch splitType {
        case .even:
            return true
        case .shares:
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
        
        // Update existing expense
        expense.amount = amountValue
        expense.expenseDescription = description
        expense.date = date
        expense.category = category
        expense.paidBy = payer
        
        // Update receipt image
        if let image = receiptImage {
            expense.receiptImageData = image.compressedForReceipt()
        } else {
            expense.receiptImageData = nil
        }
        
        // Delete old shares
        for share in expense.shares {
            modelContext.delete(share)
        }
        expense.shares.removeAll()
        
        // Delete old line items
        for person in trip.participants {
            let oldItems = person.lineItems.filter { $0.expense == expense }
            for item in oldItems {
                modelContext.delete(item)
                if let index = person.lineItems.firstIndex(where: { $0.id == item.id }) {
                    person.lineItems.remove(at: index)
                }
            }
        }
        
        // Delete old shared items
        for oldSharedItem in expense.sharedItems {
            modelContext.delete(oldSharedItem)
        }
        expense.sharedItems.removeAll()
        
        // Create new data based on split type
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
            // Save line items
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
            
            // Save shared items
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
                        
                        // Store custom shares using person name
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
