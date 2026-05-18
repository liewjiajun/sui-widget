import Foundation
import ImageIO
import Testing
@testable import SuiWidgetKit

@Suite("ImagePipeline — non-network")
struct ImagePipelineNonNetworkTests {

    @Test func ipfs_resolver_expands_ipfs_scheme_to_three_gateway_urls() {
        let resolver = IPFSGatewayResolver()
        let candidates = resolver.candidates(for: "ipfs://bafybeicid/image.png")
        #expect(candidates.count == 3)
        #expect(candidates[0].absoluteString == "https://ipfs.io/ipfs/bafybeicid/image.png")
        #expect(candidates[1].absoluteString == "https://cloudflare-ipfs.com/ipfs/bafybeicid/image.png")
        #expect(candidates[2].absoluteString == "https://dweb.link/ipfs/bafybeicid/image.png")
    }

    @Test func ipfs_resolver_passes_through_https_urls_unchanged() {
        let resolver = IPFSGatewayResolver()
        let candidates = resolver.candidates(for: "https://example.com/nft.png")
        #expect(candidates.count == 1)
        #expect(candidates[0].absoluteString == "https://example.com/nft.png")
    }

    @Test func ipfs_resolver_rotates_existing_gateway_urls() {
        let resolver = IPFSGatewayResolver()
        let candidates = resolver.candidates(for: "https://some-other-gateway.com/ipfs/bafybeicid/image.png")
        #expect(candidates.count == 3)
        #expect(candidates[0].absoluteString == "https://ipfs.io/ipfs/bafybeicid/image.png")
    }

    @Test func resizer_produces_smaller_output_than_input() throws {
        let inputData = try FixtureLoader.data(named: "nft-thumbnail-input.png")
        let resizer = ImageResizer()
        let resized = try resizer.resize(inputData, maxPixelDimension: 8)

        // Check pixel dimensions of resized JPEG.
        guard let source = CGImageSourceCreateWithData(resized as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int else {
            #expect(Bool(false), "could not read resized image properties")
            return
        }
        #expect(w <= 8 && h <= 8)
    }

    @Test func image_cache_round_trips_data_via_temp_dir() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let cache = ImageCache(containerURL: dir)
        let key = "test-key"
        let payload = Data("hello".utf8)
        let stored = try await cache.store(payload, key: key)
        #expect(FileManager.default.fileExists(atPath: stored.path))

        let url = await cache.url(forKey: key)
        #expect(url == stored)
        let readBack = try Data(contentsOf: url!)
        #expect(readBack == payload)

        try await cache.evict(key: key)
        let urlAfterEvict = await cache.url(forKey: key)
        #expect(urlAfterEvict == nil)
    }

    @Test func thumbnail_generator_key_is_deterministic() {
        let k1 = ThumbnailGenerator.key(objectId: "0xabc", size: 200)
        let k2 = ThumbnailGenerator.key(objectId: "0xabc", size: 200)
        let k3 = ThumbnailGenerator.key(objectId: "0xabc", size: 600)
        #expect(k1 == k2)
        #expect(k1 != k3)
        #expect(k1.count == 64) // sha256 hex
    }
}

extension MockURLProtocolSuite {

    @Suite("ImagePipeline — networked")
    struct ImagePipelineNetworkTests {

        @Test func downloader_returns_first_successful_candidate() async throws {
            MockURLProtocol.reset()
            // Simulate ipfs.io 404 and cloudflare-ipfs.com 200.
            MockURLProtocol.handler = { request in
                let host = request.url?.host ?? ""
                if host == "ipfs.io" {
                    return (404, Data(), [:], nil)
                }
                if host == "cloudflare-ipfs.com" {
                    return (200, Data("png-bytes".utf8), [:], nil)
                }
                return (500, Data(), [:], nil)
            }

            let downloader = ImageDownloader(
                http: HTTPClient(session: .mocked(), retryPolicy: .noRetry, randomJitter: { 0 })
            )
            let data = try await downloader.download(remoteURL: "ipfs://bafybeicid/image.png")
            #expect(String(decoding: data, as: UTF8.self) == "png-bytes")
            // ipfs.io was tried first, then cloudflare-ipfs.com.
            let hosts = MockURLProtocol.requestsObserved.map { $0.url?.host ?? "" }
            #expect(hosts.first == "ipfs.io")
            #expect(hosts.contains("cloudflare-ipfs.com"))
        }

        @Test func downloader_throws_when_all_gateways_fail() async throws {
            MockURLProtocol.reset()
            MockURLProtocol.handler = { _ in (404, Data(), [:], nil) }

            let downloader = ImageDownloader(
                http: HTTPClient(session: .mocked(), retryPolicy: .noRetry, randomJitter: { 0 })
            )
            do {
                _ = try await downloader.download(remoteURL: "ipfs://bafybeicid/image.png")
                #expect(Bool(false), "expected allGatewaysFailed throw")
            } catch let err as ImagePipelineError {
                if case .allGatewaysFailed(let url) = err {
                    #expect(url == "ipfs://bafybeicid/image.png")
                } else {
                    #expect(Bool(false), "wrong error: \(err)")
                }
            }
        }

        @Test func thumbnail_generator_writes_both_sizes_to_cache() async throws {
            MockURLProtocol.reset()
            let pngData = try FixtureLoader.data(named: "nft-thumbnail-input.png")
            MockURLProtocol.handler = { _ in (200, pngData, [:], nil) }

            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: dir) }

            let downloader = ImageDownloader(
                http: HTTPClient(session: .mocked(), retryPolicy: .noRetry, randomJitter: { 0 })
            )
            let generator = ThumbnailGenerator(
                downloader: downloader,
                resizer: ImageResizer(),
                cache: ImageCache(containerURL: dir)
            )
            let result = try await generator.generate(
                objectId: "0xobj1",
                remoteURL: "https://example.com/nft.png"
            )
            #expect(FileManager.default.fileExists(atPath: result.widgetURL.path))
            #expect(FileManager.default.fileExists(atPath: result.galleryURL.path))
            #expect(result.widgetURL != result.galleryURL)
        }
    }
}
