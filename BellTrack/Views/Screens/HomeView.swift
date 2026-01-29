import SwiftUI

struct HomeView: View {

    @Binding var showLogWorkout: Bool

    @State private var blocks: [Block] = []
    @State private var workouts: [Workout] = []
    @State private var isLoading = true
    @State private var showingCreateBlock = false

    private var activeBlock: Block? {
        blocks
            .sorted { $0.startDate > $1.startDate }
            .first
    }

    var body: some View {
        VStack(spacing: 0) {

            // HEADER
            HStack {
                Text("Home")
                    .font(Theme.Font.title)
                    .foregroundColor(.brand.textPrimary)

                Spacer()

                Button {
                    showLogWorkout = true
                } label: {
                    Text("Log Workout")
                        .font(Theme.Font.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, Theme.Space.md)
                        .padding(.vertical, Theme.Space.sm)
                        .background(Color.brand.primary)
                        .cornerRadius(Theme.Radius.sm)
                }
            }
            .padding(.horizontal, Theme.Space.md)
            .padding(.vertical, Theme.Space.sm)
            .background(Color.brand.background)

            Divider()
                .foregroundColor(Color.brand.border)

            // CONTENT
            ZStack {
                Color.brand.background.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                } else if let block = activeBlock {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Theme.Space.lg) {

                            header(block)

                            ForEach(block.workouts) { template in
                                workoutSummary(template, blockID: block.id)
                            }
                        }
                        .padding(Theme.Space.md)
                    }
                } else {
                    emptyState
                }
            }
        }
        .task {
            await load()
        }
    }

    // MARK: - Content

    private func content(_ block: Block) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.lg) {

                header(block)

                ForEach(block.workouts) { template in
                    workoutSummary(template, blockID: block.id)
                }
            }
            .padding(Theme.Space.md)
        }
    }

    private func header(_ block: Block) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(block.name)
                .font(.system(size: Theme.TypeSize.xl, weight: .semibold))
                .foregroundColor(.brand.textPrimary)

            Text("Week \(currentWeek(block)) of \(block.durationWeeks)")
                .font(Theme.Font.body)
                .foregroundColor(.brand.textSecondary)
        }
    }

    // MARK: - Workout Summary

    private func workoutSummary(
        _ template: WorkoutTemplate,
        blockID: String
    ) -> some View {

        let related = workouts
            .filter { $0.blockID == blockID && $0.workoutTemplateID == template.id }
            .sorted { $0.date < $1.date }

        return VStack(alignment: .leading, spacing: Theme.Space.sm) {

            Text("Workout \(template.name)")
                .font(Theme.Font.body)
                .fontWeight(.medium)
                .foregroundColor(.brand.textPrimary)

            ForEach(template.exercises) { exercise in
                exerciseRow(
                    exercise,
                    workouts: related
                )
            }
        }
        .padding(Theme.Space.md)
        .background(Color.brand.surface)
        .cornerRadius(Theme.Radius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .stroke(Color.brand.border, lineWidth: 1)
        )
    }

    private func exerciseRow(
        _ exercise: Exercise,
        workouts: [Workout]
    ) -> some View {

        let results = workouts
            .compactMap { workout in
                workout.results.first { $0.exerciseID == exercise.id }
            }

        let first = results.first?.valuesSummary
        let last = results.last?.valuesSummary

        return HStack {
            Text(exercise.name)
                .font(Theme.Font.meta)
                .foregroundColor(.brand.textPrimary)

            Spacer()

            if let first, let last {
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

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: Theme.Space.lg) {
            Text("No active block")
                .font(Theme.Font.title)
                .foregroundColor(.brand.textPrimary)

            Text("Create a block to start tracking your training.")
                .font(Theme.Font.body)
                .foregroundColor(.brand.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                showingCreateBlock = true
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
            .sheet(isPresented: $showingCreateBlock) {
                SaveBlockView()
            }
        }
        .padding(Theme.Space.xl)
    }

    // MARK: - Data

    private func load() async {
        do {
            blocks = try await FirestoreService.shared.fetchBlocks()
            workouts = try await FirestoreService.shared.fetchWorkouts()
            isLoading = false
        } catch {
            print(error)
            isLoading = false
        }
    }

    private func currentWeek(_ block: Block) -> Int {
        let weeks = Calendar.current.dateComponents(
            [.weekOfYear],
            from: block.startDate,
            to: Date()
        ).weekOfYear ?? 0

        return min(block.durationWeeks, max(1, weeks + 1))
    }
}

// MARK: - Helpers

private extension ExerciseResult {
    var valuesSummary: String {
        values
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map { "\($0.value)" }
            .joined(separator: " · ")
    }
}
