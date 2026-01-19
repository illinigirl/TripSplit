//
//  TripListView.swift
//  TripSplitApp
//
//  Created by Megan Schott on 1/19/26.
//

import SwiftUI
import SwiftData

struct TripListView: View {
    @Query private var trips: [Trip]
    @State private var showingCreateTrip = false
    
    var body: some View {
        NavigationStack {
            List(trips) { trip in
                NavigationLink(destination: TripDetailView(trip: trip)) {
                    VStack(alignment: .leading) {
                        Text(trip.name)
                            .font(.headline)
                        Text("\(trip.participants.count) people • $\(trip.totalSpent, specifier: "%.2f")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Trips")
            .toolbar {
                Button {
                    showingCreateTrip = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showingCreateTrip) {
                CreateTripView()
            }
        }
    }
}
