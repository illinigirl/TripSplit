//
//  DemoSeed.swift
//  TripSplitApp
//
//  Screenshot/demo support. Launching a DEBUG build with "-seedDemoData"
//  replaces all data with a sample trip; adding "-screenshotScreen <name>"
//  (tripDetail | expenseDetail | settlement) then auto-opens that screen.
//  Compiles to a no-op in Release, so none of this ships to the App Store.
//
//  Example:
//    xcrun simctl launch booted com.meganschott.TripSplitApp \
//        -seedDemoData -screenshotScreen settlement
//

import SwiftUI
import SwiftData

#if DEBUG
@MainActor
enum DemoSeed {
    enum Screen: String {
        case tripDetail, expenseDetail, settlement
    }

    /// The trip and expense opened by the screenshot screens.
    static let featuredTripName = "Lake Tahoe 2026"
    static let featuredExpenseDescription = "Dinner at The Boathouse"

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-seedDemoData")
    }

    static var screen: Screen? {
        let args = ProcessInfo.processInfo.arguments
        guard let flagIndex = args.firstIndex(of: "-screenshotScreen"),
              args.indices.contains(flagIndex + 1) else { return nil }
        return Screen(rawValue: args[flagIndex + 1])
    }

    /// Guards against onAppear firing more than once per launch.
    private static var hasSeeded = false

    /// Wipes all data and inserts the sample trip, so repeated screenshot
    /// runs are deterministic regardless of what was in the store before.
    static func seed(context: ModelContext) {
        guard !hasSeeded else { return }
        hasSeeded = true

        // Delete individually — bulk delete(model:) fails silently on
        // models with cascade relationships.
        for trip in (try? context.fetch(FetchDescriptor<Trip>())) ?? [] {
            context.delete(trip)
        }
        for friend in (try? context.fetch(FetchDescriptor<Friend>())) ?? [] {
            context.delete(friend)
        }
        try? context.save()

        func day(_ day: Int) -> Date {
            Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: day, hour: 12))!
        }

        // Two background trips so the trip list looks lived-in
        func addSimpleTrip(_ name: String, month: Int, days: ClosedRange<Int>,
                           people: [(String, String)], expenses: [(String, String, Double)]) {
            func tripDay(_ d: Int) -> Date {
                Calendar.current.date(from: DateComponents(year: 2026, month: month, day: d, hour: 12))!
            }
            let trip = Trip(name: name, startDate: tripDay(days.lowerBound), endDate: tripDay(days.upperBound))
            context.insert(trip)
            var participants: [Person] = []
            for (personName, color) in people {
                let person = Person(name: personName, color: color)
                person.trip = trip
                context.insert(person)
                trip.participants.append(person)
                participants.append(person)
            }
            for (index, (description, category, amount)) in expenses.enumerated() {
                let expense = Expense(amount: amount, description: description,
                                      date: tripDay(days.lowerBound), category: category,
                                      paidBy: participants[index % participants.count])
                expense.trip = trip
                context.insert(expense)
                trip.expenses.append(expense)
                let shareAmount = amount / Double(participants.count)
                for person in participants {
                    let share = ExpenseShare(person: person, amount: shareAmount)
                    share.expense = expense
                    expense.shares.append(share)
                    context.insert(share)
                }
            }
        }

        addSimpleTrip("Moab Long Weekend", month: 4, days: 10...13,
                      people: [("Alex", "coral"), ("Riley", "purple"), ("Casey", "yellow")],
                      expenses: [("Campsite", "Lodging", 180),
                                 ("Jeep rental", "Transportation", 420),
                                 ("Groceries", "Food", 84.30)])
        addSimpleTrip("Chicago Weekend", month: 5, days: 15...17,
                      people: [("Sam", "blue"), ("Jordan", "teal")],
                      expenses: [("Hotel", "Lodging", 492),
                                 ("Deep dish night", "Food", 63.80)])

        let trip = Trip(name: featuredTripName, startDate: day(18), endDate: day(21))
        context.insert(trip)

        let alex = Person(name: "Alex", color: "coral")
        let sam = Person(name: "Sam", color: "blue")
        let jordan = Person(name: "Jordan", color: "teal")
        let riley = Person(name: "Riley", color: "purple")
        let everyone = [alex, sam, jordan, riley]
        for person in everyone {
            person.trip = trip
            context.insert(person)
            trip.participants.append(person)
        }

        // Wires an expense into the trip the same way AddExpenseView.saveExpense does.
        func addExpense(_ amount: Double, _ description: String, category: String,
                        paidBy: Person, date: Date, shares: [(Person, Double)]) -> Expense {
            let expense = Expense(amount: amount, description: description,
                                  date: date, category: category, paidBy: paidBy)
            expense.trip = trip
            context.insert(expense)
            trip.expenses.append(expense)
            for (person, shareAmount) in shares {
                let share = ExpenseShare(person: person, amount: shareAmount)
                share.expense = expense
                expense.shares.append(share)
                context.insert(share)
            }
            return expense
        }

        // Even splits
        _ = addExpense(840, "Lakeside Airbnb", category: "Lodging", paidBy: alex, date: day(18),
                       shares: everyone.map { ($0, 210) })
        _ = addExpense(126.40, "Groceries & supplies", category: "Food", paidBy: sam, date: day(18),
                       shares: everyone.map { ($0, 31.60) })
        _ = addExpense(360, "Ski lift tickets", category: "Entertainment", paidBy: riley, date: day(19),
                       shares: everyone.map { ($0, 90) })

        // Ratio split: Sam took 2 shares of gas, everyone else 1
        _ = addExpense(94.50, "Gas & tolls", category: "Transportation", paidBy: alex, date: day(21),
                       shares: [(alex, 18.90), (sam, 37.80), (jordan, 18.90), (riley, 18.90)])

        // Itemized dinner: per-person line items plus two shared items,
        // one split evenly and one with custom share counts.
        let dinner = addExpense(187.20, featuredExpenseDescription, category: "Food",
                                paidBy: jordan, date: day(20),
                                shares: [(alex, 65.55), (sam, 50.55), (jordan, 42.55), (riley, 28.55)])

        let dishes: [(Person, String, Double)] = [
            (alex, "Ribeye", 42), (sam, "Grilled Salmon", 34),
            (jordan, "Truffle Pasta", 26), (riley, "Boathouse Burger", 19),
        ]
        for (person, name, amount) in dishes {
            let lineItem = LineItem(name: name, amount: amount)
            lineItem.person = person
            lineItem.expense = dinner
            person.lineItems.append(lineItem)
            context.insert(lineItem)
        }

        let appetizers = SharedItem(name: "Appetizers", amount: 38.20)
        context.insert(appetizers)
        appetizers.expense = dinner
        for person in everyone {
            appetizers.sharedBy.append(person)
            person.sharedItems.append(appetizers)
        }
        dinner.sharedItems.append(appetizers)

        let wine = SharedItem(name: "Bottle of Wine", amount: 28)
        wine.isCustomSplit = true
        context.insert(wine)
        wine.expense = dinner
        for person in [alex, sam, jordan] {
            wine.sharedBy.append(person)
            person.sharedItems.append(wine)
        }
        wine.customShares = ["Alex": 2, "Sam": 1, "Jordan": 1]
        dinner.sharedItems.append(wine)

        // A partial settle-up so the settlement screen shows a recorded payment
        let payment = PaymentRecord(fromPersonName: "Sam", toPersonName: "Alex",
                                    amount: 100, date: day(21))
        payment.trip = trip
        context.insert(payment)
        trip.paymentRecords.append(payment)

        try? context.save()
    }
}
#endif

