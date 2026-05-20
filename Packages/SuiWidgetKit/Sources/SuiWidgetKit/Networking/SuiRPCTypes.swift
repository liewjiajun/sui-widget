import Foundation

// MARK: - JSON-RPC envelope

struct JSONRPCRequest<P: Encodable>: Encodable {
    let jsonrpc: String
    let id: Int
    let method: String
    let params: P

    init(method: String, params: P, id: Int = 1) {
        self.jsonrpc = "2.0"
        self.id = id
        self.method = method
        self.params = params
    }
}

struct JSONRPCResponse<R: Decodable>: Decodable {
    let jsonrpc: String?
    let id: Int?
    let result: R?
    let error: JSONRPCErrorPayload?
}

struct JSONRPCErrorPayload: Decodable, Equatable {
    let code: Int
    let message: String
}

// MARK: - suix_getAllBalances

public struct SuiBalance: Decodable, Equatable, Sendable {
    public let coinType: String
    public let coinObjectCount: Int
    public let totalBalance: Decimal

    enum CodingKeys: String, CodingKey {
        case coinType, coinObjectCount, totalBalance
    }

    public init(coinType: String, coinObjectCount: Int, totalBalance: Decimal) {
        self.coinType = coinType
        self.coinObjectCount = coinObjectCount
        self.totalBalance = totalBalance
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        coinType = try c.decode(String.self, forKey: .coinType)
        coinObjectCount = try c.decode(Int.self, forKey: .coinObjectCount)
        let totalString = try c.decode(String.self, forKey: .totalBalance)
        guard let dec = Decimal(suiU64String: totalString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .totalBalance, in: c,
                debugDescription: "totalBalance not a u64 string: \(totalString)"
            )
        }
        totalBalance = dec
    }
}

// MARK: - suix_getCoinMetadata

public struct SuiCoinMetadata: Decodable, Equatable, Sendable {
    public let decimals: Int
    public let name: String
    public let symbol: String
    public let description: String
    public let iconUrl: String?

    enum CodingKeys: String, CodingKey {
        case decimals, name, symbol, description, iconUrl
    }

    public init(decimals: Int, name: String, symbol: String, description: String, iconUrl: String?) {
        self.decimals = decimals
        self.name = name
        self.symbol = symbol
        self.description = description
        self.iconUrl = iconUrl
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        decimals = try c.decode(Int.self, forKey: .decimals)
        name = try c.decode(String.self, forKey: .name)
        symbol = try c.decode(String.self, forKey: .symbol)
        description = try c.decode(String.self, forKey: .description)
        // The Sui RPC may return iconUrl as null or as an empty string. Normalise empty → nil.
        if let raw = try c.decodeIfPresent(String.self, forKey: .iconUrl), !raw.isEmpty {
            iconUrl = raw
        } else {
            iconUrl = nil
        }
    }
}

// MARK: - suix_getOwnedObjects

public struct SuiOwnedObjectsPage: Decodable, Equatable, Sendable {
    public let data: [SuiOwnedObjectWrapper]
    public let nextCursor: String?
    public let hasNextPage: Bool

    enum CodingKeys: String, CodingKey {
        case data, nextCursor, hasNextPage
    }

    public init(data: [SuiOwnedObjectWrapper], nextCursor: String?, hasNextPage: Bool) {
        self.data = data
        self.nextCursor = nextCursor
        self.hasNextPage = hasNextPage
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        nextCursor = try c.decodeIfPresent(String.self, forKey: .nextCursor)
        hasNextPage = try c.decodeIfPresent(Bool.self, forKey: .hasNextPage) ?? false
        // Decode each owned-object element through FailableDecodable so a single
        // malformed object (unexpected display shape, missing field, etc.) is
        // dropped instead of aborting the whole page. Before this, one bad NFT
        // surfaced as "expected to decode String" and the user lost every NFT
        // on the page.
        let failable = try c.decodeIfPresent(
            [FailableDecodable<SuiOwnedObjectWrapper>].self, forKey: .data
        ) ?? []
        data = failable.compactMap(\.value)
    }
}

public struct SuiOwnedObjectWrapper: Decodable, Equatable, Sendable {
    public let data: SuiOwnedObject?
    public init(data: SuiOwnedObject?) { self.data = data }
}

public struct SuiOwnedObject: Decodable, Equatable, Sendable {
    public let objectId: String
    public let type: String?
    public let display: SuiDisplayContainer?
    public init(objectId: String, type: String?, display: SuiDisplayContainer?) {
        self.objectId = objectId
        self.type = type
        self.display = display
    }
}

/// Sui returns `display` as `{ "data": <dict-or-null>, "error": <string-or-null> }`.
/// Display values are *nominally* strings, but real NFT collections regularly
/// emit `null`, numeric or boolean values for individual keys (an unresolved
/// template field, a numeric attribute, etc.). A plain `[String: String]`
/// decode aborts the entire object — and, before page-level tolerance, the
/// entire NFT list — on the first odd field. We decode leniently instead:
/// scalars are coerced to their string form and nulls/containers are dropped.
public struct SuiDisplayContainer: Decodable, Equatable, Sendable {
    public let data: [String: String]?
    public let error: String?

