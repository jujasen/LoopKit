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
    func editRemoteCarbs(_ edit: RemoteCarbEdit) async throws
}

/// A change to a carb entry the host already has, sent from a caregiver's phone.
///
/// The entry is found by its sync identifier, the `syncIdentifier` the host uploads with each carb
/// treatment. A value that is absent is kept as it is; an empty `foodType` clears it. With `delete`
/// the entry is removed and the other values are ignored. Only the shape is checked here; the host
/// holds the new values to the same limits as a new remote carb entry.
public struct RemoteCarbEdit: Equatable {
    public let syncIdentifier: String
    public let amountInGrams: Double?
    public let absorptionTime: TimeInterval?
    public let foodType: String?
    public let startDate: Date?
    public let delete: Bool

    public init(
        syncIdentifier: String,
        amountInGrams: Double? = nil,
        absorptionTime: TimeInterval? = nil,
        foodType: String? = nil,
        startDate: Date? = nil,
        delete: Bool = false
    ) throws {
        guard !syncIdentifier.isEmpty else {
            throw RemoteCarbEditError.missingSyncIdentifier
        }
        if !delete {
            guard amountInGrams != nil || absorptionTime != nil || foodType != nil || startDate != nil else {
                throw RemoteCarbEditError.nothingToChange
            }
            guard [amountInGrams, absorptionTime].compactMap({ $0 }).allSatisfy(\.isFinite) else {
                throw RemoteCarbEditError.invalidValue
            }
        }

        self.syncIdentifier = syncIdentifier
        self.amountInGrams = delete ? nil : amountInGrams
        self.absorptionTime = delete ? nil : absorptionTime
        self.foodType = delete ? nil : foodType
        self.startDate = delete ? nil : startDate
        self.delete = delete
    }
}

public enum RemoteCarbEditError: LocalizedError, Equatable {
    case missingSyncIdentifier
    case nothingToChange
    case invalidValue
    case entryNotFound
    case entryNotEditable

    public var errorDescription: String? {
        switch self {
        case .missingSyncIdentifier:
            return LocalizedString("No carb entry given", comment: "Remote carb edit error: the command did not say which carb entry to change.")
        case .nothingToChange:
            return LocalizedString("No changes to the carb entry", comment: "Remote carb edit error: the command contained no new value.")
        case .invalidValue:
            return LocalizedString("Invalid value", comment: "Remote carb edit error: a value is not a finite number.")
        case .entryNotFound:
            return LocalizedString("The carb entry was not found", comment: "Remote carb edit error: no recent carb entry has the given sync identifier.")
        case .entryNotEditable:
            return LocalizedString("The carb entry was made by another app and cannot be changed", comment: "Remote carb edit error: the carb entry was not created by Loop.")
        }
    }
}

/// Therapy settings sent from a caregiver's phone.
///
/// Each schedule, when present, replaces the whole schedule: times that are missing from it are
/// removed, new times are added. The override preset list, when present, replaces the whole list.
/// A setting that is absent is left as it is. Only the shape is checked here; the host checks every
/// value against its guardrails before saving anything.
public struct RemoteTherapySettingsChange: Equatable {

    /// An override preset as the caregiver app describes it.
    public struct OverridePreset: Equatable {
        public let name: String
        public let symbol: String
        /// Seconds; 0 means indefinite.
        public let duration: TimeInterval
        public let insulinNeedsScaleFactor: Double
        /// In the change's `glucoseUnit`; nil leaves the correction range alone.
        public let targetRange: DoubleRange?

        public init(name: String, symbol: String, duration: TimeInterval, insulinNeedsScaleFactor: Double = 1.0, targetRange: DoubleRange? = nil) {
            self.name = name
            self.symbol = symbol
            self.duration = duration
            self.insulinNeedsScaleFactor = insulinNeedsScaleFactor
            self.targetRange = targetRange
        }
    }

    /// Carb ratio schedule items, in grams per unit.
    public let carbRatioItems: [RepeatingScheduleValue<Double>]?
    /// Insulin sensitivity schedule items, in `insulinSensitivityUnit` per unit.
    public let insulinSensitivityItems: [RepeatingScheduleValue<Double>]?
    /// The glucose unit of `insulinSensitivityItems` (mg/dL or mmol/L).
    public let insulinSensitivityUnit: HKUnit?

