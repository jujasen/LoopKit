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
    public var carbsQuantity: HKQuantity
    public var foodType: String
    public var absorptionTime: TimeInterval
    public var servingSize: String
    public var folderID: String?

    public init(name: String, carbsQuantity: HKQuantity, foodType: String, absorptionTime: TimeInterval, servingSize: String = "", folderID: String? = nil) {
        self.name = name
        self.carbsQuantity = carbsQuantity
        self.foodType = foodType
        self.absorptionTime = absorptionTime
        self.servingSize = servingSize
        self.folderID = folderID
    }
}
