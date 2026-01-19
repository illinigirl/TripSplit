//
//  TripSplitAppApp.swift
//  TripSplitApp
//
//  Created by Megan Schott on 1/19/26.
//

import SwiftUI
import SwiftData

@main
struct TripSplitApp: App {
    var body: some Scene {
        WindowGroup {
            TripListView()
        }
        .modelContainer(for: [Trip.self, Person.self, Expense.self])
    }
}
