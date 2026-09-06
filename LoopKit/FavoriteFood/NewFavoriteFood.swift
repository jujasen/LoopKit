//
//  NewFavoriteFood.swift
//  LoopKit
//
//  Created by Noah Brauner on 8/9/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import HealthKit

public struct NewFavoriteFood: FavoriteFood {
    public var name: String
    public var foodType: String
    public var absorptionTime: TimeInterval
    public var portions: [FavoriteFoodPortion]
    public var folderID: String?

    public init(name: String, portions: [FavoriteFoodPortion], foodType: String, absorptionTime: TimeInterval, folderID: String? = nil) {
        self.name = name
        self.portions = portions.isEmpty ? [FavoriteFoodPortion(carbsQuantity: HKQuantity(unit: .gram(), doubleValue: 0))] : portions
        self.foodType = foodType
        self.absorptionTime = absorptionTime
        self.folderID = folderID
    }

    /// Convenience for a food with a single amount.
    public init(name: String, carbsQuantity: HKQuantity, foodType: String, absorptionTime: TimeInterval, servingSize: String = "", folderID: String? = nil) {
        self.init(
            name: name,
            portions: [FavoriteFoodPortion(name: servingSize, carbsQuantity: carbsQuantity)],
            foodType: foodType,
            absorptionTime: absorptionTime,
            folderID: folderID
        )
    }

    public var carbsQuantity: HKQuantity {
        portions.first?.carbsQuantity ?? HKQuantity(unit: .gram(), doubleValue: 0)
    }

    public var servingSize: String {
        portions.count == 1 ? (portions.first?.name ?? "") : ""
    }
}
