//
//  LineItenSheets.swift
//  TripSplitApp
//
//  Created by Megan Schott on 1/20/26.
//

import SwiftUI
import SwiftData

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
    var shares: [PersistentIdentifier: Int] // NEW - stores custom shares per person
    var isCustomSplit: Bool // NEW - tracks if using custom shares
    
    var amountPerPerson: Double {
        guard !sharedByIDs.isEmpty else { return 0 }
        
        if isCustomSplit {
            // Calculate based on custom shares
            let totalShares = shares.values.reduce(0, +)
            guard totalShares > 0 else { return 0 }
            return amount / Double(totalShares)
        } else {
            // Even split
            return amount / Double(sharedByIDs.count)
        }
    }
    
    func amountFor(personID: PersistentIdentifier) -> Double {
        guard sharedByIDs.contains(personID) else { return 0 }
        
        if isCustomSplit {
            let personShares = shares[personID] ?? 1
            let totalShares = shares.values.reduce(0, +)
            guard totalShares > 0 else { return 0 }
            return amount * Double(personShares) / Double(totalShares)
        } else {
            return amountPerPerson
        }
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
    @State private var isCustomSplit = false
    @State private var customShares: [PersistentIdentifier: Int] = [:]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Item Details") {
                    TextField("Item name (optional)", text: $itemName)
                    TextField("Total amount", text: $itemAmount)
                        .keyboardType(.decimalPad)
                }
                
                Section {
                    Picker("Split Type", selection: $isCustomSplit) {
                        Text("Even").tag(false)
                        Text("Custom Shares").tag(true)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("How to Split")
                }
                
                if isCustomSplit {
                    customSplitSection
                } else {
                    evenSplitSection
                }
                
                if !selectedPeople.isEmpty, let amount = Double(itemAmount) {
                    Section("Preview") {
                        ForEach(participants.filter { selectedPeople.contains($0.persistentModelID) }) { person in
                            HStack {
                                Circle()
                                    .fill(Color(person.color))
                                    .frame(width: 20, height: 20)
                                Text(person.name)
                                Spacer()
                                if isCustomSplit {
                                    let shares = customShares[person.persistentModelID] ?? 1
                                    let totalShares = selectedPeople.reduce(0) { total, id in
                                        total + (customShares[id] ?? 1)
                                    }
                                    let personAmount = amount * Double(shares) / Double(totalShares)
                                    Text("$\(personAmount, specifier: "%.2f")")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("$\(amount / Double(selectedPeople.count), specifier: "%.2f")")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
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
                        saveItem()
                    }
                    .disabled(Double(itemAmount) == nil || selectedPeople.isEmpty)
                }
            }
        }
    }
    
    private var evenSplitSection: some View {
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
                    togglePerson(person)
                }
            }
            
            Button("Select All") {
                selectedPeople = Set(participants.map { $0.persistentModelID })
            }
        }
    }
    
    private var customSplitSection: some View {
        Section("Custom Shares") {
            ForEach(participants) { person in
                HStack {
                    Circle()
                        .fill(Color(person.color))
                        .frame(width: 25, height: 25)
                    Text(person.name)
                    Spacer()
                    
                    if selectedPeople.contains(person.persistentModelID) {
                        Stepper(
                            value: Binding(
                                get: { customShares[person.persistentModelID] ?? 1 },
                                set: { customShares[person.persistentModelID] = $0 }
                            ),
                            in: 1...10
                        ) {
                            Text("\(customShares[person.persistentModelID] ?? 1) share\(customShares[person.persistentModelID] ?? 1 == 1 ? "" : "s")")
                                .frame(width: 80, alignment: .trailing)
                        }
                    } else {
                        Button(action: {
                            togglePerson(person)
                        }) {
                            Image(systemName: "circle")
                                .foregroundStyle(.gray)
                        }
                    }
                }
            }
            
            Button("Select All") {
                selectedPeople = Set(participants.map { $0.persistentModelID })
                // Initialize shares for newly selected people
                for id in selectedPeople {
                    if customShares[id] == nil {
                        customShares[id] = 1
                    }
                }
            }
        }
    }
    
    private func togglePerson(_ person: Person) {
        if selectedPeople.contains(person.persistentModelID) {
            selectedPeople.remove(person.persistentModelID)
            customShares.removeValue(forKey: person.persistentModelID)
        } else {
            selectedPeople.insert(person.persistentModelID)
            if isCustomSplit && customShares[person.persistentModelID] == nil {
                customShares[person.persistentModelID] = 1
            }
        }
    }
    
    private func saveItem() {
        guard let amount = Double(itemAmount), !selectedPeople.isEmpty else { return }
        
        let finalName = itemName.isEmpty ? "Item" : itemName
        let names = participants
            .filter { selectedPeople.contains($0.persistentModelID) }
            .map { $0.name }
        
        // Build shares dictionary - use custom shares if custom split, otherwise all 1
        var sharesDict: [PersistentIdentifier: Int] = [:]
        for id in selectedPeople {
            sharesDict[id] = isCustomSplit ? (customShares[id] ?? 1) : 1
        }
        
        onSave(TempSharedItem(
            name: finalName,
            amount: amount,
            sharedByIDs: Array(selectedPeople),
            sharedByNames: names,
            shares: sharesDict,
            isCustomSplit: isCustomSplit
        ))
        dismiss()
    }
}

// Make PersistentIdentifier Identifiable for sheet presentation
extension PersistentIdentifier: @retroactive Identifiable {
    public var id: Self { self }
}
