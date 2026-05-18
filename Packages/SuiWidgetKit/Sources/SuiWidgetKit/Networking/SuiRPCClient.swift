import Foundation

public struct SuiRPCClient: Sendable {
    public let http: HTTPClient
    public let rotator: RPCEndpointRotator

    public init(http: HTTPClient = .init(), rotator: RPCEndpointRotator = .init()) {
        self.http = http
        self.rotator = rotator
    }

    // MARK: - Public API

    public func getAllBalances(owner: SuiAddress) async throws -> [SuiBalance] {
        try await call(
            method: "suix_getAllBalances",
            params: [AnyEncodable(owner.rawValue)],
            decode: [SuiBalance].self
        )
    }

    public func getCoinMetadata(coinType: String) async throws -> SuiCoinMetadata {
        try await call(
            method: "suix_getCoinMetadata",
            params: [AnyEncodable(coinType)],
            decode: SuiCoinMetadata.self
        )
    }

    public func getOwnedObjects(
        owner: SuiAddress,
        limit: Int = 50,
        cursor: String? = nil
    ) async throws -> SuiOwnedObjectsPage {
        let queryWrapper = OwnedObjectsQuery(filter: nil, options: OwnedObjectsOptions())
        let cursorParam: AnyEncodable = if let cursor {
            AnyEncodable(cursor)
        } else {
            AnyEncodable(Optional<String>.none)
        }
        let params: [AnyEncodable] = [
            AnyEncodable(owner.rawValue),
            AnyEncodable(queryWrapper),
            cursorParam,
            AnyEncodable(limit),
        ]
        return try await call(
            method: "suix_getOwnedObjects",
            params: params,
            decode: SuiOwnedObjectsPage.self
        )
    }

    public func getStakes(owner: SuiAddress) async throws -> [SuiDelegatedStake] {
        try await call(
            method: "suix_getStakes",
            params: [AnyEncodable(owner.rawValue)],
            decode: [SuiDelegatedStake].self
        )
    }

    public func getLatestSuiSystemState() async throws -> SuiSystemState {
        try await call(
            method: "suix_getLatestSuiSystemState",
            params: [String](),
            decode: SuiSystemState.self
        )
    }

    public func resolveNameServiceAddress(name: String) async throws -> SuiAddress? {
        let raw: String? = try await call(
            method: "suix_resolveNameServiceAddress",
            params: [AnyEncodable(name)],
            decode: String?.self
        )
        guard let raw, let addr = SuiAddress(rawValue: raw) else { return nil }
        return addr
    }

    public func resolveNameServiceNames(address: SuiAddress) async throws -> [String] {
        let page: ResolveNamesPage = try await call(
            method: "suix_resolveNameServiceNames",
            params: [AnyEncodable(address.rawValue)],
            decode: ResolveNamesPage.self
        )
        return page.data
    }

    // MARK: - Core call/rotation/decode loop

    private func call<P: Encodable, R: Decodable>(
        method: String,
        params: P,
        decode: R.Type
    ) async throws -> R {
        let bodyData = try JSONEncoder().encode(JSONRPCRequest(method: method, params: params))

        // Loop through all endpoints once before declaring total failure.
        for _ in 0..<rotator.endpoints.count {
            let endpoint = await rotator.currentEndpoint()
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "content-type")
            request.httpBody = bodyData
            request.timeoutInterval = 10

            do {
                let (data, _) = try await http.send(request)
                let envelope: JSONRPCResponse<R>
                do {
                    envelope = try JSONDecoder().decode(JSONRPCResponse<R>.self, from: data)
                } catch let decodingError as DecodingError {
                    throw SuiRPCError.decodingFailed(detail: String(describing: decodingError))
                }
                if let rpcError = envelope.error {
                    throw SuiRPCError.rpcError(code: rpcError.code, message: rpcError.message)
                }
                guard let result = envelope.result else {
                    throw SuiRPCError.missingResult
                }
                await rotator.recordSuccess(at: endpoint)
                return result
            } catch _ as HTTPClientError {
                // Treat HTTP/transport failures as endpoint-specific; rotate and retry.
                await rotator.recordFailure(at: endpoint)
                continue
            } catch let suiError as SuiRPCError {
                // RPC-level errors come from the server payload (not the endpoint health) —
                // surface immediately without rotating.
                throw suiError
            } catch {
                // Unknown transport-layer error: rotate and try the next endpoint.
                await rotator.recordFailure(at: endpoint)
                continue
            }
        }

        throw SuiRPCError.allEndpointsFailed
    }
}

// MARK: - JSON-RPC param helpers

/// Type-erased box for heterogeneous parameter encoding. Captures encode behaviour
/// of the wrapped value so a mixed `[AnyEncodable]` array can be passed as `params`.
struct AnyEncodable: Encodable {
    private let encodeImpl: @Sendable (Encoder) throws -> Void
    init<T: Encodable>(_ value: T) {
        self.encodeImpl = { try value.encode(to: $0) }
    }
    func encode(to encoder: Encoder) throws { try encodeImpl(encoder) }
}

private struct OwnedObjectsQuery: Encodable {
    let filter: String?  // null in our calls
    let options: OwnedObjectsOptions
}

private struct OwnedObjectsOptions: Encodable {
    var showType: Bool = true
    var showDisplay: Bool = true
    var showContent: Bool = false
}

private struct ResolveNamesPage: Decodable {
    let data: [String]
    // Sui returns a page envelope with `data: [String]`; we don't paginate yet.
}
