import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    @State private var showingBlockCreation = false
    @State private var showingEndBlockAlert = false
    @State private var showingRenameSheet = false
    @State private var newBlockName = ""
    @State private var progressData: [String: (first: String?, last: String?)] = [:]

    var body: some View {
        ZStack {
            Color.brand.background.ignoresSafeArea()

            if appViewModel.isLoading {
                ProgressView()
            } else if let block = appViewModel.activeBlock {
                activeBlockContent(block)
            } else {
                noBlockContent
            }
        }
        .sheet(isPresented: $showingBlockCreation) {
            BlockCreationView()
        }
        .sheet(isPresented: $showingRenameSheet) {
            renameSheet
        }
        .alert("End Block", isPresented: $showingEndBlockAlert) {
            Button("Cancel", role: .cancel) { }
            Button("End Block", role: .destructive) {
                Task {
                    await appViewModel.endCurrentBlock()
                }
            }
        } message: {
            Text("This will mark the current block as completed. You can view it in History.")
        }
    }

    private func activeBlockContent(_ block: Block) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.lg) {
                blockHeader(block)
                progressSection(block)
                actionsSection
            }
            .padding(Theme.Space.md)
        }
        .refreshable {
            await appViewModel.loadData()
            await loadProgress(for: block)
        }
        .task {
            await loadProgress(for: block)
        }
    }

    private func blockHeader(_ block: Block) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(block.name)
                .font(.system(size: Theme.TypeSize.xl, weight: .semibold))
                .foregroundColor(.brand.textPrimary)

            Text(block.statusText)
                .font(Theme.Font.body)
                .foregroundColor(.brand.textSecondary)

            Text(block.dateRangeText)
                .font(Theme.Font.meta)
                .foregroundColor(.brand.textSecondary)
        }
    }

    private func progressSection(_ block: Block) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            Text("Progress")
                .font(Theme.Font.title)
                .foregroundColor(.brand.textPrimary)

            ForEach(block.workouts) { workout in
                workoutProgressCard(workout)
            }
        }
    }

    private func workoutProgressCard(_ workout: Workout) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("Workout \(workout.name)")
                .font(Theme.Font.body)
                .fontWeight(.medium)
                .foregroundColor(.brand.textPrimary)

            ForEach(workout.exercises) { exercise in
                exerciseProgressRow(exercise)
            }
        }
        .padding(Theme.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brand.surface)
        .cornerRadius(Theme.Radius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .stroke(Color.brand.border, lineWidth: 1)
        )
    }

    private func exerciseProgressRow(_ exercise: Exercise) -> some View {
        let progress = progressData[exercise.id]

        return HStack {
            Text(exercise.name)
                .font(Theme.Font.meta)
                .foregroundColor(.brand.textPrimary)

            Spacer()

            if let first = progress?.first, let last = progress?.last {
                Text("\(first) → \(last)")
                    .font(Theme.Font.meta)
                    .foregroundColor(.brand.textSecondary)
            } else {
                Text("—")
                    .font(Theme.Font.meta)
                    .foregroundColor(.brand.textSecondary)
            }
        }
    }

    private var actionsSection: some View {
        VStack(spacing: Theme.Space.sm) {
            Button {
                if let block = appViewModel.activeBlock {
                    newBlockName = block.name
                }
                showingRenameSheet = true
            } label: {
                HStack {
                    Image(systemName: "pencil")
                    Text("Rename Block")
                }
                .font(Theme.Font.body)
                .foregroundColor(.brand.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(Theme.Space.md)
                .background(Color.brand.surface)
                .cornerRadius(Theme.Radius.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .stroke(Color.brand.border, lineWidth: 1)
                )
            }

            Button {
                showingEndBlockAlert = true
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle")
                    Text("End Block")
                }
                .font(Theme.Font.body)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(Theme.Space.md)
                .background(Color.brand.surface)
                .cornerRadius(Theme.Radius.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .stroke(Color.brand.border, lineWidth: 1)
                )
            }
        }
    }

    private var noBlockContent: some View {
        VStack(spacing: Theme.Space.lg) {
            Text("No active block")
                .font(Theme.Font.title)
                .foregroundColor(.brand.textPrimary)

            Text("Create a training block to start tracking your workouts.")
                .font(Theme.Font.body)
                .foregroundColor(.brand.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                showingBlockCreation = true
            } label: {
                Text("Create Block")
                    .font(Theme.Font.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, Theme.Space.lg)
                    .padding(.vertical, Theme.Space.md)
                    .background(Color.brand.primary)
                    .cornerRadius(Theme.Radius.sm)
            }
        }
        .padding(Theme.Space.xl)
    }

    private var renameSheet: some View {
        NavigationStack {
            ZStack {
                Color.brand.background.ignoresSafeArea()

                VStack(alignment: .leading, spacing: Theme.Space.md) {
                    Text("Block Name")
                        .font(Theme.Font.meta)
                        .foregroundColor(.brand.textSecondary)

                    TextField("Block name", text: $newBlockName)
                        .font(Theme.Font.body)
                        .padding(Theme.Space.md)
                        .background(Color.brand.surface)
                        .cornerRadius(Theme.Radius.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                .stroke(Color.brand.border, lineWidth: 1)
                        )

                    Spacer()
                }
                .padding(Theme.Space.md)
            }
            .navigationTitle("Rename Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingRenameSheet = false
                    }
                    .foregroundColor(.brand.textSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await renameBlock()
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func loadProgress(for block: Block) async {
        var newProgress: [String: (first: String?, last: String?)] = [:]

        for workout in block.workouts {
            for exercise in workout.exercises {
                let progress = await appViewModel.getProgress(for: exercise.id)
                newProgress[exercise.id] = progress
            }
        }

        progressData = newProgress
    }

    private func renameBlock() async {
        guard var block = appViewModel.activeBlock else { return }
        block.name = newBlockName.trimmingCharacters(in: .whitespacesAndNewlines)
        await appViewModel.saveBlock(block)
        showingRenameSheet = false
    }
}