    enum CodingKeys: String, CodingKey {
        case data, error
    }

    public init(data: [String: String]?, error: String?) {
        self.data = data
        self.error = error
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // `error` is non-critical metadata — never let it fail the decode.
        error = (try? c.decodeIfPresent(String.self, forKey: .error)) ?? nil
        if let rawMap = try c.decodeIfPresent([String: LenientScalar].self, forKey: .data) {
            var coerced: [String: String] = [:]
            for (key, scalar) in rawMap {
                if let str = scalar.stringValue {
                    coerced[key] = str
                }
            }
            data = coerced
        } else {
            data = nil
        }
    }
}

// MARK: - Lenient decoding helpers

/// Wraps a decode that may fail. The wrapper itself always decodes
/// successfully — the inner failure is captured as a nil `value` — so an array
/// of these can be decoded even when individual elements are malformed.
struct FailableDecodable<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try? container.decode(T.self)
    }
}

/// Decodes a single JSON scalar (string / number / bool / null) and exposes it
/// as an optional `String`. Used for Sui display maps whose values are
/// nominally strings but occasionally arrive as nulls or numbers. Nested
/// objects/arrays are not representable as a display string and decode to nil.
struct LenientScalar: Decodable {
    let stringValue: String?
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            stringValue = nil
        } else if let s = try? c.decode(String.self) {
            stringValue = s
        } else if let i = try? c.decode(Int.self) {
            stringValue = String(i)
        } else if let d = try? c.decode(Double.self) {
            stringValue = String(d)
        } else if let b = try? c.decode(Bool.self) {
            stringValue = b ? "true" : "false"
        } else {
            stringValue = nil
        }
    }
}

// MARK: - suix_getStakes

public struct SuiDelegatedStake: Decodable, Equatable, Sendable {
    public let validatorAddress: String
    public let stakingPool: String
    public let stakes: [SuiStakeEntry]
}

public struct SuiStakeEntry: Decodable, Equatable, Sendable {
    public let stakedSuiId: String
    public let stakeRequestEpoch: String
    public let principal: Decimal
    public let status: String                // "Active" / "Pending" / "Unstaked"
    public let estimatedReward: Decimal?

    enum CodingKeys: String, CodingKey {
        case stakedSuiId, stakeRequestEpoch, principal, status, estimatedReward
    }

    public init(
        stakedSuiId: String,
        stakeRequestEpoch: String,
        principal: Decimal,
        status: String,
        estimatedReward: Decimal?
    ) {
        self.stakedSuiId = stakedSuiId
        self.stakeRequestEpoch = stakeRequestEpoch
        self.principal = principal
        self.status = status
        self.estimatedReward = estimatedReward
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        stakedSuiId = try c.decode(String.self, forKey: .stakedSuiId)
        stakeRequestEpoch = try c.decode(String.self, forKey: .stakeRequestEpoch)
        let principalString = try c.decode(String.self, forKey: .principal)
        guard let p = Decimal(suiU64String: principalString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .principal, in: c,
                debugDescription: "principal not a u64 string: \(principalString)"
            )
        }
        principal = p
        status = try c.decode(String.self, forKey: .status)

        if let rewardString = try c.decodeIfPresent(String.self, forKey: .estimatedReward),
           let dec = Decimal(suiU64String: rewardString) {
            estimatedReward = dec
        } else {
            estimatedReward = nil
        }
    }
}

// MARK: - suix_getLatestSuiSystemState (truncated to fields we care about)

public struct SuiSystemState: Decodable, Equatable, Sendable {
    public let epoch: String
    public let activeValidators: [SuiValidatorInfo]
}

public struct SuiValidatorInfo: Decodable, Equatable, Sendable {
    public let suiAddress: String
    public let name: String
    public let imageUrl: String?
    public let description: String?
    public let commissionRate: String
    public let stakingPoolId: String

    enum CodingKeys: String, CodingKey {
        case suiAddress, name, imageUrl, description, commissionRate, stakingPoolId
    }

    public init(
        suiAddress: String,
        name: String,
        imageUrl: String?,
        description: String?,
        commissionRate: String,
        stakingPoolId: String
    ) {
        self.suiAddress = suiAddress
        self.name = name
        self.imageUrl = imageUrl
        self.description = description
        self.commissionRate = commissionRate
        self.stakingPoolId = stakingPoolId
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        suiAddress = try c.decode(String.self, forKey: .suiAddress)
        name = try c.decode(String.self, forKey: .name)
        if let raw = try c.decodeIfPresent(String.self, forKey: .imageUrl), !raw.isEmpty {
            imageUrl = raw
        } else {
            imageUrl = nil
        }
        if let raw = try c.decodeIfPresent(String.self, forKey: .description), !raw.isEmpty {
            description = raw
        } else {
            description = nil
        }
        commissionRate = try c.decode(String.self, forKey: .commissionRate)
        stakingPoolId = try c.decode(String.self, forKey: .stakingPoolId)
    }
}
