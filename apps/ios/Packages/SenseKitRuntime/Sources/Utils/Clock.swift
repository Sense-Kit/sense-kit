import Foundation

public protocol Clock: Sendable {
    func now() -> Date
}

public struct SystemClock: Clock {
    public init() {}

    public func now() -> Date {
        Date()
    }
}

public struct FixedClock: Clock {
    private let currentDate: Date

    public init(currentDate: Date) {
        self.currentDate = currentDate
    }

    public func now() -> Date {
        currentDate
    }
}

