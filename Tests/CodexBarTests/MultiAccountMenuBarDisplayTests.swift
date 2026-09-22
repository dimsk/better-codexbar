import CodexBarCore
import Foundation
import Testing
@testable import CodexBar

struct MultiAccountMenuBarDisplayTests {
    @Test
    func `renders every account session percentage in configured order`() {
        let accounts = [
            Self.account(id: "first", email: "first@example.com"),
            Self.account(id: "second", email: "second@example.com"),
            Self.account(id: "third", email: "third@example.com"),
        ]
        let snapshots = [
            Self.accountSnapshot(accounts[0], fiveHourUsed: 45, weeklyUsed: 1),
            Self.accountSnapshot(accounts[1], fiveHourUsed: 88, weeklyUsed: 2),
            Self.accountSnapshot(accounts[2], fiveHourUsed: 85, weeklyUsed: 3),
        ]

        let query = Self.query(accounts: accounts, snapshots: snapshots)
        #expect(MultiAccountMenuBarDisplay.text(query) == "55% 12% 15%")
        #expect(MultiAccountMenuBarDisplay.items(query)?.map(\.indicator) == ["F", "S", "T"])
    }

    @Test
    func `uses account numbers when personal information is hidden`() {
        let accounts = [
            Self.account(id: "first", email: "alice@example.com"),
            Self.account(id: "second", email: "bob@example.com"),
        ]
        let snapshots = [
            Self.accountSnapshot(accounts[0], fiveHourUsed: 45, weeklyUsed: 1),
            Self.accountSnapshot(accounts[1], fiveHourUsed: 88, weeklyUsed: 2),
        ]

        let items = MultiAccountMenuBarDisplay.items(
            Self.query(accounts: accounts, snapshots: snapshots, showEmailInitial: false))
        #expect(items?.map(\.indicator) == ["1", "2"])
    }

    @Test
    func `weekly selection and used direction apply to every account`() {
        let accounts = [
            Self.account(id: "first", email: "first@example.com"),
            Self.account(id: "second", email: "second@example.com"),
        ]
        let snapshots = [
            Self.accountSnapshot(accounts[0], fiveHourUsed: 10, weeklyUsed: 21),
            Self.accountSnapshot(accounts[1], fiveHourUsed: 20, weeklyUsed: 64),
        ]

        let text = MultiAccountMenuBarDisplay.text(
            Self.query(accounts: accounts, snapshots: snapshots, window: .weekly, showUsed: true))
        #expect(text == "21% 64%")
    }

