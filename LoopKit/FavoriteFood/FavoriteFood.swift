//
//  FavoriteFood.swift
//  LoopKit
//
//  Created by Noah Brauner on 7/13/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import HealthKit

/// One recorded amount of a favorite food, e.g. "half a slice" at 8 g.
///
/// A food always has at least one portion. Foods that come in several sizes — a whole, a half and
/// a quarter slice of bread — carry one portion per size, each with its own carb quantity, so the
/// same food can be logged at different amounts without duplicating it in the register.
public struct FavoriteFoodPortion: Identifiable, Hashable {
    public var id: String

    /// Free-form name for this amount, e.g. "1 slice". May be empty when a food has only one portion.
    public var name: String

    public var carbsQuantity: HKQuantity

    public init(id: String = UUID().uuidString, name: String = "", carbsQuantity: HKQuantity) {
        self.id = id
        self.name = name
        self.carbsQuantity = carbsQuantity
    }

    public var hasName: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public func carbsString(formatter: QuantityFormatter) -> String {
        formatter.string(from: carbsQuantity) ?? ""
    }

    public static func == (lhs: FavoriteFoodPortion, rhs: FavoriteFoodPortion) -> Bool {
        lhs.id == rhs.id
            && lhs.name == rhs.name
            && lhs.carbsQuantity.doubleValue(for: .gram()) == rhs.carbsQuantity.doubleValue(for: .gram())
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(carbsQuantity.doubleValue(for: .gram()))
    }
}

extension FavoriteFoodPortion: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            name: try container.decodeIfPresent(String.self, forKey: .name) ?? "",
            carbsQuantity: HKQuantity(unit: .gram(), doubleValue: try container.decode(Double.self, forKey: .carbsQuantity))
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(carbsQuantity.doubleValue(for: .gram()), forKey: .carbsQuantity)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case carbsQuantity
    }
}

public protocol FavoriteFood {
    var name: String { get }
    var carbsQuantity: HKQuantity { get }
    var foodType: String { get }
    var absorptionTime: TimeInterval { get }

    /// Free-form serving size, e.g. "1 bowl", "2 slices".
    /// Empty when the food has no serving size recorded.
    var servingSize: String { get }

    /// Every amount this food can be logged at. Never empty.
    var portions: [FavoriteFoodPortion] { get }
}

extension FavoriteFood {
    /// Defaults so that conformers predating serving sizes and portions keep compiling.
    public var servingSize: String { "" }

    public var portions: [FavoriteFoodPortion] {
        [FavoriteFoodPortion(name: servingSize, carbsQuantity: carbsQuantity)]
    }

    public var hasServingSize: Bool {
        !servingSize.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// True when picking this food should also ask which amount is being eaten.
    public var hasMultiplePortions: Bool {
        portions.count > 1
    }

    public var title: String {
        return name + " " + foodType
    }

    /// Name and serving size on one line, e.g. "Yoghurt · 1 bowl". Falls back to the name alone.
    public var nameWithServingSize: String {
        hasServingSize ? "\(name) · \(servingSize)" : name
    }

    public func absorptionTimeString(formatter: DateComponentsFormatter) -> String {
        guard let string = formatter.string(from: absorptionTime) else {
            assertionFailure("Unable to format \(String(describing: absorptionTime))")
            return ""
        }
        return string
    }
    
    public func carbsString(formatter: QuantityFormatter) -> String {
        guard let string = formatter.string(from: carbsQuantity) else {
            assertionFailure("Unable to format \(String(describing: carbsQuantity)) into gram format")
            return ""
        }
        return string
    }
}

/// An optional, user-created group that favorite foods can be filed into.
///
/// Folders are purely an organizational overlay: a food's folder membership is stored on the food
/// itself, so a food whose folder is deleted simply becomes unfiled rather than being lost.
public struct FavoriteFoodFolder: Identifiable, Hashable, Codable {
    public var id: String
    public var name: String
    /// Optional emoji shown alongside the folder name.
    public var emoji: String

    public init(id: String = UUID().uuidString, name: String, emoji: String = "") {
        self.id = id
        self.name = name
        self.emoji = emoji
    }

    public var title: String {
        emoji.isEmpty ? name : "\(emoji) \(name)"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            emoji: try container.decodeIfPresent(String.self, forKey: .emoji) ?? ""
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case emoji
    }
}
