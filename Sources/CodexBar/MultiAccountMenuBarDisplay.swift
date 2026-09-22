import CodexBarCore
import Foundation

enum MultiAccountMenuBarWindow: String, CaseIterable, Identifiable {
    case session
    case weekly

    var id: String {
        self.rawValue
    }

    var label: String {
        switch self {
        case .session: L("Session")
        case .weekly: L("Weekly")
        }
    }

    fileprivate var rateLane: CodexConsumerProjection.RateLane {
        switch self {
        case .session: .session
        case .weekly: .weekly
        }
    }

    /// Accepts the earlier session raw value so an existing menu-bar choice keeps working.
    static func resolved(storedRaw: String?) -> Self {
        switch storedRaw {
        case weekly.rawValue:
            .weekly
        case session.rawValue, "fiveHour":
            .session
        default:
            .session
        }
    }
}

enum MultiAccountMenuBarDisplay {
    static let unavailableValue = "–"

    struct Item: Equatable {
        let accountID: String
        let indicator: String
        let percentage: String
    }

    struct Query {
        var accounts: [CodexVisibleAccount] = []
        var snapshots: [CodexAccountUsageSnapshot] = []
        var selectedSnapshot: UsageSnapshot?
        var selectedAccountID: String?
        var window: MultiAccountMenuBarWindow = .session
        var showUsed = false
        var showEmailInitial = true
    }

    /// Provider-neutral account row. Session maps to the snapshot's primary window and weekly to
    /// its secondary window, with the other window as fallback when one lane is missing.
    struct Reading {
        var id: String
        var label: String
        var snapshot: UsageSnapshot?
    }

    static func text(_ query: Query) -> String? {
        self.items(query)?
            .map(\.percentage)
            .joined(separator: " ")
    }

    static func items(_ query: Query) -> [Item]? {
        let orderedAccounts = query.accounts.isEmpty ? query.snapshots.map(\.account) : query.accounts
        guard !orderedAccounts.isEmpty else {
            guard let percentage = self.percentText(snapshot: query.selectedSnapshot, query: query) else {
                return nil
            }
            let email = query.selectedSnapshot?.accountEmail(for: .codex) ?? ""
            return [Item(
                accountID: query.selectedAccountID ?? email,
                indicator: query.showEmailInitial ? self.indicator(email: email) : "1",
                percentage: percentage)]
        }

        var hasAvailableValue = false
        let items = orderedAccounts.enumerated().map { index, account in
            let snapshot = self.usageSnapshot(for: account, among: orderedAccounts, query: query)
            guard let percentage = self.percentText(snapshot: snapshot, query: query) else {
                return Item(
                    accountID: account.id,
                    indicator: query.showEmailInitial ? self.indicator(email: account.email) : String(index + 1),
                    percentage: self.unavailableValue)
            }
            hasAvailableValue = true
            return Item(
                accountID: account.id,
                indicator: query.showEmailInitial ? self.indicator(email: account.email) : String(index + 1),
                percentage: percentage)
        }
        return hasAvailableValue ? items : nil
    }

    static func standardItems(
        readings: [Reading],
        window: MultiAccountMenuBarWindow,
        showUsed: Bool,
        showEmailInitial: Bool) -> [Item]?
    {
        guard !readings.isEmpty else { return nil }
        var hasAvailableValue = false
        let items = readings.enumerated().map { index, reading in
            let indicator = showEmailInitial ? self.indicator(email: reading.label) : String(index + 1)
            guard let percentage = MenuBarDisplayText.percentText(
                window: self.standardRateWindow(from: reading.snapshot, window: window),
                showUsed: showUsed)
            else {
                return Item(
                    accountID: reading.id,
                    indicator: indicator,
                    percentage: self.unavailableValue)
            }
            hasAvailableValue = true
            return Item(accountID: reading.id, indicator: indicator, percentage: percentage)
        }
        return hasAvailableValue ? items : nil
    }

    static func standardRateWindow(
        from snapshot: UsageSnapshot?,
        window: MultiAccountMenuBarWindow) -> RateWindow?
    {
        switch window {
        case .session:
            snapshot?.primary ?? snapshot?.secondary
        case .weekly:
            snapshot?.secondary ?? snapshot?.primary
        }
    }

    private static func indicator(email: String) -> String {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let initial = String(trimmed.prefix(1)).uppercased()
        return initial.isEmpty ? "?" : initial
    }

    private static func usageSnapshot(
        for account: CodexVisibleAccount,
        among accounts: [CodexVisibleAccount],
        query: Query) -> UsageSnapshot?
    {
        let snapshotsByAccountID = Dictionary(
            query.snapshots.map { ($0.id, $0) },
            uniquingKeysWith: { _, latest in latest })
        var candidates: [UsageSnapshot] = []
        if let snapshot = snapshotsByAccountID[account.id]?.snapshot {
            candidates.append(snapshot)
        } else if let matched = self.identityMatchedSnapshot(for: account, snapshots: query.snapshots) {
            candidates.append(matched)
        }
        if let selectedSnapshot = query.selectedSnapshot,
           self.shouldUseSelectedSnapshot(for: account, among: accounts, query: query)
        {
            candidates.append(selectedSnapshot)
        }
        return candidates.first { self.rateWindow(from: $0, window: query.window) != nil } ?? candidates.first
    }

