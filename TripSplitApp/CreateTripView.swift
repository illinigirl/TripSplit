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
    
    @State private var tripName = ""
    @State private var startDate = Date()
    @State private var participantNames: [String] = [""]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Trip Details") {
                    TextField("Trip Name", text: $tripName)
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                }
                
                Section("Participants") {
                    ForEach(participantNames.indices, id: \.self) { index in
                        HStack {
                            TextField("Name", text: $participantNames[index])
                            if participantNames.count > 1 {
                                Button(role: .destructive) {
                                    participantNames.remove(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                }
                            }
                        }
                    }
                    
                    Button("Add Person") {
                        participantNames.append("")
                    }
                }
            }
            .navigationTitle("New Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createTrip()
                    }
                    .disabled(tripName.isEmpty || participantNames.filter { !$0.isEmpty }.count < 2)
                }
            }
        }
    }
    
    private func createTrip() {
        let trip = Trip(name: tripName, startDate: startDate)
        modelContext.insert(trip)
        
        let colors = ["blue", "green", "orange", "purple", "pink", "red", "teal"]
        for (index, name) in participantNames.filter({ !$0.isEmpty }).enumerated() {
            let person = Person(name: name, color: colors[index % colors.count])
            person.trip = trip
            trip.participants.append(person)
            modelContext.insert(person)
        }
        
        dismiss()
    }
}
