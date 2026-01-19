import SwiftUI
import SwiftData

struct TripDetailView: View {
    let trip: Trip
    @State private var showingAddExpense = false
    @State private var showingSettlement = false
    
    var whoShouldPayNext: Person? {
        guard !trip.participants.isEmpty else { return nil }
        return trip.participants.min(by: { $0.netBalance(in: trip) < $1.netBalance(in: trip) })
    }
    
    var body: some View {
        List {
            if !trip.expenses.isEmpty, let nextPayer = whoShouldPayNext {
                Section {
                    HStack {
                        Circle()
                            .fill(Color(nextPayer.color))
                            .frame(width: 30, height: 30)
                        VStack(alignment: .leading) {
                            Text("\(nextPayer.name) should grab the next one")
                                .font(.headline)
                            Text("Down $\(abs(nextPayer.netBalance(in: trip)), specifier: "%.2f")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
            }
            
            Section("Balances") {
                ForEach(trip.participants) { person in
                    HStack {
                        Circle()
                            .fill(Color(person.color))
                            .frame(width: 30, height: 30)
                        Text(person.name)
                        Spacer()
                        Text("$\(person.netBalance(in: trip), specifier: "%.2f")")
                            .foregroundStyle(person.netBalance(in: trip) >= 0 ? .green : .red)
                    }
                }
            }
            
            Section("Expenses") {
                if trip.expenses.isEmpty {
                    Text("No expenses yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(trip.expenses.sorted(by: { $0.date > $1.date })) { expense in
                        VStack(alignment: .leading) {
                            HStack {
                                Text(expense.expenseDescription)
                                    .font(.headline)
                                Spacer()
                                Text("$\(expense.amount, specifier: "%.2f")")
                            }
                            Text("Paid by \(expense.paidBy?.name ?? "Unknown") • Split \(expense.participants.count) ways")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(trip.name)
        
        
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddExpense = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: SettlementView(trip: trip)) {
                    Text("Settle Up")
                }
            }
        }
        
        .sheet(isPresented: $showingAddExpense) {
            AddExpenseView(trip: trip)
        }
    }
}
