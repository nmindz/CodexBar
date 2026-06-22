import Foundation
import Testing
@testable import CodexBar
@testable import CodexBarCore

@Suite(.serialized)
@MainActor
struct UsageStoreRefreshCacheTests {
    @Test
    func `background refresh skips provider with recent successful snapshot`() async throws {
        let settings = Self.makeSettingsStore(suite: "UsageStoreRefreshCacheTests-background-skip")
        settings.statusChecksEnabled = false
        settings.openAIWebAccessEnabled = false
        settings.usageCacheDuration = .fiveMinutes
        try Self.enableOnly(.codex, settings: settings)
        let store = Self.makeUsageStore(settings: settings)
        var refreshCount = 0
        store._test_providerRefreshOverride = { _ in refreshCount += 1 }
        defer { store._test_providerRefreshOverride = nil }

        await store.refresh()
        store.snapshots[.codex] = Self.snapshot(updatedAt: Date())
        await ProviderInteractionContext.$current.withValue(.background) {
            await store.refresh()
        }

        #expect(refreshCount == 1)
    }

    @Test
    func `manual refresh bypasses usage cache`() async throws {
        let settings = Self.makeSettingsStore(suite: "UsageStoreRefreshCacheTests-manual-bypass")
        settings.statusChecksEnabled = false
        settings.openAIWebAccessEnabled = false
        settings.usageCacheDuration = .thirtyMinutes
        try Self.enableOnly(.codex, settings: settings)
        let store = Self.makeUsageStore(settings: settings)
        var refreshCount = 0
        store._test_providerRefreshOverride = { _ in refreshCount += 1 }
        defer { store._test_providerRefreshOverride = nil }

        await store.refresh()
        store.snapshots[.codex] = Self.snapshot(updatedAt: Date())
        await ProviderInteractionContext.$current.withValue(.userInitiated) {
            await store.refresh(forceTokenUsage: true)
        }

        #expect(refreshCount == 2)
    }

    @Test
    func `background refresh runs when usage cache is disabled`() async throws {
        let settings = Self.makeSettingsStore(suite: "UsageStoreRefreshCacheTests-disabled")
        settings.statusChecksEnabled = false
        settings.openAIWebAccessEnabled = false
        settings.usageCacheDuration = .disabled
        try Self.enableOnly(.codex, settings: settings)
        let store = Self.makeUsageStore(settings: settings)
        var refreshCount = 0
        store._test_providerRefreshOverride = { _ in refreshCount += 1 }
        defer { store._test_providerRefreshOverride = nil }

        await store.refresh()
        store.snapshots[.codex] = Self.snapshot(updatedAt: Date())
        await ProviderInteractionContext.$current.withValue(.background) {
            await store.refresh()
        }

        #expect(refreshCount == 2)
    }

    @Test
    func `clear usage caches drops volatile usage state and cost throttle`() async throws {
        let settings = Self.makeSettingsStore(suite: "UsageStoreRefreshCacheTests-reset")
        try Self.enableOnly(.codex, settings: settings)
        let store = Self.makeUsageStore(settings: settings)
        store.snapshots[.codex] = Self.snapshot(updatedAt: Date())
        store.errors[.codex] = "stale"
        store.lastSourceLabels[.codex] = "cached"
        store.tokenSnapshots[.codex] = CostUsageTokenSnapshot(
            sessionTokens: 10,
            sessionCostUSD: 0.01,
            last30DaysTokens: 10,
            last30DaysCostUSD: 0.01,
            daily: [],
            updatedAt: Date())
        store.lastTokenFetchAt[.codex] = Date()

        let error = await store.clearUsageCaches()

        #expect(error == nil)
        #expect(store.snapshots.isEmpty)
        #expect(store.errors.isEmpty)
        #expect(store.lastSourceLabels.isEmpty)
        #expect(store.tokenSnapshots.isEmpty)
        #expect(store.lastTokenFetchAt.isEmpty)
    }

    private static func snapshot(updatedAt: Date) -> UsageSnapshot {
        UsageSnapshot(
            primary: RateWindow(usedPercent: 25, windowMinutes: 300, resetsAt: nil, resetDescription: nil),
            secondary: nil,
            updatedAt: updatedAt)
    }

    private static func makeSettingsStore(suite: String) -> SettingsStore {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let configStore = testConfigStore(suiteName: suite)
        let settings = SettingsStore(
            userDefaults: defaults,
            configStore: configStore,
            zaiTokenStore: NoopZaiTokenStore(),
            syntheticTokenStore: NoopSyntheticTokenStore(),
            codexCookieStore: InMemoryCookieHeaderStore(),
            claudeCookieStore: InMemoryCookieHeaderStore(),
            cursorCookieStore: InMemoryCookieHeaderStore(),
            opencodeCookieStore: InMemoryCookieHeaderStore(),
            factoryCookieStore: InMemoryCookieHeaderStore(),
            minimaxCookieStore: InMemoryMiniMaxCookieStore(),
            minimaxAPITokenStore: InMemoryMiniMaxAPITokenStore(),
            kimiTokenStore: InMemoryKimiTokenStore(),
            kimiK2TokenStore: InMemoryKimiK2TokenStore(),
            augmentCookieStore: InMemoryCookieHeaderStore(),
            ampCookieStore: InMemoryCookieHeaderStore(),
            copilotTokenStore: InMemoryCopilotTokenStore(),
            tokenAccountStore: InMemoryTokenAccountStore())
        settings.providerDetectionCompleted = true
        return settings
    }

    private static func makeUsageStore(settings: SettingsStore) -> UsageStore {
        UsageStore(
            fetcher: UsageFetcher(environment: [:]),
            browserDetection: BrowserDetection(cacheTTL: 0),
            settings: settings,
            environmentBase: [:])
    }

    private static func enableOnly(_ enabledProvider: UsageProvider, settings: SettingsStore) throws {
        let metadata = ProviderRegistry.shared.metadata
        for provider in UsageProvider.allCases {
            try settings.setProviderEnabled(
                provider: provider,
                metadata: #require(metadata[provider]),
                enabled: provider == enabledProvider)
        }
    }
}
