//
//  SettlementView.swift
//  TripSplitApp
//
//  Created by Megan Schott on 1/19/26.
//

import SwiftUI
import SwiftData

struct Payment: Identifiable {
    let id = UUID()
    let from: Person
    let to: Person
    let amount: Double
}

struct SettlementView: View {
    let trip: Trip
    
    var settlements: [Payment] {
        calculateSettlement()
    }
    
    var body: some View {
        List {
            if settlements.isEmpty {
                Section {
                    Text("Everyone is settled up!")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("Suggested Payments") {
                    ForEach(settlements) { payment in
                        HStack {
                            Circle()
                                .fill(Color(payment.from.color))
                                .frame(width: 30, height: 30)
                            Text(payment.from.name)
                            
                            Image(systemName: "arrow.right")
                                .foregroundStyle(.secondary)
                            
                            Circle()
                                .fill(Color(payment.to.color))
                                .frame(width: 30, height: 30)
                            Text(payment.to.name)
                            
                            Spacer()
                            
                            Text("$\(payment.amount, specifier: "%.2f")")
                                .font(.headline)
                                .foregroundStyle(.green)
                        }
                    }
                }
                
                Section {
                    Text("\(settlements.count) transaction\(settlements.count == 1 ? "" : "s") needed")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settle Up")
    }
    
    private func calculateSettlement() -> [Payment] {
        var balances = trip.participants.map { ($0, $0.netBalance(in: trip)) }
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
