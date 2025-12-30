import SwiftUI
import FirebaseAuth

struct WorkoutsListView: View {
    @EnvironmentObject var authService: AuthService
    @State private var blocks: [WorkoutBlock] = []
    @State private var showAddBlock = false
    @State private var showSettings = false
    @State private var editingBlock: WorkoutBlock?
    @State private var duplicatingBlock: WorkoutBlock?
    @State private var isLoading = true
    private let firestoreService = FirestoreService()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brand.surface.ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                } else if blocks.isEmpty {
                    VStack(spacing: Spacing.md) {
                        Text("No workouts yet")
                            .font(.system(size: 18))
                            .foregroundColor(Color.brand.textSecondary)
                        Text("Tap + to add your first block")
                            .font(.system(size: 14))
                            .foregroundColor(Color.brand.textSecondary)
                    }
                } else {
                    ScrollView {
                        WorkoutsList(
                            groupedBlocks: groupedBlocks,
                            onTap: { block in
                                editingBlock = block
                            },
                            onDuplicate: { block in
                                duplicatingBlock = block
                            },
                            onDelete: deleteBlock
                        )
                    }
                }
            }
            .navigationTitle("Workouts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape")
                            .foregroundColor(Color.brand.textPrimary)
                    }
                    .buttonStyle(.plain)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddBlock = true }) {
                        ZStack {
                            Circle()
                                .fill(Color.brand.primary)
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .sheet(isPresented: $showAddBlock, onDismiss: {
                Task { await loadBlocks() }
            }) {
                AddEditBlockView()
            }
            .sheet(item: $editingBlock, onDismiss: {
                Task { await loadBlocks() }
            }) { block in
                AddEditBlockView(existingBlock: block, isEditing: true)
            }
            .sheet(item: $duplicatingBlock, onDismiss: {
                Task { await loadBlocks() }
            }) { block in
                AddEditBlockView(existingBlock: block, isEditing: false)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }
    
    private var groupedBlocks: [Date: [WorkoutBlock]] {
        Dictionary(grouping: blocks) { block in
            Calendar.current.startOfDay(for: block.date)
        }
    }
    
    private func loadBlocks() async {
        guard let userId = authService.user?.uid else { return }
        
        do {
            blocks = try await firestoreService.fetchBlocks(userId: userId)
            isLoading = false
        } catch {
            print("Error loading blocks: \(error)")
            isLoading = false
        }
    }
    
    private func deleteBlock(_ block: WorkoutBlock) {
        guard let id = block.id else { return }
        
        Task {
            do {
                try await firestoreService.deleteBlock(id: id)
                await loadBlocks()
            } catch {
                print("Error deleting block: \(error)")
            }
        }
    }
}

struct WorkoutsList: View {
    let groupedBlocks: [Date: [WorkoutBlock]]
    let onTap: (WorkoutBlock) -> Void
    let onDuplicate: (WorkoutBlock) -> Void
    let onDelete: (WorkoutBlock) -> Void
    
    var body: some View {
        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
            ForEach(sortedDates, id: \.self) { date in
                Section {
                    ForEach(Array((groupedBlocks[date] ?? []).enumerated()), id: \.element.id) { index, block in
                        VStack(spacing: 0) {
                            BlockCard(
                                block: block,
                                onTap: { onTap(block) },
                                onDuplicate: { onDuplicate(block) },
                                onDelete: { onDelete(block) }
                            )
                            
                            if index < (groupedBlocks[date]?.count ?? 0) - 1 {
                                Divider()
                                    .background(Color.brand.border)
                                    .padding(.horizontal, Spacing.md)
                            }
                        }
                    }
                    
                    // Full-width divider after last block of date
                    Divider()
                        .background(Color.brand.border)
                        .padding(.bottom, Spacing.lg)
                } header: {
                    DateHeader(date: date)
                }
            }
        }
    }
    
    private var sortedDates: [Date] {
        groupedBlocks.keys.sorted(by: >)
    }
}

struct DateHeader: View {
    let date: Date
    
    var body: some View {
        Text(date.formatted(date: .abbreviated, time: .omitted))
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(Color.brand.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.sm)
            .background(Color.brand.surface)
    }
}

struct BlockCard: View {
    let block: WorkoutBlock
    let onTap: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // First line: exercises and rounds/type
            Text(exerciseLine)
                .font(.system(size: 16))
                .foregroundColor(Color.brand.textPrimary)
            
            // Second line: style and weight
            Text(detailsLine)
                .font(.system(size: 14))
                .foregroundColor(Color.brand.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.md)
        .background(Color.brand.surface)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            
            Button(action: onDuplicate) {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
            .tint(Color.brand.primary)
        }
    }
    
    private var exerciseLine: String {
        let exerciseParts = block.exercises.map { "\($0.reps) \($0.name)" }
        return "\(exerciseParts.joined(separator: " ")) x \(block.rounds) \(block.type.rawValue)"
    }
    
    private var detailsLine: String {
        "\(block.style.rawValue) \(block.weight)kg"
    }
}
