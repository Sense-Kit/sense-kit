import Foundation

public typealias SignalHandler = @Sendable (ContextSignal) async -> Void

@MainActor
public protocol ContextSignalCollector: AnyObject {
    func start() async
    func stop()
}
