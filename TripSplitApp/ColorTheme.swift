//
//  ColorTheme.swift
//  TripSplitApp
//
//  Created by Megan Schott on 1/20/26.
//

import SwiftUI

extension Color {
    // Sunset/Ocean Palette
    static let sunsetOrange = Color(red: 1.0, green: 0.42, blue: 0.33)      // Coral
    static let sunsetPink = Color(red: 1.0, green: 0.56, blue: 0.66)        // Soft pink
    static let sunsetYellow = Color(red: 1.0, green: 0.85, blue: 0.24)      // Golden
    static let oceanBlue = Color(red: 0.20, green: 0.60, blue: 0.86)        // Sky blue
    static let oceanTeal = Color(red: 0.18, green: 0.73, blue: 0.78)        // Teal
    static let oceanDeep = Color(red: 0.13, green: 0.37, blue: 0.58)        // Deep ocean
    
    // UI Colors
    static let cardBackground = Color(.systemBackground)
    static let secondaryBackground = Color(.secondarySystemBackground)
    
    // Keep intuitive red/green for money
    static let moneyOwed = Color.red
    static let moneyOwing = Color.green
    
    // Participant colors (vibrant set)
    static let participantColors: [String: Color] = [
        "coral": sunsetOrange,
        "pink": sunsetPink,
        "yellow": sunsetYellow,
        "blue": oceanBlue,
        "teal": oceanTeal,
        "purple": Color(red: 0.68, green: 0.47, blue: 0.96),
        "indigo": Color(red: 0.35, green: 0.34, blue: 0.84),
        "green": Color(red: 0.20, green: 0.78, blue: 0.35)
    ]
}
