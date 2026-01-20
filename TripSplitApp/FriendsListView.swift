//
//  FriendsListView.swift
//  TripSplitApp
//
//  Created by Megan Schott on 1/20/26.
//

import SwiftUI
import SwiftData

struct FriendsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var friends: [Friend]
    @State private var showingAddFriend = false
    @State private var editingFriend: Friend?
    
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [Color.sunsetOrange.opacity(0.35), Color.oceanBlue.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if friends.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.oceanBlue)
                    Text("No friends yet")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Tap + to add your first friend")
                        .foregroundStyle(.secondary)
                }
            } else {
                List {
                    ForEach(friends.sorted(by: { $0.name < $1.name })) { friend in
                        Button {
                            editingFriend = friend
                        } label: {
                            HStack(spacing: 16) {
                                Circle()
                                    .fill(Color.participantColors[friend.color] ?? .blue)
                                    .frame(width: 50, height: 50)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(friend.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    
                                    if let email = friend.email, !email.isEmpty {
                                        HStack(spacing: 4) {
                                            Image(systemName: "envelope.fill")
                                                .font(.caption)
                                            Text(email)
                                                .font(.caption)
                                        }
                                        .foregroundStyle(.secondary)
                                    }
                                    
                                    if let phone = friend.phone, !phone.isEmpty {
                                        HStack(spacing: 4) {
                                            Image(systemName: "phone.fill")
                                                .font(.caption)
                                            Text(phone)
                                                .font(.caption)
                                        }
                                        .foregroundStyle(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .onDelete(perform: deleteFriends)
                    .listRowBackground(Color.cardBackground)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Friends")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddFriend = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.sunsetOrange)
                }
            }
        }
        .sheet(isPresented: $showingAddFriend) {
            AddFriendView()
        }
        .sheet(item: $editingFriend) { friend in
            AddFriendView(friend: friend)
        }
    }
    
    private func deleteFriends(at offsets: IndexSet) {
        let sortedFriends = friends.sorted(by: { $0.name < $1.name })
        for index in offsets {
            let friend = sortedFriends[index]
            modelContext.delete(friend)
        }
    }
}
