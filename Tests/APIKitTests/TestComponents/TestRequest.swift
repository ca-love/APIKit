import Foundation
import APIKit

struct TestRequest: Request {
    var absoluteURL: URL? {
        let urlRequest = try? buildURLRequest()
        return urlRequest?.url
    }

    // MARK: Request
    typealias Response = Any

    init(baseURL: String = "https://example.com", path: String = "/", method: HTTPMethod = .get, parameters: Sendable? = [:], headerFields: [String: String] = [:], interceptURLRequest: @escaping @Sendable (URLRequest) throws -> URLRequest = { $0 }) {
        self.baseURL = URL(string: baseURL)!
        self.path = path
        self.method = method
        self.parameters = parameters
        self.headerFields = headerFields
        self.interceptURLRequest = interceptURLRequest
    }

    let baseURL: URL
    let method: HTTPMethod
    let path: String
    let parameters: Sendable?
    let headerFields: [String: String]
    let interceptURLRequest: @Sendable (URLRequest) throws -> URLRequest

    func intercept(urlRequest: URLRequest) throws -> URLRequest {
        return try interceptURLRequest(urlRequest)
    }

    func response(from object: Any, urlResponse: HTTPURLResponse) throws -> Response {
        return object
    }
}
