//
//  AddFriendView.swift
//  TripSplitApp
//
//  Created by Megan Schott on 1/20/26.
//

import SwiftUI
import SwiftData

struct AddFriendView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let friend: Friend?
    
    @State private var name: String
    @State private var selectedColor: String
    @State private var email: String
    @State private var phone: String
    
    let availableColors = ["coral", "pink", "yellow", "blue", "teal", "purple", "indigo", "green"]
    
    init(friend: Friend? = nil) {
        self.friend = friend
        _name = State(initialValue: friend?.name ?? "")
        _selectedColor = State(initialValue: friend?.color ?? "blue")
        _email = State(initialValue: friend?.email ?? "")
        _phone = State(initialValue: friend?.phone ?? "")
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
                    Section {
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundStyle(Color.oceanBlue)
                            TextField("Name", text: $name)
                        }
                    } header: {
                        Text("Friend Details")
                    }
                    .listRowBackground(Color.cardBackground)
                    
                    Section {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundStyle(Color.oceanTeal)
                            TextField("Email (optional)", text: $email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                        }
                        
                        HStack {
                            Image(systemName: "phone.fill")
                                .foregroundStyle(Color.sunsetOrange)
                            TextField("Phone (optional)", text: $phone)
                                .keyboardType(.phonePad)
                        }
                    } header: {
                        Text("Contact Info")
                    } footer: {
                        Text("Optional - for future features like sending trip summaries")
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.cardBackground)
                    
                    Section("Color") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 16) {
                            ForEach(availableColors, id: \.self) { color in
                                Button {
                                    selectedColor = color
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(Color.participantColors[color] ?? .blue)
                                            .frame(width: 50, height: 50)
                                        
                                        if selectedColor == color {
                                            Circle()
                                                .stroke(Color.primary, lineWidth: 3)
                                                .frame(width: 56, height: 56)
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(.white)
                                                .fontWeight(.bold)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)  // Add this line
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(Color.cardBackground)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(friend == nil ? "Add Friend" : "Edit Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.moneyOwed)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(friend == nil ? "Add" : "Save") {
                        saveFriend()
                    }
                    .foregroundStyle(Color.oceanBlue)
                    .fontWeight(.semibold)
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func saveFriend() {
        if let friend = friend {
            // Edit existing friend
            friend.name = name
            friend.color = selectedColor
            friend.email = email.isEmpty ? nil : email
            friend.phone = phone.isEmpty ? nil : phone
        } else {
            // Create new friend
            let newFriend = Friend(
                name: name,
                color: selectedColor,
                email: email.isEmpty ? nil : email,
                phone: phone.isEmpty ? nil : phone
            )
            modelContext.insert(newFriend)
        }
        
        try? modelContext.save()
        dismiss()
    }
}
