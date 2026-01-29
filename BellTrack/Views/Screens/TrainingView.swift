import SwiftUI

struct TrainingView: View {

    @State private var blocks: [Block] = []
    @State private var workouts: [Workout] = []
    @State private var expandedBlockIDs: Set<String> = []

    @State private var showingSaveBlock = false
    @State private var editingBlock: Block?

    var body: some View {
        VStack(spacing: 0) {

            // HEADER
            HStack {
                Text("Training")
                    .font(Theme.Font.title)
                    .foregroundColor(.brand.textPrimary)

                Spacer()
            }
            .padding(.horizontal, Theme.Space.md)
            .padding(.vertical, Theme.Space.sm)
            .background(Color.brand.background)

            Divider()
                .foregroundColor(Color.brand.border)

            // CONTENT
            ZStack {
                Color.brand.background.ignoresSafeArea()

                List {
                    ForEach(
                        blocks.sorted { $0.startDate > $1.startDate }
                    ) { block in
                        Section {
                            blockRow(block)
                        }
                    }
                    .onDelete(perform: deleteBlock)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .sheet(isPresented: $showingSaveBlock) {
            SaveBlockView(block: editingBlock)
        }
        .task { await load() }
        .refreshable { await load() }
    }

    // MARK: - Block Row

    private func blockRow(_ block: Block) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {

            Button {
                toggle(block.id)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(block.name)
                            .font(Theme.Font.body)
                            .foregroundColor(.brand.textPrimary)

                        Text(blockSubtitle(block))
                            .font(Theme.Font.meta)
                            .foregroundColor(.brand.textSecondary)
                    }

                    Spacer()

                    Image(systemName: expandedBlockIDs.contains(block.id) ? "chevron.down" : "chevron.right")
                        .foregroundColor(.brand.textSecondary)
                }
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button("Edit Block") {
                    editingBlock = block
                    showingSaveBlock = true
                }
            }

            if expandedBlockIDs.contains(block.id) {
                VStack(alignment: .leading, spacing: Theme.Space.sm) {

                    ForEach(block.workouts) { template in
                        Text("Workout \(template.name)")
                            .font(Theme.Font.meta)
                            .foregroundColor(.brand.textPrimary)
                    }

                    Divider()

                    ForEach(workoutsForBlock(block.id)) { workout in
                        workoutRow(workout)
                    }
                }
                .padding(.top, Theme.Space.xs)
            }
        }
        .padding(.vertical, Theme.Space.xs)
    }

    // MARK: - Workout Row

    private func workoutRow(_ workout: Workout) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.workoutName)
                    .font(Theme.Font.meta)
                    .foregroundColor(.brand.textPrimary)

                Text(workout.date.formatted(date: .abbreviated, time: .omitted))
                    .font(Theme.Font.meta)
                    .foregroundColor(.brand.textSecondary)
            }

            Spacer()
        }
        .swipeActions {
            Button(role: .destructive) {
                Task { await deleteWorkout(workout) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Helpers

    private func workoutsForBlock(_ blockID: String) -> [Workout] {
        workouts
            .filter { $0.blockID == blockID }
            .sorted { $0.date > $1.date }
    }

    private func toggle(_ blockID: String) {
        if expandedBlockIDs.contains(blockID) {
            expandedBlockIDs.remove(blockID)
        } else {
            expandedBlockIDs.insert(blockID)
        }
    }

    private func blockSubtitle(_ block: Block) -> String {
        let end = Calendar.current.date(
            byAdding: .weekOfYear,
            value: block.durationWeeks,
            to: block.startDate
        )!

        return "\(block.startDate.formatted(date: .abbreviated, time: .omitted)) – \(end.formatted(date: .abbreviated, time: .omitted))"
    }

    // MARK: - Data

    private func load() async {
        do {
            blocks = try await FirestoreService.shared.fetchBlocks()
            workouts = try await FirestoreService.shared.fetchWorkouts()
        } catch {
            print(error)
        }
    }

    private func deleteBlock(at offsets: IndexSet) {
        for index in offsets {
            let block = blocks[index]
            Task {
                try await FirestoreService.shared.deleteBlock(blockID: block.id)
                await load()
            }
        }
    }

    private func deleteWorkout(_ workout: Workout) async {
        do {
            try await FirestoreService.shared.deleteWorkout(workoutID: workout.id)
            await load()
        } catch {
            print(error)
        }
    }
}
