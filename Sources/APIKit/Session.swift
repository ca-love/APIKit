import Foundation

private let taskRequestKey = UncheckedSendableBox(value: 0)

/// `Session` manages tasks for HTTP/HTTPS requests.
open class Session {
    /// The adapter that connects `Session` instance and lower level backend.
    public let adapter: SessionAdapter

    /// The default callback queue for `send(_:handler:)`.
    public let callbackQueue: CallbackQueue

    /// Returns `Session` instance that is initialized with `adapter`.
    /// - parameter adapter: The adapter that connects lower level backend with Session interface.
    /// - parameter callbackQueue: The default callback queue for `send(_:handler:)`.
    public init(adapter: SessionAdapter, callbackQueue: CallbackQueue = .main) {
        self.adapter = adapter
        self.callbackQueue = callbackQueue
    }

    // Shared session for class methods
    private static let privateShared: UncheckedSendableBox<Session> = {
        let configuration = URLSessionConfiguration.default
        let adapter = URLSessionAdapter(configuration: configuration)
        return UncheckedSendableBox(value: Session(adapter: adapter))
    }()

    /// The shared `Session` instance for class methods, `Session.send(_:handler:)` and `Session.cancelRequests(with:passingTest:)`.
    open class var shared: Session {
        return privateShared.value
    }

    /// Calls `send(_:callbackQueue:handler:)` of `Session.shared`.
    /// - parameter request: The request to be sent.
    /// - parameter callbackQueue: The queue where the handler runs. If this parameters is `nil`, default `callbackQueue` of `Session` will be used.
    /// - parameter handler: The closure that receives result of the request.
    /// - returns: The new session task.
    @discardableResult
    open class func send<Request: APIKit.Request>(_ request: Request, callbackQueue: CallbackQueue? = nil, handler: @escaping @Sendable (Result<Request.Response, SessionTaskError>) -> Void = { _ in }) -> SessionTask? {
        return shared.send(request, callbackQueue: callbackQueue, handler: handler)
    }

    /// Calls `cancelRequests(with:passingTest:)` of `Session.shared`.
    open class func cancelRequests<Request: APIKit.Request>(with requestType: Request.Type, passingTest test: @escaping @Sendable (Request) -> Bool = { _ in true }) {
        shared.cancelRequests(with: requestType, passingTest: test)
    }

    /// Sends a request and receives the result as the argument of `handler` closure. This method takes
    /// a type parameter `Request` that conforms to `Request` protocol. The result of passed request is
    /// expressed as `Result<Request.Response, SessionTaskError>`. Since the response type
    /// `Request.Response` is inferred from `Request` type parameter, the it changes depending on the request type.
    /// - parameter request: The request to be sent.
    /// - parameter callbackQueue: The queue where the handler runs. If this parameters is `nil`, default `callbackQueue` of `Session` will be used.
    /// - parameter handler: The closure that receives result of the request.
    /// - returns: The new session task.
    @discardableResult
    open func send<Request: APIKit.Request>(_ request: Request, callbackQueue: CallbackQueue? = nil, handler: @escaping @Sendable (Result<Request.Response, SessionTaskError>) -> Void = { _ in }) -> SessionTask? {
        let task = createSessionTask(request, callbackQueue: callbackQueue, handler: handler)
        task?.resume()
        return task
    }

    /// Cancels requests that passes the test.
    /// - parameter requestType: The request type to cancel.
    /// - parameter test: The test closure that determines if a request should be cancelled or not.
    open func cancelRequests<Request: APIKit.Request>(with requestType: Request.Type, passingTest test: @escaping @Sendable (Request) -> Bool = { _ in true }) {
        let selfBox = UncheckedSendableWeakBox<Session>(value: self)
        adapter.getTasks { tasks in
            tasks
                .filter { task in
                    if let request = selfBox.value?.requestForTask(task) as Request? {
                        return test(request)
                    } else {
                        return false
                    }
                }
                .forEach { $0.cancel() }
        }
    }

    internal func createSessionTask<Request: APIKit.Request>(_ request: Request, callbackQueue: CallbackQueue?, handler: @escaping @Sendable (Result<Request.Response, SessionTaskError>) -> Void) -> SessionTask? {
        let callbackQueue = callbackQueue ?? self.callbackQueue
        let urlRequest: URLRequest
        do {
            urlRequest = try request.buildURLRequest()
        } catch {
            callbackQueue.execute {
                handler(.failure(.requestError(error)))
            }
            return nil
        }

        let task = adapter.createTask(with: urlRequest) { data, urlResponse, error in
            let result: UncheckedSendableBox<Result<Request.Response, SessionTaskError>>

            switch (data, urlResponse, error) {
            case (_, _, let error?):
                result = .init(value: .failure(.connectionError(error)))

            case (let data?, let urlResponse as HTTPURLResponse, _):
                do {
                    result = .init(value: .success(try request.parse(data: data as Data, urlResponse: urlResponse)))
                } catch {
                    result = .init(value: .failure(.responseError(error)))
                }

            default:
                result = .init(value:  .failure(.responseError(ResponseError.nonHTTPURLResponse(urlResponse))))
            }

            callbackQueue.execute {
                handler(result.value)
            }
        }

        setRequest(request, forTask: task)

        return task
    }

    private func setRequest<Request: APIKit.Request>(_ request: Request, forTask task: SessionTask) {
        objc_setAssociatedObject(task, &taskRequestKey.value, request, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private func requestForTask<Request: APIKit.Request>(_ task: SessionTask) -> Request? {
        return objc_getAssociatedObject(task, &taskRequestKey.value) as? Request
    }
}
