//
//  Item.swift
//  Kitten Narrator
//
//  Created by Zabir Raihan on 16/04/2026.
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
