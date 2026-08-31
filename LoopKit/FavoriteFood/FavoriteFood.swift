//
//  FavoriteFood.swift
//  LoopKit
//
//  Created by Noah Brauner on 7/13/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import HealthKit

public protocol FavoriteFood {
    var name: String { get }
    var carbsQuantity: HKQuantity { get }
    var foodType: String { get }
    var absorptionTime: TimeInterval { get }

    /// Free-form serving size, e.g. "1 bowl", "2 slices", "half a banana".
    /// Empty when the food has no serving size recorded.
    var servingSize: String { get }
}

extension FavoriteFood {
    /// Default so that conformers predating serving sizes keep compiling.
    public var servingSize: String { "" }

    public var hasServingSize: Bool {
        !servingSize.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