    /// The glucose unit (mg/dL or mmol/L) of the correction, pre-meal, workout and override ranges
    /// and the suspend threshold.
    public let glucoseUnit: HKUnit?
    /// Basal rate schedule items, in units per hour.
    public let basalRateItems: [RepeatingScheduleValue<Double>]?
    /// Correction range schedule items, in `glucoseUnit`.
    public let correctionRangeItems: [RepeatingScheduleValue<DoubleRange>]?
    /// In `glucoseUnit`.
    public let preMealTargetRange: DoubleRange?
    /// In `glucoseUnit`.
    public let workoutTargetRange: DoubleRange?
    /// The glucose safety limit, in `glucoseUnit`.
    public let suspendThreshold: Double?
    /// Units per hour.
    public let maximumBasalRatePerHour: Double?
    /// Units.
    public let maximumBolus: Double?
    public let insulinModel: ExponentialInsulinModelPreset?
    public let dosingStrategy: AutomaticDosingStrategy?
    public let closedLoop: Bool?
    public let overridePresets: [OverridePreset]?
    public let glucoseBasedPartialApplication: Bool?
    public let integralRetrospectiveCorrection: Bool?

    /// The most items Loop's own schedule editors allow: one every 30 minutes.
    public static let maximumItemCount = 48

    public init(
        carbRatioItems: [RepeatingScheduleValue<Double>]? = nil,
        insulinSensitivityItems: [RepeatingScheduleValue<Double>]? = nil,
        insulinSensitivityUnit: HKUnit? = nil,
        glucoseUnit: HKUnit? = nil,
        basalRateItems: [RepeatingScheduleValue<Double>]? = nil,
        correctionRangeItems: [RepeatingScheduleValue<DoubleRange>]? = nil,
        preMealTargetRange: DoubleRange? = nil,
        workoutTargetRange: DoubleRange? = nil,
        suspendThreshold: Double? = nil,
        maximumBasalRatePerHour: Double? = nil,
        maximumBolus: Double? = nil,
        insulinModel: ExponentialInsulinModelPreset? = nil,
        dosingStrategy: AutomaticDosingStrategy? = nil,
        closedLoop: Bool? = nil,
        overridePresets: [OverridePreset]? = nil,
        glucoseBasedPartialApplication: Bool? = nil,
        integralRetrospectiveCorrection: Bool? = nil
    ) throws {
        let changesGlucose = correctionRangeItems != nil || preMealTargetRange != nil || workoutTargetRange != nil || suspendThreshold != nil
            || overridePresets?.contains(where: { $0.targetRange != nil }) == true
        let changesAnything = carbRatioItems != nil || insulinSensitivityItems != nil || basalRateItems != nil || changesGlucose
            || maximumBasalRatePerHour != nil || maximumBolus != nil || insulinModel != nil || dosingStrategy != nil
            || closedLoop != nil || overridePresets != nil || glucoseBasedPartialApplication != nil || integralRetrospectiveCorrection != nil
        guard changesAnything else {
            throw RemoteTherapySettingsError.nothingToChange
        }
        if let carbRatioItems {
            try Self.validateTimes(of: carbRatioItems, valueIsFinite: \.isFinite)
        }
        if let insulinSensitivityItems {
            guard let insulinSensitivityUnit, Self.isGlucoseUnit(insulinSensitivityUnit) else {
                throw RemoteTherapySettingsError.unsupportedGlucoseUnit
            }
            try Self.validateTimes(of: insulinSensitivityItems, valueIsFinite: \.isFinite)
        }
        if let basalRateItems {
            try Self.validateTimes(of: basalRateItems, valueIsFinite: \.isFinite)
        }
        if changesGlucose {
            guard let glucoseUnit, Self.isGlucoseUnit(glucoseUnit) else {
                throw RemoteTherapySettingsError.unsupportedGlucoseUnit
            }
        }
        if let correctionRangeItems {
            try Self.validateTimes(of: correctionRangeItems, valueIsFinite: { $0.minValue.isFinite && $0.maxValue.isFinite })
        }
        let numbers = [preMealTargetRange?.minValue, preMealTargetRange?.maxValue, workoutTargetRange?.minValue, workoutTargetRange?.maxValue,
                       suspendThreshold, maximumBasalRatePerHour, maximumBolus].compactMap { $0 }
            + (overridePresets ?? []).flatMap { [$0.duration, $0.insulinNeedsScaleFactor, $0.targetRange?.minValue, $0.targetRange?.maxValue].compactMap { $0 } }
        guard numbers.allSatisfy(\.isFinite) else {
            throw RemoteTherapySettingsError.invalidValue
        }

        self.carbRatioItems = carbRatioItems
        self.insulinSensitivityItems = insulinSensitivityItems
        self.insulinSensitivityUnit = insulinSensitivityItems == nil ? nil : insulinSensitivityUnit
        self.glucoseUnit = changesGlucose ? glucoseUnit : nil
        self.basalRateItems = basalRateItems
        self.correctionRangeItems = correctionRangeItems
        self.preMealTargetRange = preMealTargetRange
        self.workoutTargetRange = workoutTargetRange
        self.suspendThreshold = suspendThreshold
        self.maximumBasalRatePerHour = maximumBasalRatePerHour
        self.maximumBolus = maximumBolus
        self.insulinModel = insulinModel
        self.dosingStrategy = dosingStrategy
        self.closedLoop = closedLoop
        self.overridePresets = overridePresets
        self.glucoseBasedPartialApplication = glucoseBasedPartialApplication
        self.integralRetrospectiveCorrection = integralRetrospectiveCorrection
    }

