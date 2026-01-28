import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    @State private var selectedBlock: Block?
    @State private var blockLogs: [WorkoutLog] = []
    @State private var isLoadingLogs = false

    var body: some View {
        ZStack {
            Color.brand.background.ignoresSafeArea()

            if let block = selectedBlock {
                blockDetailView(block)
            } else {
                blockListView
            }
        }
    }

    private var blockListView: some View {
        VStack(alignment: .leading, spacing: Theme.Space.lg) {
            Text("Workouts")
                .font(.system(size: Theme.TypeSize.xl, weight: .semibold))
                .foregroundColor(.brand.textPrimary)
                .padding(.horizontal, Theme.Space.md)
                .padding(.top, Theme.Space.md)

            if appViewModel.completedBlocks.isEmpty {
                emptyHistoryView
            } else {
                blockList
            }
        }
    }

    private var emptyHistoryView: some View {
        VStack(spacing: Theme.Space.md) {
            Spacer()

            Text("No completed blocks")
                .font(Theme.Font.title)
                .foregroundColor(.brand.textPrimary)

            Text("Completed training blocks will appear here.")
                .font(Theme.Font.body)
                .foregroundColor(.brand.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(Theme.Space.xl)
    }

    private var blockList: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Space.sm) {
                ForEach(appViewModel.completedBlocks) { block in
                    blockRow(block)
                }
            }
            .padding(.horizontal, Theme.Space.md)
        }
    }

    private func blockRow(_ block: Block) -> some View {
        Button {
            selectBlock(block)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Text(block.name)
                        .font(Theme.Font.body)
                        .fontWeight(.medium)
                        .foregroundColor(.brand.textPrimary)

                    Text(block.dateRangeText)
                        .font(Theme.Font.meta)
                        .foregroundColor(.brand.textSecondary)

                    Text("\(block.workouts.count) workouts")
                        .font(Theme.Font.meta)
                        .foregroundColor(.brand.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.brand.textSecondary)
            }
            .padding(Theme.Space.md)
            .background(Color.brand.surface)
            .cornerRadius(Theme.Radius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(Color.brand.border, lineWidth: 1)
            )
        }
    }

    private func blockDetailView(_ block: Block) -> some View {
        VStack(spacing: 0) {
            detailHeader(block)

            if isLoadingLogs {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Space.lg) {
                        blockSummary(block)
                        logsSection
                    }
                    .padding(Theme.Space.md)
                }
            }
        }
    }

    private func detailHeader(_ block: Block) -> some View {
        HStack {
            Button {
                selectedBlock = nil
                blockLogs = []
            } label: {
                HStack(spacing: Theme.Space.xs) {
                    Image(systemName: "chevron.left")
                    Text("History")
                }
                .font(Theme.Font.body)
                .foregroundColor(.brand.primary)
            }

            Spacer()
        }
        .padding(Theme.Space.md)
        .background(Color.brand.background)
    }

    private func blockSummary(_ block: Block) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text(block.name)
                .font(.system(size: Theme.TypeSize.xl, weight: .semibold))
                .foregroundColor(.brand.textPrimary)

            Text(block.dateRangeText)
                .font(Theme.Font.body)
                .foregroundColor(.brand.textSecondary)

            Text("\(blockLogs.count) logged workouts")
                .font(Theme.Font.meta)
                .foregroundColor(.brand.textSecondary)
        }
    }

    private var logsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            Text("Workout Logs")
                .font(Theme.Font.title)
                .foregroundColor(.brand.textPrimary)

            if blockLogs.isEmpty {
                Text("No workouts logged for this block.")
                    .font(Theme.Font.body)
                    .foregroundColor(.brand.textSecondary)
            } else {
                ForEach(blockLogs) { log in
                    logCard(log)
                }
            }
        }
    }

    private func logCard(_ log: WorkoutLog) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            HStack {
                Text("Workout \(log.workoutName)")
                    .font(Theme.Font.body)
                    .fontWeight(.medium)
                    .foregroundColor(.brand.textPrimary)

                Spacer()

                Text(log.shortDate)
                    .font(Theme.Font.meta)
                    .foregroundColor(.brand.textSecondary)
            }

            ForEach(log.exerciseResults.filter { $0.hasValue }) { result in
                HStack {
                    Text(result.exerciseName)
                        .font(Theme.Font.meta)
                        .foregroundColor(.brand.textSecondary)

                    Spacer()

                    Text(result.value)
                        .font(Theme.Font.meta)
                        .foregroundColor(.brand.textPrimary)
                }
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

    private func selectBlock(_ block: Block) {
        selectedBlock = block
        isLoadingLogs = true

        Task {
            if let blockId = block.id {
                await appViewModel.loadLogsForBlock(blockId)
                blockLogs = appViewModel.logs
            }
            isLoadingLogs = false
        }
    }
}
