public final class ErrorObject<Value>: @unchecked Sendable {
    public let value: Value

    public init(value: Value) {
        self.value = value
    }
}
