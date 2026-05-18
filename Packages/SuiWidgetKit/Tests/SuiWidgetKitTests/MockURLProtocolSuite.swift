import Testing

/// Parent suite that serialises all child suites which share `MockURLProtocol`'s
/// global handler. Without this, two top-level `.serialized` suites (e.g.
/// `HTTPClient` and `SuiRPCClient`) still run in parallel relative to each
/// other and race on `MockURLProtocol.handler`.
///
/// `.serialized` propagates to descendants: the nested `@Suite` declarations
/// in extension files inherit it, so every test under this parent runs
/// strictly one-at-a-time regardless of file boundaries.
@Suite("MockURLProtocolSuite", .serialized)
enum MockURLProtocolSuite {}
