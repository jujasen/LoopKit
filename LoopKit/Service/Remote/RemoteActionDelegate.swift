//
//  RemoteActionDelegate.swift
//  LoopKit
//
//  Created by Bill Gestrich on 3/19/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

public protocol RemoteActionDelegate: AnyObject {
    func enactRemoteOverride(name: String, durationTime: TimeInterval?, remoteAddress: String) async throws
    func cancelRemoteOverride() async throws
    func deliverRemoteCarbs(amountInGrams: Double, absorptionTime: TimeInterval?, foodType: String?, startDate: Date?) async throws
    func deliverRemoteBolus(amountInUnits: Double) async throws
    func applyRemoteTherapySettings(_ change: RemoteTherapySettingsChange) async throws
}

/// Replacement carb ratio and/or insulin sensitivity schedules sent from a caregiver's phone.
///
/// Each schedule, when present, replaces the whole schedule: times that are missing from it are
/// removed, new times are added. A schedule that is absent is left as it is.
public struct RemoteTherapySettingsChange: Equatable {
    /// Carb ratio schedule items, in grams per unit.
    public let carbRatioItems: [RepeatingScheduleValue<Double>]?
    /// Insulin sensitivity schedule items, in `insulinSensitivityUnit` per unit.
    public let insulinSensitivityItems: [RepeatingScheduleValue<Double>]?
    /// The glucose unit of `insulinSensitivityItems` (mg/dL or mmol/L).
    public let insulinSensitivityUnit: HKUnit?

    /// The most items Loop's own schedule editors allow: one every 30 minutes.
    public static let maximumItemCount = 48

    public init(carbRatioItems: [RepeatingScheduleValue<Double>]?, insulinSensitivityItems: [RepeatingScheduleValue<Double>]?, insulinSensitivityUnit: HKUnit?) throws {
        guard carbRatioItems != nil || insulinSensitivityItems != nil else {
            throw RemoteTherapySettingsError.nothingToChange
        }
        if let carbRatioItems {
            try Self.validateTimes(of: carbRatioItems)
        }
        if let insulinSensitivityItems {
            guard let insulinSensitivityUnit,
                  insulinSensitivityUnit == .milligramsPerDeciliter || insulinSensitivityUnit == .millimolesPerLiter
            else {
                throw RemoteTherapySettingsError.unsupportedGlucoseUnit
            }
            try Self.validateTimes(of: insulinSensitivityItems)
        }

        self.carbRatioItems = carbRatioItems
        self.insulinSensitivityItems = insulinSensitivityItems
        self.insulinSensitivityUnit = insulinSensitivityItems == nil ? nil : insulinSensitivityUnit
    }

    /// A schedule must start at midnight, move forward in whole minutes and stay within the day —
    /// the same shape Loop's editors produce.
    private static func validateTimes(of items: [RepeatingScheduleValue<Double>]) throws {
        guard !items.isEmpty, items.count <= maximumItemCount else {
            throw RemoteTherapySettingsError.invalidSchedule
        }
        guard items.first?.startTime == 0 else {
            throw RemoteTherapySettingsError.invalidSchedule
        }
        var previous: TimeInterval = -1
        for item in items {
            guard item.startTime > previous,
                  item.startTime < .hours(24),
                  item.startTime.truncatingRemainder(dividingBy: 60) == 0,
                  item.value.isFinite
            else {
                throw RemoteTherapySettingsError.invalidSchedule
            }
            previous = item.startTime
        }
    }
}

public enum RemoteTherapySettingsError: LocalizedError, Equatable {
    case nothingToChange
    case invalidSchedule
    case unsupportedGlucoseUnit

    public var errorDescription: String? {
        switch self {
        case .nothingToChange:
            return LocalizedString("No settings to change", comment: "Remote therapy settings error: the command contained no schedule.")
        case .invalidSchedule:
            return LocalizedString("Invalid schedule", comment: "Remote therapy settings error: schedule times are missing, out of order or outside the day.")
        case .unsupportedGlucoseUnit:
            return LocalizedString("Unsupported glucose unit", comment: "Remote therapy settings error: insulin sensitivity unit is not mg/dL or mmol/L.")
        }
    }
}
