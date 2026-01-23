//
//  Item.swift
//  ValueMiner(cursorbuild)
//
//  Created by Michael Alfieri on 1/23/26.
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
