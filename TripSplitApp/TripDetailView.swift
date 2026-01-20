import SwiftUI
import SwiftData

struct TripDetailView: View {
    let trip: Trip
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddExpense = false
    @State private var showingAddPerson = false
    
    var whoShouldPayNext: Person? {
        guard !trip.participants.isEmpty else { return nil }
        return trip.participants.min(by: { $0.netBalance(in: trip) < $1.netBalance(in: trip) })
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
            
            List {
                if !trip.expenses.isEmpty, let nextPayer = whoShouldPayNext {
                    Section {
                        HStack {
                            Circle()
                                .fill(Color.participantColors[nextPayer.color] ?? .blue)
                                .frame(width: 40, height: 40)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(nextPayer.name) should grab the next one")
                                    .font(.headline)
                                Text("Down $\(abs(nextPayer.netBalance(in: trip)), specifier: "%.2f")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color.sunsetOrange)
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(Color.cardBackground)
                }
                
                Section("Balances") {
                    ForEach(trip.participants) { person in
                        HStack {
                            Circle()
                                .fill(Color.participantColors[person.color] ?? .blue)
                                .frame(width: 35, height: 35)
                            Text(person.name)
                                .font(.headline)
                            Spacer()
                            Text("$\(person.netBalance(in: trip), specifier: "%.2f")")
                                .font(.headline)
                                .foregroundStyle(person.netBalance(in: trip) >= 0 ? Color.moneyOwing : Color.moneyOwed)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listRowBackground(Color.cardBackground)
                
                Section("Expenses") {
                    if trip.expenses.isEmpty {
                        Text("No expenses yet")
                            .foregroundStyle(.secondary)
                            .italic()
                    } else {
                        ForEach(trip.expenses.sorted(by: { $0.date > $1.date })) { expense in
                            NavigationLink(destination: ExpenseDetailView(expense: expense, trip: trip)) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(expense.expenseDescription)
                                            .font(.headline)
                                        HStack(spacing: 4) {
                                            if let payer = expense.paidBy {
                                                Circle()
                                                    .fill(Color.participantColors[payer.color] ?? .blue)
                                                    .frame(width: 16, height: 16)
                                                Text(payer.name)
                                            }
                                            Text("•")
                                                .foregroundStyle(.secondary)
                                            Text("\(expense.participantCount) people")
                                        }
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("$\(expense.amount, specifier: "%.2f")")
                                        .font(.headline)
                                        .foregroundStyle(Color.oceanBlue)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete(perform: deleteExpenses)
                    }
                }
                .listRowBackground(Color.cardBackground)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(trip.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddExpense = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.sunsetOrange)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingAddPerson = true
                    } label: {
                        Label("Add Person", systemImage: "person.badge.plus")
                    }
                    
                    NavigationLink(destination: SettlementView(trip: trip)) {
                        Label("Settle Up", systemImage: "checkmark.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Color.oceanBlue)
                }
            }
        }
        .sheet(isPresented: $showingAddExpense) {
            AddExpenseView(trip: trip)
        }
        .sheet(isPresented: $showingAddPerson) {
            AddPersonToTripView(trip: trip)
        }
    }
    
    private func deleteExpenses(at offsets: IndexSet) {
        let sortedExpenses = trip.expenses.sorted(by: { $0.date > $1.date })
        for index in offsets {
            let expense = sortedExpenses[index]
            modelContext.delete(expense)
            if let tripIndex = trip.expenses.firstIndex(where: { $0.id == expense.id }) {
                trip.expenses.remove(at: tripIndex)
            }
        }
    }
}
