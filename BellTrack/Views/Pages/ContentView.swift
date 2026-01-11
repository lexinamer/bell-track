import SwiftUI
import Combine
import FirebaseAuth

// MARK: - Data change notification

extension Notification.Name {
    static let bellTrackDataDidChange = Notification.Name("bellTrackDataDidChange")
}

// MARK: - App Router

final class AppRouter: ObservableObject {

    enum RootPage {
        case home
    }

    @Published var page: RootPage = .home

    /// Remembers which root page opened the current sheet so we can return there after save.
    @Published var sheetOriginPage: RootPage?

    enum Sheet: Identifiable {
        case settings
        case blockDetail(Block)
        case editBlock(Block?) // nil = create
        case editSession(block: Block, session: Session?) // nil = create

        var id: String {
            switch self {
            case .settings:
                return "settings"
            case .blockDetail(let block):
                return "blockDetail_\(block.id ?? "new")"
            case .editBlock(let block):
                return "editBlock_\(block?.id ?? "new")"
            case .editSession(let block, let session):
                return "editSession_\(block.id ?? "new")_\(session?.id ?? "new")"
            }
        }
    }

    @Published var sheet: Sheet?

    private func captureSheetOrigin() {
        sheetOriginPage = page
    }

    func openSettings() {
        captureSheetOrigin()
        sheet = .settings
    }

    func openBlockDetail(_ block: Block) {
        captureSheetOrigin()
        sheet = .blockDetail(block)
    }

    func openCreateBlock() {
        captureSheetOrigin()
        sheet = .editBlock(nil)
    }

    func openEditBlock(_ block: Block) {
        captureSheetOrigin()
        sheet = .editBlock(block)
    }

    func openLogSession(for block: Block) {
        captureSheetOrigin()
        sheet = .editSession(block: block, session: nil)
    }

    func openEditSession(block: Block, session: Session) {
        captureSheetOrigin()
        sheet = .editSession(block: block, session: session)
    }

    func closeSheet() {
        sheet = nil
        sheetOriginPage = nil
    }

    /// Hard reset to a safe baseline (use on login/logout).
    func resetToHome() {
        closeSheet()
        page = .home
    }
}

// MARK: - ContentView

struct ContentView: View {
    @EnvironmentObject private var authService: AuthService
    @StateObject private var router = AppRouter()

    private let firestoreService = FirestoreService()

    var body: some View {
        Group {
            if authService.user == nil {
                LoginView()
            } else {
                signedInShell
            }
        }
        // ✅ This is the fix:
        // Any time auth flips (logout/login), dump any open sheet and route to Home.
        .onChange(of: authService.user?.uid) { _, _ in
            router.resetToHome()
        }
    }

    private var signedInShell: some View {
        NavigationStack {
            ZStack {
                Color.brand.background.ignoresSafeArea()
                HomeView()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .environmentObject(router)
        .fullScreenCover(item: $router.sheet) { sheet in
            switch sheet {

            case .settings:
                SettingsView()
                    .environmentObject(router)

            case .blockDetail(let block):
                BlockDetailView(block: block)
                    .environmentObject(router)

            case .editBlock(let existingBlock):
                AddEditBlockView(existingBlock) { savedBlock in Task {
                        guard let uid = authService.user?.uid else {
                            await MainActor.run { router.closeSheet() }
                            return
                        }

                        do {
                            try await firestoreService.saveBlock(userId: uid, block: savedBlock)
                        } catch {
                            // v1: fail quietly
                        }

                        NotificationCenter.default.post(name: .bellTrackDataDidChange, object: nil)

                        await MainActor.run {
                            router.page = router.sheetOriginPage ?? router.page
                            router.closeSheet()
                        }
                    }
                }
                .environmentObject(router)

            case .editSession(let block, let existingSession):
                AddEditSessionView(block: block, session: existingSession, onSave: { savedSession in
                    Task {
                        guard let uid = authService.user?.uid else {
                            await MainActor.run { router.closeSheet() }
                            return
                        }

                        do {
                            try await firestoreService.saveSession(userId: uid, session: savedSession)
                        } catch {
                            // v1: fail quietly
                        }

                        NotificationCenter.default.post(name: .bellTrackDataDidChange, object: nil)

                        await MainActor.run {
                            router.page = router.sheetOriginPage ?? router.page
                            router.closeSheet()
                        }
                    }
                })
                .environmentObject(router)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button { router.openSettings() } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.brand.textSecondary)
            }
            .accessibilityLabel("Settings")
        }

        ToolbarItem(placement: .principal) {
            Text("Workouts")
                .font(TextStyles.title)
                .foregroundColor(Color.brand.textPrimary)
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            Button { router.openCreateBlock() } label: {
                Image(systemName: "rectangle.stack.badge.plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.brand.textSecondary)
            }
            .accessibilityLabel("New Block")
        }
    }
}
