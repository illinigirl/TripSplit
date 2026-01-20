//
//  AddPersonToTripView.swift
//  TripSplitApp
//
//  Created by Megan Schott on 1/20/26.
//

import SwiftUI
import SwiftData

struct AddPersonToTripView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let trip: Trip
    @Query private var friends: [Friend]
    
    @State private var selectedFriend: Friend?
    @State private var showingAddFriend = false
    @State private var manualName = ""
    @State private var manualColor = "blue"
    
    let availableColors = ["coral", "pink", "yellow", "blue", "teal", "purple", "indigo", "green"]
    
    var availableFriends: [Friend] {
        // Filter out friends already in the trip
        friends.filter { friend in
            !trip.participants.contains(where: { $0.name == friend.name })
        }
    }
    
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
                    if !availableFriends.isEmpty {
                        Section("Select from Friends") {
                            ForEach(availableFriends.sorted(by: { $0.name < $1.name })) { friend in
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(Color.participantColors[friend.color] ?? .blue)
                                        .frame(width: 35, height: 35)
                                    Text(friend.name)
                                        .font(.headline)
                                    Spacer()
                                    if selectedFriend == friend {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.oceanBlue)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(.gray)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if selectedFriend == friend {
                                        selectedFriend = nil
                                    } else {
                                        selectedFriend = friend
                                        manualName = "" // Clear manual entry if selecting friend
                                    }
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
                        }
                        .listRowBackground(Color.cardBackground)
                    }
                    
                    Section {
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundStyle(Color.oceanBlue)
                            TextField("Name", text: $manualName)
                                .onChange(of: manualName) { _, _ in
                                    if !manualName.isEmpty {
                                        selectedFriend = nil // Clear friend selection if typing
                                    }
                                }
                        }
                    } header: {
                        Text(availableFriends.isEmpty ? "Add Person" : "Or Add Someone New")
                    }
                    .listRowBackground(Color.cardBackground)
                    
                    if !manualName.isEmpty {
                        Section("Color") {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 16) {
                                ForEach(availableColors, id: \.self) { color in
                                    Button {
                                        manualColor = color
                                    } label: {
                                        ZStack {
                                            Circle()
                                                .fill(Color.participantColors[color] ?? .blue)
                                                .frame(width: 50, height: 50)
                                            
                                            if manualColor == color {
                                                Circle()
                                                    .stroke(Color.primary, lineWidth: 3)
                                                    .frame(width: 56, height: 56)
                                                Image(systemName: "checkmark")
                                                    .foregroundStyle(.white)
                                                    .fontWeight(.bold)
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .listRowBackground(Color.cardBackground)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Add Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.moneyOwed)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addPerson()
                    }
                    .foregroundStyle(Color.oceanBlue)
                    .fontWeight(.semibold)
                    .disabled(!canAdd)
                }
            }
            .sheet(isPresented: $showingAddFriend) {
                AddFriendView()
            }
        }
    }
    
    private var canAdd: Bool {
        if let friend = selectedFriend {
            return true
        }
        return !manualName.isEmpty
    }
    
    private func addPerson() {
        let person: Person
        
        if let friend = selectedFriend {
            // Add from friends list
            person = Person(name: friend.name, color: friend.color)
        } else {
            // Add manually entered person
            person = Person(name: manualName, color: manualColor)
        }
        
        person.trip = trip
        trip.participants.append(person)
        modelContext.insert(person)
        
        try? modelContext.save()
        dismiss()
    }
}
