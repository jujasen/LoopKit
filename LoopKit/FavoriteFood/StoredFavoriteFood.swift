//
//  StoredFavoriteFood.swift
//  LoopKit
//
//  Created by Noah Brauner on 8/9/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import HealthKit

public struct StoredFavoriteFood: FavoriteFood, Identifiable {
    public var id: String
    
    public var name: String
    public var foodType: String
    public var absorptionTime: TimeInterval

    /// Every amount this food can be logged at, in the order shown to the user. Never empty.
    public var portions: [FavoriteFoodPortion]

    /// `id` of the `FavoriteFoodFolder` this food is filed under, or `nil` when unfiled.
    public var folderID: String?

    /// When this food was last edited, on whichever device edited it. Decides which side wins
    /// when the same food was changed both here and in a caregiver app between two syncs.
    public var updatedAt: Date

    /// `_id` of the matching Nightscout food document, once the food has been shared.
    public var nsID: String?

    public init(id: String = UUID().uuidString, name: String, portions: [FavoriteFoodPortion], foodType: String, absorptionTime: TimeInterval, folderID: String? = nil, updatedAt: Date = Date(), nsID: String? = nil) {
        self.id = id
        self.name = name
        self.portions = portions.isEmpty ? [FavoriteFoodPortion(carbsQuantity: HKQuantity(unit: .gram(), doubleValue: 0))] : portions
        self.foodType = foodType
        self.absorptionTime = absorptionTime
        self.folderID = folderID
        self.updatedAt = updatedAt
        self.nsID = nsID
    }

    /// Convenience for a food with a single amount.
    public init(id: String = UUID().uuidString, name: String, carbsQuantity: HKQuantity, foodType: String, absorptionTime: TimeInterval, servingSize: String = "", folderID: String? = nil, updatedAt: Date = Date(), nsID: String? = nil) {
        self.init(
            id: id,
            name: name,
            portions: [FavoriteFoodPortion(name: servingSize, carbsQuantity: carbsQuantity)],
            foodType: foodType,
            absorptionTime: absorptionTime,
            folderID: folderID,
            updatedAt: updatedAt,
            nsID: nsID
        )
    }

    /// True when the two describe the same food to a user. Sharing compares content rather than
    /// timestamps before writing, so an unchanged food is never pushed back and forth.
    public func hasSameContent(as other: StoredFavoriteFood) -> Bool {
        id == other.id
            && name == other.name
            && foodType == other.foodType
            && absorptionTime == other.absorptionTime
            && portions == other.portions
            && folderID == other.folderID
    }

    /// The amount applied when the food is picked without choosing one — the first in the list.
    public var defaultPortion: FavoriteFoodPortion {
        portions.first ?? FavoriteFoodPortion(carbsQuantity: HKQuantity(unit: .gram(), doubleValue: 0))
    }

    public var carbsQuantity: HKQuantity {
        defaultPortion.carbsQuantity
    }

    /// A food with several amounts has no single serving size, so this is empty for those.
    public var servingSize: String {
        portions.count == 1 ? defaultPortion.name : ""
    }

    public func portion(withID id: String?) -> FavoriteFoodPortion? {
        guard let id else { return nil }
        return portions.first(where: { $0.id == id })
    }
}

extension StoredFavoriteFood: Equatable {
    public static func == (lhs: StoredFavoriteFood, rhs: StoredFavoriteFood) -> Bool {
        return lhs.id == rhs.id
    }
}

extension StoredFavoriteFood: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let decodedPortions = try container.decodeIfPresent([FavoriteFoodPortion].self, forKey: .portions)
        let portions: [FavoriteFoodPortion]
        if let decodedPortions, !decodedPortions.isEmpty {
            portions = decodedPortions
        }
        else {
            // Foods stored before portions existed carry a single carb quantity and serving size.
            portions = [FavoriteFoodPortion(
                name: try container.decodeIfPresent(String.self, forKey: .servingSize) ?? "",
                carbsQuantity: HKQuantity(unit: .gram(), doubleValue: try container.decode(Double.self, forKey: .carbsQuantity))
            )]
        }

        self.init(
            id: try container.decode(String.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            portions: portions,
            foodType: try container.decode(String.self, forKey: .foodType),
            absorptionTime: try container.decode(TimeInterval.self, forKey: .absorptionTime),
            folderID: try container.decodeIfPresent(String.self, forKey: .folderID),
            // Foods stored before sharing existed count as old, so a shared copy wins once.
            updatedAt: try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .distantPast,
            nsID: try container.decodeIfPresent(String.self, forKey: .nsID)
        )
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(portions, forKey: .portions)
        try container.encode(foodType, forKey: .foodType)
        try container.encode(absorptionTime, forKey: .absorptionTime)
        try container.encodeIfPresent(folderID, forKey: .folderID)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(nsID, forKey: .nsID)
        // Mirrored so a downgrade to a build without portions still reads a usable food.
        try container.encode(carbsQuantity.doubleValue(for: .gram()), forKey: .carbsQuantity)
        try container.encode(servingSize, forKey: .servingSize)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case carbsQuantity
        case foodType
        case absorptionTime
        case servingSize
        case folderID
        case portions
        case updatedAt
        case nsID
    }
}
