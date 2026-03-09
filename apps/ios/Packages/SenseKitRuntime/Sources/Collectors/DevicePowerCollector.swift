import Foundation

#if os(iOS) && canImport(UIKit)
import UIKit

@MainActor
public final class DevicePowerCollector: ContextSignalCollector {
    private let device: UIDevice
    private let signalHandler: SignalHandler
    private var previousBatteryState: UIDevice.BatteryState

    public init(device: UIDevice = .current, signalHandler: @escaping SignalHandler) {
        self.device = device
        self.signalHandler = signalHandler
        self.previousBatteryState = device.batteryState
    }

    public func start() async {
        device.isBatteryMonitoringEnabled = true
        previousBatteryState = device.batteryState
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBatteryStateChange),
            name: UIDevice.batteryStateDidChangeNotification,
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
        defer { previousBatteryState = current }
        guard previousBatteryState.isCharging, !current.isCharging else { return }

        Task {
            await signalHandler(
                ContextSignal(
                    signalKey: "power.charger_disconnected_recently",
                    source: "uidevice_battery",
                    weight: 0.10,
                    polarity: .support,
                    observedAt: Date(),
                    validForSec: 90
                )
            )
        }
    }
}

private extension UIDevice.BatteryState {
    var isCharging: Bool {
        self == .charging || self == .full
    }
}
#else
public final class DevicePowerCollector: ContextSignalCollector {
    public init(signalHandler: @escaping SignalHandler) {}
    public func start() async {}
    public func stop() {}
}
#endif
