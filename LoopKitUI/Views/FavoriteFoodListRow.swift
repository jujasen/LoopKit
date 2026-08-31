//
//  FavoriteFoodListRow.swift
//  LoopKitUI
//
//  Created by Noah Brauner on 8/9/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import HealthKit

public struct FavoriteFoodListRow: View {
    @Environment(\.editMode) var editMode
    @Environment(\.carbTintColor) var carbTintColor

    let food: StoredFavoriteFood
    @Binding var foodToConfirmDeleteId: String?
    
    let onTap: (StoredFavoriteFood) -> ()
    let onDelete: (StoredFavoriteFood) -> ()
    
    let carbFormatter: QuantityFormatter
    let absorptionTimeFormatter: DateComponentsFormatter
    let preferredCarbUnit: HKUnit

    public init(food: StoredFavoriteFood, foodToConfirmDeleteId: Binding<String?>, onFoodTap: @escaping (StoredFavoriteFood) -> Void, onFoodDelete: @escaping (StoredFavoriteFood) -> Void, carbFormatter: QuantityFormatter, absorptionTimeFormatter: DateComponentsFormatter, preferredCarbUnit: HKUnit = .gram()) {
        self.food = food
        self._foodToConfirmDeleteId = foodToConfirmDeleteId
        self.onTap = onFoodTap
        self.onDelete = onFoodDelete
        self.carbFormatter = carbFormatter
        self.absorptionTimeFormatter = absorptionTimeFormatter
        self.preferredCarbUnit = preferredCarbUnit
    }
    
    public var body: some View {
        let isEditing = editMode?.wrappedValue == .active
        let isConfirmingDelete = foodToConfirmDeleteId == food.id
        
        HStack(spacing: 0) {
            if isEditing {
                deleteButton
                    .onTapGesture {
                        if isConfirmingDelete {
                            onDelete(food)
                        }
                        else {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                foodToConfirmDeleteId = food.id
                            }
                        }
                    }
            }
                        
            HStack(spacing: 12) {
                FavoriteFoodEmojiTile(emoji: food.foodType, tint: carbTintColor)

                foodCardContent
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isEditing {
                    editBars
                }
                else {
                    disclosure
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap(food)
            }
        }
    }
}

extension FavoriteFoodListRow {
    private var foodCardContent: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(food.name)
                .font(.body.weight(.semibold))
                .foregroundColor(.primary)

            if food.hasServingSize {
                Text(food.servingSize)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text(FavoriteFoodSummary.carbsAndAbsorption(for: food, carbFormatter: carbFormatter, absorptionTimeFormatter: absorptionTimeFormatter))
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }
    
    private var deleteButton: some View {
        let isEditing = editMode?.wrappedValue == .active
        let isConfirmingDelete = foodToConfirmDeleteId == food.id
        
        return ZStack {
            Color.red
                .clipShape(RoundedRectangle(cornerRadius: isConfirmingDelete ? 0 : 12.5, style: .continuous))
                .frame(width: isConfirmingDelete ? nil : 25, height: isConfirmingDelete ? nil : 25)
            
            if isConfirmingDelete {
                Text("Delete")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
            }
            else {
                Image(systemName: "minus")
                    .font(.footnote.weight(.bold))
                    .foregroundColor(.white)
            }
        }
        .frame(width: isEditing ? isConfirmingDelete ? 72 : 45 : 0, alignment: .trailing)
        .contentShape(Rectangle())
    }
    
    private var disclosure: some View {
        Image(systemName: "chevron.forward")
            .font(.footnote.weight(.semibold))
            .foregroundColor(Color(UIColor.tertiaryLabel))
    }
    
    private var editBars: some View {
        Image(systemName: "line.3.horizontal")
            .foregroundColor(Color(UIColor.tertiaryLabel))
            .font(.title2)
    }
}

/// The emoji a favorite food was saved with, shown on a soft tinted tile.
public struct FavoriteFoodEmojiTile: View {
    private let emoji: String
    private let tint: Color
    private let size: CGFloat

    public init(emoji: String, tint: Color = .green, size: CGFloat = 42) {
        self.emoji = emoji
        self.tint = tint
        self.size = size
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.29, style: .continuous)
                .fill(tint.opacity(0.14))

            if emoji.isEmpty {
                Image(systemName: "fork.knife")
                    .font(.system(size: size * 0.42, weight: .medium))
                    .foregroundColor(tint)
            }
            else {
                Text(emoji)
                    .font(.system(size: size * 0.48))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Shared, localized summaries of a favorite food, so every surface describes a food the same way.
public enum FavoriteFoodSummary {
    public static func carbsAndAbsorption(for food: FavoriteFood, carbFormatter: QuantityFormatter, absorptionTimeFormatter: DateComponentsFormatter) -> String {
        String(
            format: LocalizedString("%1$@ carbs · %2$@ absorption", comment: "Summary of a favorite food's carb quantity and absorption time (1: carb quantity, 2: absorption time)"),
            food.carbsString(formatter: carbFormatter),
            food.absorptionTimeString(formatter: absorptionTimeFormatter)
        )
    }
}