    @Test
    func `keeps a placeholder for an account without usage`() {
        let accounts = [
            Self.account(id: "first", email: "first@example.com"),
            Self.account(id: "missing", email: "missing@example.com"),
            Self.account(id: "third", email: "third@example.com"),
        ]
        let snapshots = [
            Self.accountSnapshot(accounts[0], fiveHourUsed: 10, weeklyUsed: 20),
            Self.accountSnapshot(accounts[2], fiveHourUsed: 30, weeklyUsed: 40),
        ]

        #expect(MultiAccountMenuBarDisplay.text(
            Self.query(accounts: accounts, snapshots: snapshots)) == "90% – 70%")
    }

    @Test
    func `renders four configured accounts`() {
        let accounts = [
            Self.account(id: "c@example.com", email: "c@example.com"),
            Self.account(id: "d@example.com", email: "d@example.com"),
            Self.account(id: "i@example.com", email: "i@example.com"),
            Self.account(id: "k@example.com", email: "k@example.com"),
        ]
        let snapshots = [
            Self.accountSnapshot(accounts[0], fiveHourUsed: 45, weeklyUsed: 1),
            Self.accountSnapshot(accounts[1], fiveHourUsed: 0, weeklyUsed: 2),
            Self.accountSnapshot(accounts[2], fiveHourUsed: 0, weeklyUsed: 3),
            Self.accountSnapshot(accounts[3], fiveHourUsed: 0, weeklyUsed: 4),
        ]

        let items = MultiAccountMenuBarDisplay.items(
            Self.query(accounts: accounts, snapshots: snapshots, selectedAccountID: accounts[0].id))
        #expect(items?.map(\.indicator) == ["C", "D", "I", "K"])
        #expect(items?.map(\.percentage) == ["55%", "100%", "100%", "100%"])
    }

    @Test
    func `uses the selected snapshot when the first account is missing from fan-out rows`() {
        let accounts = [
            Self.account(id: "c@example.com", email: "c@example.com"),
            Self.account(id: "d@example.com", email: "d@example.com"),
            Self.account(id: "i@example.com", email: "i@example.com"),
            Self.account(id: "k@example.com", email: "k@example.com"),
        ]
        let snapshots = [
            Self.accountSnapshot(accounts[1], fiveHourUsed: 0, weeklyUsed: 2),
            Self.accountSnapshot(accounts[2], fiveHourUsed: 0, weeklyUsed: 3),
            Self.accountSnapshot(accounts[3], fiveHourUsed: 0, weeklyUsed: 4),
        ]
        let selected = Self.accountSnapshot(accounts[0], fiveHourUsed: 45, weeklyUsed: 10).snapshot

        let text = MultiAccountMenuBarDisplay.text(Self.query(
            accounts: accounts,
            snapshots: snapshots,
            selectedSnapshot: selected,
            selectedAccountID: accounts[0].id))
        #expect(text == "55% 100% 100% 100%")
    }

    @Test
    func `matches a live row to a managed snapshot with the same email and workspace`() throws {
        let storedID = try #require(UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"))
        let live = Self.account(
            id: "c@example.com",
            email: "c@example.com",
            workspaceAccountID: "acct-c")
        let managed = Self.account(
            id: "managed:\(storedID.uuidString.lowercased())",
            email: "c@example.com",
            source: .managedAccount(id: storedID),
            workspaceAccountID: "acct-c")
        let sibling = Self.account(
            id: "d@example.com",
            email: "d@example.com",
            workspaceAccountID: "acct-d")

        let text = MultiAccountMenuBarDisplay.text(Self.query(
            accounts: [live, sibling],
            snapshots: [
                Self.accountSnapshot(managed, fiveHourUsed: 45, weeklyUsed: 10),
                Self.accountSnapshot(sibling, fiveHourUsed: 0, weeklyUsed: 2),
            ],
            selectedAccountID: live.id))
        #expect(text == "55% 100%")
    }

    @Test
    func `falls back to weekly when an account has no five hour window`() {
        let accounts = [
            Self.account(id: "c@example.com", email: "c@example.com"),
            Self.account(id: "d@example.com", email: "d@example.com"),
        ]
        let weeklyOnly = CodexAccountUsageSnapshot(
            account: accounts[0],
            snapshot: UsageSnapshot(
                primary: nil,
                secondary: RateWindow(
                    usedPercent: 40,
                    windowMinutes: 10080,
                    resetsAt: nil,
                    resetDescription: nil),
                updatedAt: Date(timeIntervalSince1970: 100)),
            error: nil,
            sourceLabel: "test")

        let text = MultiAccountMenuBarDisplay.text(Self.query(
            accounts: accounts,
            snapshots: [
                weeklyOnly,
                Self.accountSnapshot(accounts[1], fiveHourUsed: 0, weeklyUsed: 2),
            ]))
        #expect(text == "60% 100%")
    }

    @Test
    func `keeps sibling snapshots when upserting the selected account`() {
        let first = Self.account(id: "c@example.com", email: "c@example.com")
        let second = Self.account(id: "d@example.com", email: "d@example.com")
        let firstRow = Self.accountSnapshot(first, fiveHourUsed: 10, weeklyUsed: 20)
        let secondRow = Self.accountSnapshot(second, fiveHourUsed: 0, weeklyUsed: 2)
        let updated = Self.accountSnapshot(first, fiveHourUsed: 45, weeklyUsed: 21)

        let result = UsageStore.upsertingCodexAccountSnapshot([firstRow, secondRow], updated)

        #expect(result.map(\.id) == [first.id, second.id])
        #expect(result[0].snapshot?.primary?.usedPercent == 45)
        #expect(result[1].snapshot?.primary?.usedPercent == 0)
    }

    @MainActor
    @Test
    func `reconciliation keeps a managed snapshot after live promotion`() throws {
        let storedID = try #require(UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"))
        let managed = Self.account(
            id: "c@example.com",
            email: "c@example.com",
            source: .managedAccount(id: storedID),
            workspaceAccountID: "acct-c",
            storedAccountID: storedID)
        let live = Self.account(
            id: "c@example.com",
            email: "c@example.com",
            workspaceAccountID: "acct-c",
            storedAccountID: storedID,
            isActive: true)
        let projection = CodexVisibleAccountProjection(
            visibleAccounts: [live],
            activeVisibleAccountID: live.id,
            liveVisibleAccountID: live.id,
            hasUnreadableAddedAccountStore: false)

        let result = UsageStore.codexAccountSnapshots(
            [Self.accountSnapshot(managed, fiveHourUsed: 45, weeklyUsed: 10)],
            reconciledWith: projection)

        #expect(result.count == 1)
        #expect(result.first?.account.selectionSource == .liveSystem)
        #expect(result.first?.snapshot?.primary?.usedPercent == 45)
    }

    @Test
    func `session and weekly windows use primary and secondary lanes for any provider`() {
        let readings = [
            Self.reading(id: "work", label: "work@example.com", sessionUsed: 40, weeklyUsed: 10),
            Self.reading(id: "personal", label: "personal@example.com", sessionUsed: 25, weeklyUsed: 80),
        ]

        let session = MultiAccountMenuBarDisplay.standardItems(
            readings: readings,
            window: .session,
            showUsed: false,
            showEmailInitial: true)
        let weekly = MultiAccountMenuBarDisplay.standardItems(
            readings: readings,
            window: .weekly,
            showUsed: true,
            showEmailInitial: false)

        #expect(session?.map(\.indicator) == ["W", "P"])
        #expect(session?.map(\.percentage) == ["60%", "75%"])
        #expect(weekly?.map(\.indicator) == ["1", "2"])
        #expect(weekly?.map(\.percentage) == ["10%", "80%"])
    }

    @Test
    func `keeps a placeholder when another provider account has no reading`() {
        let readings = [
            Self.reading(id: "work", label: "Work", sessionUsed: 10, weeklyUsed: 20),
            MultiAccountMenuBarDisplay.Reading(id: "missing", label: "Home", snapshot: nil),
        ]

        let items = MultiAccountMenuBarDisplay.standardItems(
            readings: readings,
            window: .session,
            showUsed: false,
            showEmailInitial: true)

        #expect(items?.map(\.indicator) == ["W", "H"])
        #expect(items?.map(\.percentage) == ["90%", "–"])
    }

    @MainActor
    @Test
    func `renders account indicators and percentages as one template image`() throws {
        let items = [
            MultiAccountMenuBarDisplay.Item(accountID: "a", indicator: "A", percentage: "55%"),
            MultiAccountMenuBarDisplay.Item(accountID: "b", indicator: "B", percentage: "12%"),
        ]

        let image = try #require(MultiAccountStatusImageRenderer.image(items: items))

        #expect(image.isTemplate)
        #expect(image.size.width >= 44)
        #expect(image.size.height == 18)
    }

    private static func query(
        accounts: [CodexVisibleAccount],
        snapshots: [CodexAccountUsageSnapshot],
        selectedSnapshot: UsageSnapshot? = nil,
        selectedAccountID: String? = nil,
        window: MultiAccountMenuBarWindow = .session,
        showUsed: Bool = false,
        showEmailInitial: Bool = true) -> MultiAccountMenuBarDisplay.Query
    {
        MultiAccountMenuBarDisplay.Query(
            accounts: accounts,
            snapshots: snapshots,
            selectedSnapshot: selectedSnapshot,
            selectedAccountID: selectedAccountID,
            window: window,
            showUsed: showUsed,
            showEmailInitial: showEmailInitial)
    }

    private static func reading(
        id: String,
        label: String,
        sessionUsed: Double,
        weeklyUsed: Double) -> MultiAccountMenuBarDisplay.Reading
    {
        MultiAccountMenuBarDisplay.Reading(
            id: id,
            label: label,
            snapshot: UsageSnapshot(
                primary: RateWindow(
                    usedPercent: sessionUsed,
                    windowMinutes: 300,
                    resetsAt: nil,
                    resetDescription: nil),
                secondary: RateWindow(
                    usedPercent: weeklyUsed,
                    windowMinutes: 10080,
                    resetsAt: nil,
                    resetDescription: nil),
                updatedAt: Date(timeIntervalSince1970: 100)))
    }

    private static func account(
        id: String,
        email: String,
        source: CodexActiveSource = .liveSystem,
        workspaceAccountID: String? = nil,
        storedAccountID: UUID? = nil,
        isActive: Bool = false,
        isLive: Bool = true) -> CodexVisibleAccount
    {
        CodexVisibleAccount(
            id: id,
            email: email,
            workspaceAccountID: workspaceAccountID,
            storedAccountID: storedAccountID,
            selectionSource: source,
            isActive: isActive,
            isLive: isLive,
            canReauthenticate: true,
            canRemove: source != .liveSystem)
    }

    private static func accountSnapshot(
        _ account: CodexVisibleAccount,
        fiveHourUsed: Double,
        weeklyUsed: Double)
        -> CodexAccountUsageSnapshot
    {
        CodexAccountUsageSnapshot(
            account: account,
            snapshot: UsageSnapshot(
                primary: RateWindow(
                    usedPercent: fiveHourUsed,
                    windowMinutes: 300,
                    resetsAt: nil,
                    resetDescription: nil),
                secondary: RateWindow(
                    usedPercent: weeklyUsed,
                    windowMinutes: 10080,
                    resetsAt: nil,
                    resetDescription: nil),
                updatedAt: Date(timeIntervalSince1970: 100)),
            error: nil,
            sourceLabel: "test")
    }
}
