import Foundation

#if os(iOS) && canImport(UIKit)
import UIKit

@MainActor
public final class DevicePowerCollector: ContextSignalCollector {
    private let device: UIDevice
    private let signalHandler: SignalHandler
    private var previousBatteryState: UIDevice.BatteryState
    private var previousBatteryLevelPercent: Int?

    public init(device: UIDevice = .current, signalHandler: @escaping SignalHandler) {
        self.device = device
        self.signalHandler = signalHandler
        self.previousBatteryState = device.batteryState
        self.previousBatteryLevelPercent = Self.batteryLevelPercent(for: device)
    }

    public func start() async {
        device.isBatteryMonitoringEnabled = true
        previousBatteryState = device.batteryState
        previousBatteryLevelPercent = Self.batteryLevelPercent(for: device)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBatteryStateChange),
            name: UIDevice.batteryStateDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBatteryLevelChange),
            name: UIDevice.batteryLevelDidChangeNotification,
            object: nil
        )
    }

    public func stop() {
        NotificationCenter.default.removeObserver(self)
        device.isBatteryMonitoringEnabled = false
    }

    @objc
    private func handleBatteryStateChange() {
        let current = device.batteryState
        let observedAt = Date()
        let previous = previousBatteryState
        previousBatteryState = current

        Task {
            await signalHandler(
                ContextSignal(
                    signalKey: "power.battery_state_changed",
                    collector: .power,
                    source: "uidevice_battery",
                    weight: 1.0,
                    polarity: .support,
                    observedAt: observedAt,
                    receivedAt: observedAt,
                    validForSec: 120,
                    payload: [
                        "previous_state": .string(previous.rawSignalValue),
                        "current_state": .string(current.rawSignalValue),
                        "battery_level": Self.batteryLevelValue(for: device),
                        "battery_level_percent": Self.batteryLevelPercentValue(for: device),
                        "is_charging": .bool(current.isCharging)
                    ]
                )
            )
        }
    }

    @objc
    private func handleBatteryLevelChange() {
        guard let currentPercent = Self.batteryLevelPercent(for: device) else {
            previousBatteryLevelPercent = nil
            return
        }
        guard previousBatteryLevelPercent != currentPercent else {
            return
        }

        previousBatteryLevelPercent = currentPercent
        let observedAt = Date()

        Task {
            await signalHandler(
                ContextSignal(
                    signalKey: "power.battery_level_observed",
                    collector: .power,
                    source: "uidevice_battery",
                    weight: 1.0,
                    polarity: .support,
                    observedAt: observedAt,
                    receivedAt: observedAt,
                    validForSec: 300,
                    payload: [
                        "battery_level": Self.batteryLevelValue(for: device),
                        "battery_level_percent": .number(Double(currentPercent)),
                        "battery_state": .string(device.batteryState.rawSignalValue),
                        "is_charging": .bool(device.batteryState.isCharging)
                    ]
                )
            )
        }
    }

    private static func batteryLevelValue(for device: UIDevice) -> JSONValue {
        let level = device.batteryLevel
        guard level >= 0 else {
            return .null
        }
        return .number(Double(level))
    }

    private static func batteryLevelPercent(for device: UIDevice) -> Int? {
        let level = device.batteryLevel
        guard level >= 0 else {
            return nil
        }
        return Int((Double(level) * 100).rounded())
    }

    private static func batteryLevelPercentValue(for device: UIDevice) -> JSONValue {
        guard let percent = batteryLevelPercent(for: device) else {
            return .null
        }
        return .number(Double(percent))
    }
}

private extension UIDevice.BatteryState {
    var isCharging: Bool {
        self == .charging || self == .full
    }

    var rawSignalValue: String {
        switch self {
        case .unknown:
            return "unknown"
        case .unplugged:
            return "unplugged"
        case .charging:
            return "charging"
        case .full:
            return "full"
        @unknown default:
            return "unknown"
        }
    }
}
#else
public final class DevicePowerCollector: ContextSignalCollector {
    public init(signalHandler: @escaping SignalHandler) {}
    public func start() async {}
    public func stop() {}
}
#endif
