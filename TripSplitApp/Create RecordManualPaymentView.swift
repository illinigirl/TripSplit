//
//  Create RecordManualPaymentView.swift
//  TripSplitApp
//
//  Created by Megan Schott on 1/20/26.
//

import SwiftUI
import SwiftData

struct RecordManualPaymentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let trip: Trip
    
    @State private var fromPerson: Person?
    @State private var toPerson: Person?
    @State private var amount = ""
    
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
                    Section("Payment Details") {
                        // From Person
                        VStack(alignment: .leading, spacing: 8) {
                            Text("From")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(trip.participants) { person in
                                        Button {
                                            fromPerson = person
                                        } label: {
                                            VStack(spacing: 8) {
                                                Circle()
                                                    .fill(Color.participantColors[person.color] ?? .blue)
                                                    .frame(width: 50, height: 50)
                                                    .overlay {
                                                        if fromPerson == person {
                                                            Circle()
                                                                .stroke(Color.oceanBlue, lineWidth: 3)
                                                        }
                                                    }
                                                Text(person.name)
                                                    .font(.caption)
                                                    .foregroundStyle(.primary)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        
                        // To Person
                        VStack(alignment: .leading, spacing: 8) {
                            Text("To")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(trip.participants) { person in
                                        Button {
                                            toPerson = person
                                        } label: {
                                            VStack(spacing: 8) {
                                                Circle()
                                                    .fill(Color.participantColors[person.color] ?? .blue)
                                                    .frame(width: 50, height: 50)
                                                    .overlay {
                                                        if toPerson == person {
                                                            Circle()
                                                                .stroke(Color.sunsetOrange, lineWidth: 3)
                                                        }
                                                    }
                                                Text(person.name)
                                                    .font(.caption)
                                                    .foregroundStyle(.primary)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        
                        // Amount
                        HStack {
                            Image(systemName: "dollarsign.circle.fill")
                                .foregroundStyle(Color.oceanBlue)
                            TextField("Amount", text: $amount)
                                .keyboardType(.decimalPad)
                                .onChange(of: amount) { oldValue, newValue in
                                    amount = filterNumeric(newValue)
                                }
                        }
                    }
                    .listRowBackground(Color.cardBackground)
                    
                    if let from = fromPerson, let to = toPerson, let amountValue = Double(amount), amountValue > 0 {
                        Section {
                            HStack {
                                Spacer()
                                VStack(spacing: 12) {
                                    HStack(spacing: 16) {
                                        VStack(spacing: 4) {
                                            Circle()
                                                .fill(Color.participantColors[from.color] ?? .blue)
                                                .frame(width: 40, height: 40)
                                            Text(from.name)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                        }
                                        
                                        Image(systemName: "arrow.right")
                                            .foregroundStyle(Color.oceanBlue)
                                        
                                        VStack(spacing: 4) {
                                            Circle()
                                                .fill(Color.participantColors[to.color] ?? .blue)
                                                .frame(width: 40, height: 40)
                                            Text(to.name)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                        }
                                    }
                                    
                                    Text("$\(amountValue, specifier: "%.2f")")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundStyle(Color.moneyOwing)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                        .listRowBackground(Color.cardBackground)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Record Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.moneyOwed)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Record") {
                        recordPayment()
                    }
                    .foregroundStyle(Color.oceanBlue)
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
        }
    }
    
    private var canSave: Bool {
        guard let from = fromPerson, let to = toPerson else { return false }
        guard from != to else { return false }
        guard let amountValue = Double(amount), amountValue > 0 else { return false }
        return true
    }
    
    private func filterNumeric(_ value: String) -> String {
        let filtered = value.filter { "0123456789.".contains($0) }
        let parts = filtered.split(separator: ".")
        if parts.count > 2 {
            return String(parts[0]) + "." + parts[1...].joined()
        }
        return filtered
    }
    
    private func recordPayment() {
        guard let from = fromPerson, let to = toPerson, let amountValue = Double(amount) else { return }
        
        let record = PaymentRecord(
            fromPersonName: from.name,
            toPersonName: to.name,
            amount: amountValue
        )
        record.trip = trip
        modelContext.insert(record)
        trip.paymentRecords.append(record)
        try? modelContext.save()
        
        dismiss()
    }
}
