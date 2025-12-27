//
//  Item.swift
//  Mneme
//
//  Created by Garren Dullas on 12/27/25.
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