    private static func identityMatchedSnapshot(
        for account: CodexVisibleAccount,
        snapshots: [CodexAccountUsageSnapshot]) -> UsageSnapshot?
    {
        let matches = snapshots.filter { UsageStore.codexPriorSnapshotAccountMatches($0.account, account: account) }
        guard matches.count == 1 else { return nil }
        return matches[0].snapshot
    }

    private static func shouldUseSelectedSnapshot(
        for account: CodexVisibleAccount,
        among accounts: [CodexVisibleAccount],
        query: Query) -> Bool
    {
        if account.id == query.selectedAccountID {
            return true
        }
        guard let selectedEmail = CodexIdentityResolver.normalizeEmail(
            query.selectedSnapshot?.accountEmail(for: .codex)
                ?? query.selectedSnapshot?.identity(for: .codex)?.accountEmail),
            let accountEmail = CodexIdentityResolver.normalizeEmail(account.email),
            selectedEmail == accountEmail
        else {
            return false
        }
        return accounts.count(where: {
            CodexIdentityResolver.normalizeEmail($0.email) == accountEmail
        }) == 1
    }

    private static func percentText(snapshot: UsageSnapshot?, query: Query) -> String? {
        MenuBarDisplayText.percentText(
            window: self.rateWindow(from: snapshot, window: query.window),
            showUsed: query.showUsed)
    }

    private static func rateWindow(
        from snapshot: UsageSnapshot?,
        window: MultiAccountMenuBarWindow) -> RateWindow?
    {
        let fallbackLane: CodexConsumerProjection.RateLane = switch window {
        case .session: .weekly
        case .weekly: .session
        }
        return CodexConsumerProjection.sourceRateWindow(for: window.rateLane, snapshot: snapshot)
            ?? CodexConsumerProjection.sourceRateWindow(for: fallbackLane, snapshot: snapshot)
            ?? snapshot?.primary
            ?? snapshot?.secondary
    }
}

extension UsageStore {
    func multiAccountMenuBarItems(for provider: UsageProvider) -> [MultiAccountMenuBarDisplay.Item]? {
        guard self.settings.multiAccountMenuBarEnabled else { return nil }
        if provider == .codex {
            return self.visibleAccountMenuBarItems()
        }
        if provider == .claude,
           ClaudeSwapAccountProjection.shouldPresentAccounts(
               accountCount: self.claudeSwapAccountSnapshots.count,
               showSingleAccount: self.settings.claudeSwapShowSingleAccount)
        {
            return self.claudeSwapMenuBarItems()
        }
        return self.tokenAccountMenuBarItems(for: provider)
    }

    private func visibleAccountMenuBarItems() -> [MultiAccountMenuBarDisplay.Item]? {
        guard self.settings.multiAccountMenuBarEnabled else { return nil }
        let projection = self.settings.codexVisibleAccountProjectionForMenuDisplay
        return MultiAccountMenuBarDisplay.items(MultiAccountMenuBarDisplay.Query(
            accounts: projection?.visibleAccounts ?? [],
            snapshots: self.codexAccountSnapshots,
            selectedSnapshot: self.snapshots[.codex],
            selectedAccountID: projection?.activeVisibleAccountID,
            window: self.settings.multiAccountMenuBarWindow,
            showUsed: self.settings.usageBarsShowUsed,
            showEmailInitial: !self.settings.hidePersonalInfo))
    }

    private func claudeSwapMenuBarItems() -> [MultiAccountMenuBarDisplay.Item]? {
        let accounts = self.claudeSwapAccountSnapshots
        guard accounts.count > 1 else { return nil }
        return self.standardMenuBarItems(readings: accounts.map { account in
            MultiAccountMenuBarDisplay.Reading(
                id: "\(account.id.source):\(account.id.opaqueID)",
                label: account.accountEmail ?? account.displayLabel,
                snapshot: account.usesLastKnownUsage ? nil : account.snapshot)
        })
    }

    private func tokenAccountMenuBarItems(
        for provider: UsageProvider) -> [MultiAccountMenuBarDisplay.Item]?
    {
        let accounts = self.tokenAccounts(for: provider)
        guard accounts.count > 1 else { return nil }
        let cached = self.validTokenAccountSnapshots(provider: provider, accounts: accounts)
        var knownAccountIDs = Set<UUID>()
        var snapshotsByID: [UUID: UsageSnapshot] = [:]
        for snapshot in cached {
            knownAccountIDs.insert(snapshot.account.id)
            if let usage = snapshot.snapshot {
                snapshotsByID[snapshot.account.id] = usage
            }
        }
        let selectedID = self.settings.effectiveSelectedTokenAccount(for: provider)?.id
        let liveSnapshot = self.snapshots[provider.instanceID]
        return self.standardMenuBarItems(readings: accounts.map { account in
            let snapshot: UsageSnapshot? = if knownAccountIDs.contains(account.id) {
                snapshotsByID[account.id]
            } else if account.id == selectedID {
                liveSnapshot
            } else {
                nil
            }
            return MultiAccountMenuBarDisplay.Reading(
                id: account.id.uuidString,
                label: account.label,
                snapshot: snapshot)
        })
    }

    private func standardMenuBarItems(
        readings: [MultiAccountMenuBarDisplay.Reading]) -> [MultiAccountMenuBarDisplay.Item]?
    {
        MultiAccountMenuBarDisplay.standardItems(
            readings: readings,
            window: self.settings.multiAccountMenuBarWindow,
            showUsed: self.settings.usageBarsShowUsed,
            showEmailInitial: !self.settings.hidePersonalInfo)
    }
}
