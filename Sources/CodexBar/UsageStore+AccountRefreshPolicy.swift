import CodexBarCore

extension UsageStore {
    static let tokenAccountMenuSnapshotLimit = 6

    func freshCodexVisibleAccountsForSnapshotHydration() -> [CodexVisibleAccount] {
        self.freshCodexVisibleAccountProjectionForAccountRefresh().visibleAccounts
    }

    func tokenAccounts(for provider: UsageProvider) -> [ProviderTokenAccount] {
        guard TokenAccountSupportCatalog.support(for: provider) != nil else { return [] }
        return self.settings.tokenAccounts(for: provider)
    }

    func shouldFetchAllTokenAccounts(provider: UsageProvider, accounts: [ProviderTokenAccount]) -> Bool {
        guard TokenAccountSupportCatalog.support(for: provider) != nil else { return false }
        guard self.settings.effectiveSelectedTokenAccount(for: provider) != nil else { return false }
        let showAllAccounts = self.settings.multiAccountMenuLayout == .stacked
            || self.settings.multiAccountMenuBarEnabled
        return (self.settings.accountWidgetsEnabled && !accounts.isEmpty)
            || (showAllAccounts && accounts.count > 1)
    }

    func shouldFetchAllCodexVisibleAccounts() -> Bool {
        // PAT is not a per-visible-account credential. Fan-out would fetch the same token for
        // every row and then reject its whoami identity against other accounts.
        guard !self.shouldUseAmbientCodexPATForUsage() else { return false }
        let projection = self.freshCodexVisibleAccountProjectionForAccountRefresh()
        let needsAllAccounts = self.settings.multiAccountMenuLayout == .stacked
            || self.settings.accountWidgetsEnabled
            || self.settings.multiAccountMenuBarEnabled
        return needsAllAccounts && projection.visibleAccounts.count > 1
    }
}
