import Foundation
import APIKit

final class TestSessionTask: SessionTask {

    let handler: @Sendable (Data?, URLResponse?, Error?) -> Void
    let cancelled = UncheckedSendableBox(value: false)

    init(handler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) {
        self.handler = handler
    }

    func resume() {

    }

    func cancel() {
        cancelled.value = true
    }
}