    /// Whether the change touches nothing but the carb ratio and insulin sensitivity schedules.
    public var onlyChangesCarbRatioOrInsulinSensitivity: Bool {
        return basalRateItems == nil && correctionRangeItems == nil && preMealTargetRange == nil && workoutTargetRange == nil
            && suspendThreshold == nil && maximumBasalRatePerHour == nil && maximumBolus == nil && insulinModel == nil
            && dosingStrategy == nil && closedLoop == nil && overridePresets == nil
            && glucoseBasedPartialApplication == nil && integralRetrospectiveCorrection == nil
    }

    private static func isGlucoseUnit(_ unit: HKUnit) -> Bool {
        return unit == .milligramsPerDeciliter || unit == .millimolesPerLiter
    }

    /// A schedule must start at midnight, move forward in whole minutes and stay within the day —
    /// the same shape Loop's editors produce.
    private static func validateTimes<T>(of items: [RepeatingScheduleValue<T>], valueIsFinite: (T) -> Bool) throws {
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
                  valueIsFinite(item.value)
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
    case invalidValue
    case unknownInsulinModel(String)
    case unknownDosingStrategy(String)
    case incompleteOverrideTargetRange(String)

    public var errorDescription: String? {
        switch self {
        case .nothingToChange:
            return LocalizedString("No settings to change", comment: "Remote therapy settings error: the command contained no setting.")
        case .invalidSchedule:
            return LocalizedString("Invalid schedule", comment: "Remote therapy settings error: schedule times are missing, out of order or outside the day.")
        case .unsupportedGlucoseUnit:
            return LocalizedString("Unsupported glucose unit", comment: "Remote therapy settings error: glucose unit is missing or not mg/dL or mmol/L.")
        case .invalidValue:
            return LocalizedString("Invalid value", comment: "Remote therapy settings error: a value is not a finite number.")
        case .unknownInsulinModel(let name):
            return String(format: LocalizedString("Unknown insulin model: %1$@", comment: "Remote therapy settings error: unknown insulin model (1: the name sent)."), name)
        case .unknownDosingStrategy(let name):
            return String(format: LocalizedString("Unknown dosing strategy: %1$@", comment: "Remote therapy settings error: unknown dosing strategy (1: the name sent)."), name)
        case .incompleteOverrideTargetRange(let name):
            return String(format: LocalizedString("Override preset %1$@ needs both a low and a high target", comment: "Remote therapy settings error: an override preset has only one target bound (1: preset name)."), name)
        }
    }
}
