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
