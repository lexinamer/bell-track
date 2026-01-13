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

    @Published var modal: Modal?
    @Published var modalOrigin: ModalOrigin?

    enum Modal: Identifiable {
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

    enum ModalOrigin {
        case home
        case blockDetail(Block)
    }

    private func captureModalOrigin() {
        if let modal = modal {
            switch modal {
            case .blockDetail(let block):
                modalOrigin = .blockDetail(block)
            default:
                modalOrigin = .home
            }
        } else {
            modalOrigin = .home
        }
    }

    func openSettings() {
        captureModalOrigin()
        modal = .settings
    }

    func openBlockDetail(_ block: Block) {
        captureModalOrigin()
        modal = .blockDetail(block)
    }

    func openCreateBlock() {
        captureModalOrigin()
        modal = .editBlock(nil)
    }

    func openEditBlock(_ block: Block) {
        captureModalOrigin()
        modal = .editBlock(block)
    }

    func openLogSession(for block: Block) {
        captureModalOrigin()
        modal = .editSession(block: block, session: nil)
    }

    func openEditSession(block: Block, session: Session) {
        captureModalOrigin()
        modal = .editSession(block: block, session: session)
    }

    func closeModal() {
        modal = nil
        modalOrigin = nil
    }

    /// Hard reset to a safe baseline (use on login/logout).
    func resetToHome() {
        closeModal()
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
        // Any time auth flips (logout/login), dump any open modal and route to Home.
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

        // Full-screen covers: Settings + Block Detail + Add/Edit Block + Add/Edit Session
        .fullScreenCover(item: $router.modal) { modal in
            switch modal {
            case .settings:
                SettingsView()
                    .environmentObject(router)

            case .blockDetail(let block):
                BlockDetailView(block: block)
                    .environmentObject(router)

            case .editBlock(let existingBlock):
                AddEditBlockView(existingBlock) { savedBlock in
                    let isEditing = (existingBlock != nil)

                    Task {
                        guard let uid = authService.user?.uid else {
                            await MainActor.run { router.closeModal() }
                            return
                        }

                        do {
                            try await firestoreService.saveBlock(userId: uid, block: savedBlock)
                        } catch {
                            // v1: fail quietly
                        }

                        NotificationCenter.default.post(name: .bellTrackDataDidChange, object: nil)

                        await MainActor.run {
                            if isEditing {
                                // Return to Block Detail and ensure it re-renders with the updated block.
                                router.modal = .blockDetail(savedBlock)
                            } else {
                                // New blocks are only created from Home.
                                router.resetToHome()
                            }
                        }
                    }
                }
                .environmentObject(router)

            case .editSession(let block, let existingSession):
                AddEditSessionView(block: block, session: existingSession) { savedSession in
                    Task {
                        guard let uid = authService.user?.uid else {
                            await MainActor.run { router.closeModal() }
                            return
                        }

                        do {
                            try await firestoreService.saveSession(userId: uid, session: savedSession)
                        } catch {
                            // v1: fail quietly
                        }

                        NotificationCenter.default.post(name: .bellTrackDataDidChange, object: nil)

                        await MainActor.run {
                            switch router.modalOrigin {
                            case .blockDetail(let originBlock):
                                router.modal = .blockDetail(originBlock)
                            default:
                                router.closeModal()
                            }
                        }
                    }
                }
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
