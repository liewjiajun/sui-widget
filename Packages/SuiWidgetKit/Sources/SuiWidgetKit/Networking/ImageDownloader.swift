import Foundation

public struct ImageDownloader: Sendable {
    public let http: HTTPClient
    public let resolver: IPFSGatewayResolver

    public init(
        http: HTTPClient = HTTPClient(),
        resolver: IPFSGatewayResolver = IPFSGatewayResolver()
    ) {
        self.http = http
        self.resolver = resolver
    }

    /// Tries each candidate URL in order; returns the first successful non-empty Data.
    /// Throws `ImagePipelineError.allGatewaysFailed` if every candidate fails.
    public func download(remoteURL: String) async throws -> Data {
        let candidates = resolver.candidates(for: remoteURL)
        guard !candidates.isEmpty else {
            throw ImagePipelineError.allGatewaysFailed(remoteURL: remoteURL)
        }

        for url in candidates {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 15
            do {
                let (data, response) = try await http.send(request)
                guard (200...299).contains(response.statusCode), !data.isEmpty else {
                    continue
                }
                return data
            } catch {
                continue
            }
        }
        throw ImagePipelineError.allGatewaysFailed(remoteURL: remoteURL)
    }
}
