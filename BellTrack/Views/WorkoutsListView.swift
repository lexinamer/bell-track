import SwiftUI
import FirebaseAuth

struct IdentifiableDate: Identifiable {
    let id = UUID()
    let date: Date
}

struct WorkoutsListView: View {
    @EnvironmentObject var authService: AuthService
    @State private var blocks: [WorkoutBlock] = []
    @State private var showAddBlock = false
    @State private var showSettings = false
    @State private var editingBlock: WorkoutBlock?
    @State private var duplicatingBlock: WorkoutBlock?
    @State private var isLoading = true
    @State private var dateNotes: [Date: DateNote] = [:]
    @State private var selectedDate: IdentifiableDate?
    private let firestoreService = FirestoreService()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brand.background.ignoresSafeArea()
                if isLoading {
                    ProgressView()
                } else if blocks.isEmpty {
                    VStack(spacing: Spacing.md) {
                        Text("No workouts yet")
                            .font(.system(size: Typography.lg))
                            .foregroundColor(Color.brand.textSecondary)
                        Text("Tap + to add your first block")
                            .font(.system(size: Typography.sm))
                            .foregroundColor(Color.brand.textSecondary)
                    }
                } else {
                    WorkoutsList(
                        groupedBlocks: groupedBlocks,
                        dateNotes: dateNotes,  // Add this
                        onTap: { block in
                            editingBlock = block
                        },
                        onDuplicate: { block in
                            duplicatingBlock = block
                        },
                        onDelete: deleteBlock,
                        onDateTap: { date in
                            selectedDate = IdentifiableDate(date: date)
                        }
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Workouts")
                        .font(.system(size: Typography.xl, weight: .semibold))
                        .foregroundColor(Color.brand.textPrimary)
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        if let email = authService.user?.email {
                            Label(email, systemImage: "")
                                .labelStyle(.titleOnly)
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            logOut()
                        } label: {
                            Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: Typography.xl))
                    }
                    .tint(Color.brand.textPrimary)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddBlock = true
                    } label: {
                        Label("plus", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.brand.secondary)
                }
                
            }
            .fullScreenCover(isPresented: $showAddBlock, onDismiss: {
                Task { await loadBlocks() }
            }) {
                AddEditBlockView()
            }
            .fullScreenCover(item: $editingBlock, onDismiss: {
                Task { await loadBlocks() }
            }) { block in
                AddEditBlockView(existingBlock: block, isEditing: true)
            }
            .fullScreenCover(item: $duplicatingBlock, onDismiss: {
                Task { await loadBlocks() }
            }) { block in
                AddEditBlockView(existingBlock: block, isEditing: false)
            }
            .fullScreenCover(item: $selectedDate, onDismiss: {
                Task { await loadDateNotes() }
            }) { identifiableDate in
                DateNoteView(
                    userId: authService.user?.uid ?? "",
                    date: identifiableDate.date,
                    existingNote: dateNotes[Calendar.current.startOfDay(for: identifiableDate.date)]
                )
            }
            .task {
                await loadBlocks()
                await loadDateNotes()
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
    
    private func loadDateNotes() async {
        guard let userId = authService.user?.uid else { return }
        
        let dates = Array(groupedBlocks.keys)
        var notes: [Date: DateNote] = [:]
        
        for date in dates {
            if let note = try? await firestoreService.fetchDateNote(userId: userId, date: date) {
                notes[Calendar.current.startOfDay(for: date)] = note
            }
        }
        
        await MainActor.run {
            dateNotes = notes
        }
    }
    
    private func logOut() {
        do {
            try authService.signOut()
        } catch {
            print("Error signing out: \(error)")
        }
    }
}

struct WorkoutsList: View {
    let groupedBlocks: [Date: [WorkoutBlock]]
    let dateNotes: [Date: DateNote]
    let onTap: (WorkoutBlock) -> Void
    let onDuplicate: (WorkoutBlock) -> Void
    let onDelete: (WorkoutBlock) -> Void
    let onDateTap: (Date) -> Void
    
