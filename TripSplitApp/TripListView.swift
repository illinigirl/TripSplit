//
//  TripListView.swift
//  TripSplitApp
//
//  Created by Megan Schott on 1/19/26.
//

import SwiftUI
import SwiftData

struct TripListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var trips: [Trip]
    @State private var showingCreateTrip = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Sunset to Ocean gradient background
                LinearGradient(
                    colors: [Color.sunsetOrange.opacity(0.35), Color.oceanBlue.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                if trips.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "airplane.departure")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.oceanBlue)
                        Text("No trips yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Tap + to create your first trip")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    List {
                        ForEach(trips) { trip in
                            NavigationLink(destination: TripDetailView(trip: trip)) {
                                HStack(spacing: 16) {
                                    // Trip icon
                                    ZStack {
                                        Circle()
                                            .fill(Color.sunsetOrange.opacity(0.2))
                                            .frame(width: 50, height: 50)
                                        Image(systemName: "suitcase.fill")
                                            .font(.title3)
                                            .foregroundStyle(Color.sunsetOrange)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(trip.name)
                                            .font(.headline)
                                        Text("\(trip.participants.count) people • $\(trip.totalSpent, specifier: "%.0f")")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        .onDelete(perform: deleteTrips)
                        .listRowBackground(Color.cardBackground)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Trips")
            
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink(destination: FriendsListView()) {
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                            Text("Friends")
                        }
                        .foregroundStyle(Color.oceanBlue)
                        .fontWeight(.semibold)
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateTrip = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.sunsetOrange)
                    }
                }
            }
            
            .sheet(isPresented: $showingCreateTrip) {
                CreateTripView()
            }
        }
    }
    
    private func deleteTrips(at offsets: IndexSet) {
        for index in offsets {
            let trip = trips[index]
            modelContext.delete(trip)
        }
    }
}
