import Foundation

extension URLSessionTask: SessionTask {

}

private let dataTaskResponseBufferKey = UncheckedSendableBox(value: 0)
private let taskAssociatedObjectCompletionHandlerKey = UncheckedSendableBox(value: 0)

/// `URLSessionAdapter` connects `URLSession` with `Session`.
///
/// If you want to add custom behavior of `URLSession` by implementing delegate methods defined in
/// `URLSessionDelegate` and related protocols, define a subclass of `URLSessionAdapter` and implement
/// delegate methods that you want to implement. Since `URLSessionAdapter` also implements delegate methods
/// `URLSession(_:task: didCompleteWithError:)` and `URLSession(_:dataTask:didReceiveData:)`, you have to call
/// `super` in these methods if you implement them.
open class URLSessionAdapter: NSObject, SessionAdapter, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate {
    /// The underlying `URLSession` instance.
    open var urlSession: URLSession!

    /// Returns `URLSessionAdapter` initialized with `URLSessionConfiguration`.
    public init(configuration: URLSessionConfiguration) {
        super.init()
        self.urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }

    /// Creates `URLSessionDataTask` instance using `dataTaskWithRequest(_:completionHandler:)`.
    open func createTask(with URLRequest: URLRequest, handler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> SessionTask {
        let task = urlSession.dataTask(with: URLRequest)

        setBuffer(NSMutableData(), forTask: task)
        setHandler(handler, forTask: task)

        return task
    }

    /// Aggregates `URLSessionTask` instances in `URLSession` using `getTasksWithCompletionHandler(_:)`.
    open func getTasks(with handler: @escaping @Sendable ([SessionTask]) -> Void) {
        urlSession.getTasksWithCompletionHandler { dataTasks, uploadTasks, downloadTasks in
            let allTasks: [URLSessionTask] = dataTasks + uploadTasks + downloadTasks
            handler(allTasks)
        }
    }

    private func setBuffer(_ buffer: NSMutableData, forTask task: URLSessionTask) {
        objc_setAssociatedObject(task, &dataTaskResponseBufferKey.value, buffer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private func buffer(for task: URLSessionTask) -> NSMutableData? {
        return objc_getAssociatedObject(task, &dataTaskResponseBufferKey.value) as? NSMutableData
    }

    private func setHandler(_ handler: @escaping (Data?, URLResponse?, Error?) -> Void, forTask task: URLSessionTask) {
        objc_setAssociatedObject(task, &taskAssociatedObjectCompletionHandlerKey.value, handler as Any, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private func handler(for task: URLSessionTask) -> ((Data?, URLResponse?, Error?) -> Void)? {
        return objc_getAssociatedObject(task, &taskAssociatedObjectCompletionHandlerKey.value) as? (Data?, URLResponse?, Error?) -> Void
    }

    // MARK: URLSessionTaskDelegate
    open func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        handler(for: task)?(buffer(for: task) as Data?, task.response, error)
    }

    // MARK: URLSessionDataDelegate
    open func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        buffer(for: dataTask)?.append(data)
    }
}
