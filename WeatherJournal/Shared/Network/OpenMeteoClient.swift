import Foundation

enum NetworkContract {
    static let secureScheme = "https"
    static let successStatus = 200..<300
    static let plus = "+"
    static let encodedPlus = "%2B"
}

enum NetworkFailure: Error {
    case invalidURL
    case invalidResponse
    case transport(Error)
    case http(status: Int, reason: String?)
    case decoding(Error)
}

struct HTTPTransport {
    let send: (URLRequest) async throws -> (Data, URLResponse)
}

/// 统一查询编码与错误分类，保留服务端原因但不将正文写入诊断日志。
struct OpenMeteoClient {
    let transport: HTTPTransport
    let diagnostics: DiagnosticSink

    func get<Response: Decodable>(_ endpoint: URL, query: [URLQueryItem]) async throws -> Response {
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw NetworkFailure.invalidURL
        }
        components.queryItems = (components.queryItems ?? []) + query
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(
            of: NetworkContract.plus, with: NetworkContract.encodedPlus)
        guard let url = components.url else { throw NetworkFailure.invalidURL }

        do {
            let data: Data
            let response: URLResponse
            do { (data, response) = try await transport.send(URLRequest(url: url)) } catch {
                if Task.isCancelled { throw CancellationError() }
                throw NetworkFailure.transport(error)
            }
            guard let http = response as? HTTPURLResponse else { throw NetworkFailure.invalidResponse }
            guard NetworkContract.successStatus.contains(http.statusCode) else {
                let reason = try? JSONDecoder().decode(ServiceError.self, from: data).reason
                throw NetworkFailure.http(status: http.statusCode, reason: reason)
            }
            do { return try JSONDecoder().decode(Response.self, from: data) } catch {
                throw NetworkFailure.decoding(error)
            }
        } catch {
            if !Task.isCancelled { diagnostics.record(.network, error) }
            throw error
        }
    }

    private struct ServiceError: Decodable { let reason: String? }
}
