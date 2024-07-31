public final class UncheckedSendableBox<Value>: @unchecked Sendable {
    public var value: Value

    public init(value: Value) {
        self.value = value
    }
}

final class UncheckedSendableWeakBox<Value: AnyObject>: @unchecked Sendable {
    weak var value: Value?

    init(value: Value?) {
        self.value = value
    }
}