/// Attached to TripListView's content. In Release builds this is a no-op;
/// in DEBUG it seeds demo data and auto-navigates when the launch args ask for it.
struct DemoScreenshotModifier: ViewModifier {
    #if DEBUG
    @Environment(\.modelContext) private var modelContext
    @Query private var trips: [Trip]
    @State private var showingDemoScreen = false

    func body(content: Content) -> some View {
        content
            .navigationDestination(isPresented: $showingDemoScreen) { demoDestination }
            .onAppear {
                guard DemoSeed.isEnabled else { return }
                DemoSeed.seed(context: modelContext)
                if DemoSeed.screen != nil {
                    // Defer one runloop turn so the seeded trip is visible to @Query
                    DispatchQueue.main.async { showingDemoScreen = true }
                }
            }
    }

    @ViewBuilder
    private var demoDestination: some View {
        if let trip = trips.first(where: { $0.name == DemoSeed.featuredTripName }) ?? trips.first {
            switch DemoSeed.screen {
            case .expenseDetail:
                if let expense = trip.expenses.first(where: {
                    $0.expenseDescription == DemoSeed.featuredExpenseDescription
                }) {
                    ExpenseDetailView(expense: expense, trip: trip)
                }
            case .settlement:
                SettlementView(trip: trip)
            case .tripDetail, .none:
                TripDetailView(trip: trip)
            }
        }
    }
    #else
    func body(content: Content) -> some View {
        content
    }
    #endif
}
