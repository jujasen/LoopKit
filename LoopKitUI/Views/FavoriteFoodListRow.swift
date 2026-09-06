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
        let absorption = food.absorptionTimeString(formatter: absorptionTimeFormatter)

        if food.hasMultiplePortions {
            return String(
                format: LocalizedString("%1$lld serving sizes · %2$@ absorption", comment: "Summary of a favorite food that has several serving sizes (1: number of serving sizes, 2: absorption time)"),
                food.portions.count,
                absorption
            )
        }

        return String(
            format: LocalizedString("%1$@ carbs · %2$@ absorption", comment: "Summary of a favorite food's carb quantity and absorption time (1: carb quantity, 2: absorption time)"),
            food.carbsString(formatter: carbFormatter),
            absorption
        )
    }

    /// One line describing a single amount, e.g. "Half a slice · 8 g".
    public static func portion(_ portion: FavoriteFoodPortion, carbFormatter: QuantityFormatter) -> String {
        let carbs = portion.carbsString(formatter: carbFormatter)
        return portion.hasName ? "\(portion.name) · \(carbs)" : carbs
    }
}

/// An editable row for one amount of a favorite food: a free-text name and its carb quantity.
public struct FavoriteFoodPortionRow: View {
    @Binding private var name: String
    @Binding private var quantity: Double?
    @Binding private var isNameFocused: Bool
    @Binding private var isQuantityFocused: Bool

    private let namePlaceholder: String
    private let preferredCarbUnit: HKUnit
    private let onDelete: (() -> Void)?

    @State private var carbInput: String = ""

    private let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumIntegerDigits = 3
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    public init(name: Binding<String>, quantity: Binding<Double?>, isNameFocused: Binding<Bool>, isQuantityFocused: Binding<Bool>, namePlaceholder: String, preferredCarbUnit: HKUnit = .gram(), onDelete: (() -> Void)? = nil) {
        self._name = name
        self._quantity = quantity
        self._isNameFocused = isNameFocused
        self._isQuantityFocused = isQuantityFocused
        self.namePlaceholder = namePlaceholder
        self.preferredCarbUnit = preferredCarbUnit
        self.onDelete = onDelete
    }

    public var body: some View {
        HStack(spacing: 8) {
            if let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .font(.body)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(LocalizedString("Remove serving size", comment: "Accessibility label for the button that removes one serving size from a favorite food")))
            }

            RowTextField(text: $name, isFocused: $isNameFocused) {
                $0.textAlignment = .left
                $0.placeholder = namePlaceholder
                $0.font = .preferredFont(forTextStyle: .body)
            }
            .onTapGesture {
                if !isNameFocused {
                    isNameFocused = true
                }
            }

            RowTextField(text: $carbInput, isFocused: $isQuantityFocused, maxLength: 5) {
                $0.textAlignment = .right
                $0.keyboardType = .decimalPad
                $0.placeholder = "0"
                $0.font = .preferredFont(forTextStyle: .body)
            }
            .frame(width: 56)
            .onTapGesture {
                if !isQuantityFocused {
                    isQuantityFocused = true
                }
            }

            Text(QuantityFormatter(for: preferredCarbUnit).localizedUnitStringWithPlurality())
                .foregroundColor(Color(.secondaryLabel))
        }
        .onChange(of: carbInput) { newValue in
            quantity = formatter.number(from: newValue)?.doubleValue
        }
        .onChange(of: quantity) { newQuantity in
            updateCarbInput(with: newQuantity)
        }
        .onAppear {
            updateCarbInput(with: quantity)
        }
    }

    private func updateCarbInput(with newQuantity: Double?) {
        // Leave a partially typed value alone, so "7," does not get rewritten while typing.
        if let value = newQuantity {
            let formatted = formatter.string(from: NSNumber(value: value)) ?? ""
            if formatter.number(from: carbInput)?.doubleValue != value {
                carbInput = formatted
            }
        }
        else if formatter.number(from: carbInput) != nil {
            carbInput = ""
        }
    }
}
