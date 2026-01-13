import SwiftUI
import FirebaseAuth

extension Notification.Name {
    static let bellTrackDataDidChange = Notification.Name("bellTrackDataDidChange")
}

struct HomeView: View {

    @EnvironmentObject private var authService: AuthService
    @StateObject private var vm = HomeViewModel()

    @State private var showingAddBlock = false
    @State private var editingBlock: Block? = nil
    @State private var sessionRoute: SessionRoute? = nil

    @State private var blockPendingDelete: Block? = nil
    @State private var showDeleteBlockConfirm = false

    @State private var expandedBlockIds: Set<String> = []

    private var userId: String { authService.user?.uid ?? "" }

    var body: some View {
        List {

            header
                .listRowBackground(Color.brand.background)
                .listRowSeparator(.hidden)
                .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))

            if vm.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.brand.background)
                .listRowSeparator(.hidden)

            } else if vm.filteredBlocks.isEmpty {
                emptyStateRow
                    .listRowBackground(Color.brand.background)
                    .listRowSeparator(.hidden)

            } else {
                ForEach(vm.filteredBlocks) { block in
                    let blockId = stableBlockId(for: block)

                    let allSessions = vm.sessions(for: block)
                    let isExpanded = expandedBlockIds.contains(blockId)
                    let visibleSessions = isExpanded ? allSessions : Array(allSessions.prefix(3))

                    BlockRow(
                        block: block,
                        onEdit: { editingBlock = block },
                        onComplete: {
                            Task { await vm.completeBlock(userId: userId, block: block) }
                        },
                        onDelete: {
                            blockPendingDelete = block
                            showDeleteBlockConfirm = true
                        }
                    )
                    .listRowBackground(Color.brand.surface)
                    .listRowSeparator(.hidden)
                    .listRowInsets(.init(top: Theme.Space.sm, leading: 0, bottom: 0, trailing: 0))

                    ForEach(visibleSessions) { session in
                        SessionRow(
                            session: session,
                            onTap: { sessionRoute = SessionRoute(block: block, session: session) }
                        )
                        .listRowBackground(Color.brand.surface)
                        .listRowSeparator(.hidden)
                        .listRowInsets(.init(top: 0, leading: Theme.Space.lg, bottom: 0, trailing: Theme.Space.lg))
                    }

                    if allSessions.count > 3 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                toggleExpanded(blockId)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(isExpanded ? "Show less" : "Show all (\(allSessions.count))")
                                    .font(Theme.Font.meta)
                                    .foregroundColor(Color.brand.textSecondary)

                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color.brand.textSecondary)
                                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.brand.surface)
                        .listRowSeparator(.hidden)
                        .listRowInsets(.init(top: 0, leading: Theme.Space.lg, bottom: 0, trailing: Theme.Space.lg))
                    }

                    Button {
                        guard !block.isCompleted else { return }
                        let draft = vm.makePrefilledNewSession(userId: userId, block: block)
                        sessionRoute = SessionRoute(block: block, session: draft)
                    } label: {
                        Label("Add session", systemImage: "plus")
                            .font(Theme.Font.body)
                            .fontWeight(.semibold)
                            .foregroundColor(block.isCompleted ? Color.brand.textSecondary : Color.brand.primary)
                    }
                    .buttonStyle(.plain)
                    .disabled(block.isCompleted)
                    .listRowBackground(Color.brand.surface)
                    .listRowSeparator(.hidden)
                    .listRowInsets(.init(top: Theme.Space.sm, leading: Theme.Space.lg, bottom: Theme.Space.md, trailing: Theme.Space.lg))
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.brand.background)
        .refreshable { await vm.load(userId: userId) }
        .task { await vm.load(userId: userId) }
        .onReceive(NotificationCenter.default.publisher(for: .bellTrackDataDidChange)) { _ in
            Task { await vm.load(userId: userId) }
        }

        .sheet(isPresented: $showingAddBlock) {
            AddEditBlockView(nil) { block in
                Task { await vm.saveBlock(userId: userId, block: block) }
                showingAddBlock = false
            }
        }
        .sheet(item: $editingBlock) { block in
            AddEditBlockView(block) { updated in
                Task { await vm.saveBlock(userId: userId, block: updated) }
                editingBlock = nil
            }
        }
        .sheet(item: $sessionRoute) { route in
            AddEditSessionView(
                block: route.block,
                session: route.session,
                onSave: { session in
                    Task { await vm.saveSession(userId: userId, session: session) }
                    sessionRoute = nil
                },
                onDelete: route.session?.id == nil ? nil : {
                    guard let s = route.session else { return }
                    Task { await vm.deleteSession(userId: userId, session: s) }
                    sessionRoute = nil
                }
            )
        }

        .confirmationDialog("Delete block?", isPresented: $showDeleteBlockConfirm) {
            Button("Delete", role: .destructive) {
                guard let b = blockPendingDelete else { return }
                Task { await vm.deleteBlock(userId: userId, block: b) }
                blockPendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                blockPendingDelete = nil
            }
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Space.md) {

                Button {
                    NotificationCenter.default.post(name: .bellTrackDataDidChange, object: nil)
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundColor(Color.brand.textPrimary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Workouts")
                    .font(Theme.Font.title)
                    .foregroundColor(Color.brand.textPrimary)

                Spacer()

                if vm.filter == .active {
                    Button { showingAddBlock = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundColor(Color.brand.textPrimary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.frame(width: 44, height: 44)
                }
            }
            .frame(height: 44)
            .padding(.horizontal, Theme.Space.md)

            Rectangle()
                .fill(Color.brand.border)
                .frame(height: 1)

            Picker("", selection: $vm.filter) {
                ForEach(BlockFilter.allCases, id: \.self) { Text($0.rawValue) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Theme.Space.md)
            .padding(.vertical, Theme.Space.md)
        }
    }

    private var emptyStateRow: some View {
        VStack(spacing: Theme.Space.md) {
            Text("No blocks yet").font(Theme.Font.title)

            Button("+ Add Block") { showingAddBlock = true }
                .font(Theme.Font.link)
                .foregroundColor(Color.brand.primary)
        }
        .padding(.top, Theme.Space.lg)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func stableBlockId(for block: Block) -> String {
        block.id ?? "\(block.userId)|\(block.name)|\(block.startDate.timeIntervalSince1970)"
    }

    private func toggleExpanded(_ blockId: String) {
        if expandedBlockIds.contains(blockId) {
            expandedBlockIds.remove(blockId)
        } else {
            expandedBlockIds.insert(blockId)
        }
    }
}
