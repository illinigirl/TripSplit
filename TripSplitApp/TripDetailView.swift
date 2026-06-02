import SwiftUI
import SwiftData

struct TripDetailView: View {
    let trip: Trip
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddExpense = false
    @State private var showingAddPerson = false
    @State private var showingRenameTrip = false
    @State private var renameText = ""
    @State private var blockedRemovalPerson: Person?
    
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
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                attemptRemove(person)
                            } label: {
                                Label("Remove", systemImage: "person.badge.minus")
                            }
                        }
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
                        renameText = trip.name
                        showingRenameTrip = true
                    } label: {
                        Label("Rename Trip", systemImage: "pencil")
                    }

                    Button {
                        showingAddPerson = true
                    } label: {
                        Label("Add Person", systemImage: "person.badge.plus")
                    }

                    NavigationLink(destination: SettlementView(trip: trip)) {
                        Label("Settle Up", systemImage: "checkmark.circle")
                    }

                    ShareLink(
                        item: TripReportGenerator(trip: trip).generateReportURL(),
                        preview: SharePreview("\(trip.name) Report", image: Image(systemName: "doc.richtext.fill"))
                    ) {
                        Label("Export Report", systemImage: "square.and.arrow.up")
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
        .alert("Rename Trip", isPresented: $showingRenameTrip) {
            TextField("Trip name", text: $renameText)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    trip.name = trimmed
                }
            }
        }
        .alert(
            "Can't Remove \(blockedRemovalPerson?.name ?? "Person")",
            isPresented: Binding(
                get: { blockedRemovalPerson != nil },
                set: { if !$0 { blockedRemovalPerson = nil } }
            )
        ) {
            Button("OK", role: .cancel) { blockedRemovalPerson = nil }
        } message: {
            Text("They're involved in one or more expenses. Remove or reassign those expenses first.")
        }
    }

    // Returns true if the person is tied to any expense — as payer, as a
    // share participant, via line items, or as part of a shared item.
    private func isInvolvedInExpenses(_ person: Person) -> Bool {
        if trip.expenses.contains(where: { $0.paidBy?.id == person.id }) { return true }
        if trip.expenses.contains(where: { expense in
            expense.shares.contains(where: { $0.person?.id == person.id })
        }) { return true }
        if !person.lineItems.isEmpty { return true }
        if trip.expenses.contains(where: { expense in
            expense.sharedItems.contains(where: { item in
                item.sharedBy.contains(where: { $0.id == person.id })
            })
        }) { return true }
        return false
    }

    private func attemptRemove(_ person: Person) {
        guard !isInvolvedInExpenses(person) else {
            blockedRemovalPerson = person
            return
        }
        if let index = trip.participants.firstIndex(where: { $0.id == person.id }) {
            trip.participants.remove(at: index)
        }
        modelContext.delete(person)
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
