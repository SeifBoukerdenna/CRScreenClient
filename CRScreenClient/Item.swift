//
//  Item.swift
//  CRScreenClient
//
//  Created by Malik Macbook on 2025-04-18.
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