    var body: some View {
        List {
            ForEach(sortedDates, id: \.self) { date in
                Section {
                    // Show note if it exists
                    if let note = dateNotes[date], !note.note.isEmpty {
                        Text("Notes: \(note.note)")
                            .font(.system(size: Typography.sm))
                            .foregroundColor(Color.brand.textSecondary)
                            .padding(.horizontal, WorkoutListSpacing.noteHorizontalPadding)
                            .padding(.vertical, WorkoutListSpacing.noteVerticalPadding)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.brand.surface)
                            .cornerRadius(CornerRadius.sm)
                            .listRowInsets(EdgeInsets(
                                top: 0,
                                leading: 0,
                                bottom: WorkoutListSpacing.noteBottom,
                                trailing: 0
                            ))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.brand.background)
                    }
                    
                    ForEach(Array((groupedBlocks[date] ?? []).enumerated()), id: \.element.id) { index, block in
                        let isLastBlock = index == (groupedBlocks[date]?.count ?? 0) - 1
                        
                        BlockCard(
                            block: block,
                            onTap: { onTap(block) },
                            onDuplicate: { onDuplicate(block) },
                            onDelete: { onDelete(block) }
                        )
                        .listRowInsets(EdgeInsets(
                            top: 0,
                            leading: 0,
                            bottom: isLastBlock ? WorkoutListSpacing.lastBlockBottom : WorkoutListSpacing.blockBottom,
                            trailing: 0
                        ))
                        .listRowSeparator(.hidden)
                    }
                    
                    Color.brand.border
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
                        .listRowInsets(EdgeInsets(
                            top: 0,
                            leading: 0,
                            bottom: WorkoutListSpacing.dividerBottom,
                            trailing: 0
                        ))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    
                } header: {
                    DateHeader(
                        date: date,
                        hasNote: dateNotes[date] != nil,
                        onTap: { onDateTap(date) }
                    )
                    .listRowInsets(EdgeInsets())
                }
                .listSectionSpacing(0)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    private var sortedDates: [Date] {
        groupedBlocks.keys
            .filter { (groupedBlocks[$0] ?? []).count > 0 }
            .sorted(by: >)
    }
}

struct DateHeader: View {
    let date: Date
    let hasNote: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: WorkoutListSpacing.horizontalPadding) {
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: Typography.md, weight: .bold))
                    .foregroundColor(Color.brand.textPrimary)
                                
                Image(systemName: "doc.plaintext")
                    .font(.system(size: Typography.sm))
                    .foregroundColor(Color.brand.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, WorkoutListSpacing.horizontalPadding)
            .background(Color.brand.background)
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(
            top: 0,
            leading: 0,
            bottom: hasNote ? WorkoutListSpacing.dateBottom : WorkoutListSpacing.dateBottomNoNote,
            trailing: 0
        ))
    }
}

struct BlockCard: View {
    let block: WorkoutBlock
    let onTap: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: WorkoutListSpacing.blockLineSpacing) {
            Text(exerciseLine)
                .font(.system(size: Typography.md))
                .foregroundColor(Color.brand.textPrimary)
            
            // Second line: style and weight
            if !detailsLine.isEmpty {
                Text(detailsLine)
                    .font(.system(size: Typography.md))
                    .foregroundColor(Color.brand.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, WorkoutListSpacing.horizontalPadding)
        .background(Color.brand.background)
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
        let exerciseParts = block.exercises.map { exercise in
            if let reps = exercise.reps {
                return "\(reps) \(exercise.name)"
            } else {
                return exercise.name
            }
        }
        let typeText = block.type.map { " \($0.rawValue)" } ?? ""
        return "\(exerciseParts.joined(separator: " ")) x \(block.rounds)\(typeText)"
    }

    private var detailsLine: String {
        var parts: [String] = []
        
        // Combine style and weight together
        var styleWeight: [String] = []
        if let style = block.style {
            styleWeight.append(style.rawValue)
        }
        if let weight = block.weight {
            styleWeight.append("\(weight)\(block.unit)")
        }
        if !styleWeight.isEmpty {
            parts.append(styleWeight.joined(separator: " "))
        }
        
        // Add time separately
        if let time = block.time, let timeUnit = block.timeUnit {
            // Format to remove unnecessary decimals (2.0 → 2, 2.5 → 2.5)
            let formattedTime = time.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(time)) : String(time)
            parts.append("\(formattedTime) \(timeUnit)")
        }
        
        return parts.joined(separator: " • ")
    }
}
