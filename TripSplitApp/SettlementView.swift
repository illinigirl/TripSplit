//
//  SettlementView.swift
//  TripSplitApp
//
//  Created by Megan Schott on 1/19/26.
//

import SwiftUI
import SwiftData
import MessageUI

struct Payment: Identifiable {
    let id = UUID()
    let from: Person
    let to: Person
    let amount: Double
}

struct SettlementView: View {
    let trip: Trip
    @Environment(\.modelContext) private var modelContext
    @Query private var friends: [Friend]
    @State private var showingMessageComposer = false
    @State private var recordingPayment: Payment?
    
    var settlements: [Payment] {
        calculateSettlement()
    }
    
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [Color.sunsetOrange.opacity(0.35), Color.oceanBlue.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if settlements.isEmpty && trip.paymentRecords.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(Color.moneyOwing)
                    Text("Everyone is settled up!")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("No payments needed")
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(spacing: 0) {
                    List {
                        // Payment History
                        if !trip.paymentRecords.isEmpty {
                            Section("Payment History") {
                                ForEach(trip.paymentRecords.sorted(by: { $0.date > $1.date })) { record in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text(record.fromPersonName)
                                                    .fontWeight(.medium)
                                                Image(systemName: "arrow.right")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                Text(record.toPersonName)
                                                    .fontWeight(.medium)
                                            }
                                            Text(record.date.formatted(date: .abbreviated, time: .shortened))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text("$\(record.amount, specifier: "%.2f")")
                                            .font(.headline)
                                            .foregroundStyle(Color.moneyOwing)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .onDelete(perform: deletePaymentRecords)
                            }
                            .listRowBackground(Color.cardBackground)
                        }
                        
                        // Remaining Settlements
                        if !settlements.isEmpty {
                            Section {
                                Text("To settle up, make these \(settlements.count) payment\(settlements.count == 1 ? "" : "s"):")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .listRowBackground(Color.clear)
                            
                            Section {
                                ForEach(settlements) { payment in
                                    VStack(spacing: 16) {
                                        HStack(spacing: 12) {
                                            // From person
                                            VStack(spacing: 8) {
                                                Circle()
                                                    .fill(Color.participantColors[payment.from.color] ?? .blue)
                                                    .frame(width: 50, height: 50)
                                                Text(payment.from.name)
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                                    .multilineTextAlignment(.center)
                                            }
                                            .frame(maxWidth: .infinity)
                                            
                                            // Arrow
                                            VStack(spacing: 4) {
                                                Image(systemName: "arrow.right")
                                                    .font(.title2)
                                                    .foregroundStyle(Color.oceanBlue)
                                                Text("pays")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                            
                                            // To person
                                            VStack(spacing: 8) {
                                                Circle()
                                                    .fill(Color.participantColors[payment.to.color] ?? .blue)
                                                    .frame(width: 50, height: 50)
                                                Text(payment.to.name)
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                                    .multilineTextAlignment(.center)
                                            }
                                            .frame(maxWidth: .infinity)
                                        }
                                        
                                        // Amount
                                        Text("$\(payment.amount, specifier: "%.2f")")
                                            .font(.title)
                                            .fontWeight(.bold)
                                            .foregroundStyle(Color.moneyOwing)
                                        
                                        // Record Payment Button
                                        Button {
                                            recordingPayment = payment
                                        } label: {
                                            HStack {
                                                Image(systemName: "checkmark.circle.fill")
                                                Text("Record Payment")
                                            }
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color.oceanBlue)
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 16)
                                            .background(Color.oceanBlue.opacity(0.1))
                                            .cornerRadius(8)
                                        }
                                    }
                                    .padding(.vertical, 12)
                                }
                            }
                            .listRowBackground(Color.cardBackground)
                        } else if !trip.paymentRecords.isEmpty {
                            Section {
                                HStack {
                                    Spacer()
                                    VStack(spacing: 12) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 50))
                                            .foregroundStyle(Color.moneyOwing)
                                        Text("All settled up!")
                                            .font(.headline)
                                    }
                                    .padding(.vertical, 20)
                                    Spacer()
                                }
                            }
                            .listRowBackground(Color.cardBackground)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    
                    // Send Group Summary Button
                    if hasAnyPhoneNumbers() && !settlements.isEmpty {
                        VStack(spacing: 0) {
                            Divider()
                            
                            Button {
                                sendGroupSummary()
                            } label: {
                                HStack {
                                    Image(systemName: "message.fill")
                                    Text("Send Trip Summary")
                                }
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.oceanBlue)
                                .cornerRadius(12)
                            }
                            .padding()
                            .background(Color.cardBackground)
                        }
                    }
                }
            }
        }
        .navigationTitle("Settle Up")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingMessageComposer) {
            if MFMessageComposeViewController.canSendText() {
                MessageComposer(
                    recipients: getPhoneNumbers(),
                    body: getTripSummaryMessage()
                )
            } else {
                Text("Unable to send messages from this device")
            }
        }
        .alert("Record Payment", isPresented: Binding(
            get: { recordingPayment != nil },
            set: { if !$0 { recordingPayment = nil } }
        )) {
            Button("Full Amount") {
                if let payment = recordingPayment {
                    recordPayment(payment: payment, amount: payment.amount)
                }
            }
            Button("Partial Amount") {
                if let payment = recordingPayment {
                    // For now, just do full amount - we could add a custom amount later
                    recordPayment(payment: payment, amount: payment.amount)
                }
            }
            Button("Cancel", role: .cancel) {
                recordingPayment = nil
            }
        } message: {
            if let payment = recordingPayment {
                Text("\(payment.from.name) paid \(payment.to.name) $\(payment.amount, specifier: "%.2f")?")
            }
        }
    }
    
    private func deletePaymentRecords(at offsets: IndexSet) {
        let sortedRecords = trip.paymentRecords.sorted(by: { $0.date > $1.date })
        for index in offsets {
            let record = sortedRecords[index]
            modelContext.delete(record)
            if let tripIndex = trip.paymentRecords.firstIndex(where: { $0.id == record.id }) {
                trip.paymentRecords.remove(at: tripIndex)
            }
        }
    }
    
    private func recordPayment(payment: Payment, amount: Double) {
        let record = PaymentRecord(
            fromPersonName: payment.from.name,
            toPersonName: payment.to.name,
            amount: amount
        )
        record.trip = trip
        modelContext.insert(record)
        trip.paymentRecords.append(record)
        try? modelContext.save()
        recordingPayment = nil
    }
    
    private func hasAnyPhoneNumbers() -> Bool {
        return trip.participants.contains { person in
            if let friend = findFriend(for: person),
               let phone = friend.phone,
               !phone.isEmpty {
                return true
            }
            return false
        }
    }
    
    private func findFriend(for person: Person) -> Friend? {
        return friends.first(where: { $0.name == person.name })
    }
    
    private func getPhoneNumbers() -> [String] {
        var phoneNumbers: [String] = []
        for person in trip.participants {
            if let friend = findFriend(for: person),
               let phone = friend.phone,
               !phone.isEmpty {
                let cleanPhone = phone.filter { "0123456789".contains($0) }
                phoneNumbers.append(cleanPhone)
            }
        }
        return phoneNumbers
    }
    
    private func getTripSummaryMessage() -> String {
        var message = "💰 \(trip.name) - Settlement Summary\n\n"
        message += "Total spent: $\(String(format: "%.2f", trip.totalSpent))\n\n"
        
        if !trip.paymentRecords.isEmpty {
            message += "Payments made:\n"
            for record in trip.paymentRecords.sorted(by: { $0.date > $1.date }) {
                message += "• \(record.fromPersonName) → \(record.toPersonName): $\(String(format: "%.2f", record.amount))\n"
            }
            message += "\n"
        }
        
        if !settlements.isEmpty {
            message += "Still to settle:\n"
            for payment in settlements {
                message += "• \(payment.from.name) pays \(payment.to.name): $\(String(format: "%.2f", payment.amount))\n"
            }
            message += "\n\(settlements.count) payment\(settlements.count == 1 ? "" : "s") needed!"
        } else {
            message += "Everyone is settled up! 🎉"
        }
        
        return message
    }
    
    private func sendGroupSummary() {
        showingMessageComposer = true
    }
    
    private func calculateSettlement() -> [Payment] {
        var balances = trip.participants.map { ($0, $0.netBalance(in: trip)) }
        
        // Adjust balances based on recorded payments
        for record in trip.paymentRecords {
            // Find the people involved
            if let fromPerson = trip.participants.first(where: { $0.name == record.fromPersonName }),
               let toPerson = trip.participants.first(where: { $0.name == record.toPersonName }) {
                // Adjust balances: person who paid gets more positive, person who received gets more negative
                if let fromIndex = balances.firstIndex(where: { $0.0 == fromPerson }) {
                    balances[fromIndex].1 += record.amount
                }
                if let toIndex = balances.firstIndex(where: { $0.0 == toPerson }) {
                    balances[toIndex].1 -= record.amount
                }
            }
        }
        
        var payments: [Payment] = []
        
        // Filter out people with zero balance
        balances = balances.filter { abs($0.1) > 0.01 }
        
        while !balances.isEmpty {
            // Find person who is owed the most (most positive)
            guard let creditorIndex = balances.indices.max(by: { balances[$0].1 < balances[$1].1 }),
                  balances[creditorIndex].1 > 0.01 else { break }
            
            // Find person who owes the most (most negative)
            guard let debtorIndex = balances.indices.min(by: { balances[$0].1 < balances[$1].1 }),
                  balances[debtorIndex].1 < -0.01 else { break }
            
            let creditor = balances[creditorIndex]
            let debtor = balances[debtorIndex]
            
            // Calculate payment amount
            let paymentAmount = min(creditor.1, abs(debtor.1))
            
            payments.append(Payment(
                from: debtor.0,
                to: creditor.0,
                amount: paymentAmount
            ))
            
            // Update balances
            balances[creditorIndex].1 -= paymentAmount
            balances[debtorIndex].1 += paymentAmount
            
            // Remove settled people
            balances = balances.filter { abs($0.1) > 0.01 }
        }
        
        return payments
    }
}
