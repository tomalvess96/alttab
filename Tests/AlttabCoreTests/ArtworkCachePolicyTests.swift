import Foundation
import Testing
@testable import AlttabCore

@Suite struct ArtworkCachePolicyTests {
    @Test func keepsOnlyCoversStillInUse() {
        let cache = ["a": 1, "b": 2, "c": 3]
        #expect(ArtworkCachePolicy.pruned(cache, keeping: ["b"]) == ["b": 2])
    }

    @Test func fetchesNewCover() {
        #expect(ArtworkCachePolicy.shouldFetch(cached: false, loading: false, lastFailure: nil, now: .now))
    }

    @Test func doesNotRefetchCachedOrLoading() {
        #expect(!ArtworkCachePolicy.shouldFetch(cached: true, loading: false, lastFailure: nil, now: .now))
        #expect(!ArtworkCachePolicy.shouldFetch(cached: false, loading: true, lastFailure: nil, now: .now))
    }

    @Test func waitsAMinuteAfterFailure() {
        let failed = Date(timeIntervalSince1970: 1000)
        #expect(!ArtworkCachePolicy.shouldFetch(cached: false, loading: false, lastFailure: failed,
                                                 now: failed.addingTimeInterval(5)))
        #expect(ArtworkCachePolicy.shouldFetch(cached: false, loading: false, lastFailure: failed,
                                                now: failed.addingTimeInterval(61)))
    }
}
