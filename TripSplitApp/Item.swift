//
//  Item.swift
//  TripSplitApp
//
//  Created by Megan Schott on 1/19/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
