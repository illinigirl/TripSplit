//
//  CreateTripView.swift
//  TripSplitApp
//
//  Created by Megan Schott on 1/19/26.
//

import SwiftUI
import SwiftData

struct CreateTripView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var friends: [Friend]
    
    @State private var tripName = ""
    @State private var startDate = Date()
    @State private var selectedFriends: Set<PersistentIdentifier> = []
    @State private var showingAddFriend = false
    
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
                    Section {
                        HStack {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundStyle(Color.sunsetOrange)
                            TextField("Trip Name", text: $tripName)
                        }
                        
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundStyle(Color.oceanBlue)
                            DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                        }
                    } header: {
                        Text("Trip Details")
                    }
                    .listRowBackground(Color.cardBackground)
                    
                    if friends.isEmpty {
                        Section {
                            VStack(spacing: 12) {
                                Image(systemName: "person.2.fill")
                                    .font(.largeTitle)
                                    .foregroundStyle(Color.oceanBlue.opacity(0.5))
                                Text("No friends added yet")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                Text("Add friends to quickly create trips")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                Button {
                                    showingAddFriend = true
                                } label: {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Add Friends")
                                    }
                                    .foregroundStyle(Color.oceanBlue)
                                    .fontWeight(.semibold)
                                }
                                .padding(.top, 8)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                        }
                        .listRowBackground(Color.cardBackground)
                    } else {
                        Section {
                            ForEach(friends.sorted(by: { $0.name < $1.name })) { friend in
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(Color.participantColors[friend.color] ?? .blue)
                                        .frame(width: 35, height: 35)
                                    Text(friend.name)
                                        .font(.headline)
                                    Spacer()
                                    if selectedFriends.contains(friend.persistentModelID) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.oceanBlue)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(.gray)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if selectedFriends.contains(friend.persistentModelID) {
                                        selectedFriends.remove(friend.persistentModelID)
                                    } else {
                                        selectedFriends.insert(friend.persistentModelID)
                                    }
                                }
                            }
                            
                            Button {
                                selectedFriends = Set(friends.map { $0.persistentModelID })
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.oceanBlue)
                                    Text("Select All")
                                        .foregroundStyle(Color.oceanBlue)
                                }
                            }
                            
                            Button {
                                showingAddFriend = true
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(Color.sunsetOrange)
                                    Text("Add New Friend")
                                        .foregroundStyle(Color.sunsetOrange)
                                }
                            }
                        } header: {
                            Text("Select Participants")
                        } footer: {
                            Text("Select at least 2 people")
                                .foregroundStyle(.secondary)
                        }
                        .listRowBackground(Color.cardBackground)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.moneyOwed)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createTrip()
                    }
                    .foregroundStyle(Color.oceanBlue)
                    .fontWeight(.semibold)
                    .disabled(tripName.isEmpty || selectedFriends.count < 2)
                }
            }
            .sheet(isPresented: $showingAddFriend) {
                AddFriendView()
            }
        }
    }
    
    private func createTrip() {
        let trip = Trip(name: tripName, startDate: startDate)
        modelContext.insert(trip)
        
        // Create trip participants from selected friends
        let selectedFriendsList = friends.filter { selectedFriends.contains($0.persistentModelID) }
        for friend in selectedFriendsList {
            let person = Person(name: friend.name, color: friend.color)
            person.trip = trip
            trip.participants.append(person)
            modelContext.insert(person)
        }
        
        dismiss()
    }
}
