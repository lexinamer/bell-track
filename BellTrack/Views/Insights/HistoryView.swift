import SwiftUI
import Foundation
import FirebaseAuth

struct HistoryView: View {
    let insight: BlockInsight

    @EnvironmentObject var authService: AuthService
    private let firestoreService = FirestoreService()

    @State private var isRenaming: Bool = false
    @State private var newName: String = ""
    @State private var movementName: String

    init(insight: BlockInsight) {
        self.insight = insight
        _movementName = State(initialValue: insight.name)
    }

    // newest first
    private var sortedBlocks: [WorkoutBlock] {
        insight.blocks.sorted { $0.date > $1.date }
    }

    // Best = highest volumeCount in this set's history
    private var bestVolume: Double? {
        insight.blocks.compactMap { $0.volumeCount }.max()
    }

    var body: some View {
        List {
            ForEach(sortedBlocks, id: \.id) { block in
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        Text(block.date.formatted(date: .abbreviated, time: .omitted))
                            .font(TextStyles.bodyStrong)
                            .foregroundColor(Color.brand.textPrimary)

                        Spacer()

                        if let volume = block.volumeCount,
                           isBest(volume: volume) {
                            Text("Best")
                                .font(TextStyles.subtextStrong)
                                .padding(.horizontal, Spacing.xs)
                                .padding(.vertical, 2)
                                .background(Color.brand.primary.opacity(0.08))
                                .foregroundColor(Color.brand.primary)
                                .cornerRadius(CornerRadius.sm)
                        }
                    }

                    // Combined metric line: load + volume
                    if let metric = metricLine(for: block) {
                        Text(metric)
                            .font(TextStyles.body)
                            .foregroundColor(Color.brand.textPrimary)
                            .padding(.bottom, 0)
                    }

                    let trimmedDetails = block.details
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    if !trimmedDetails.isEmpty {
                        Text(trimmedDetails)
                            .font(TextStyles.subtext)
                            .foregroundColor(Color.brand.secondary)
                            .padding(.top, CardStyle.bottomSpacer)
                    }
                }
                .padding(.vertical, CardStyle.cardTopBottomPadding)
                .listRowSeparator(.visible)
                .listRowInsets(.init(
                    top: 0,
                    leading: Spacing.lg,
                    bottom: 0,
                    trailing: Spacing.lg
                ))
                .listRowBackground(Color.brand.surface)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.brand.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(movementName)
                    .font(TextStyles.title)
                    .foregroundColor(Color.brand.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newName = movementName
                    isRenaming = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(Color.brand.textPrimary)
                }
                .buttonStyle(.plain)
            }
        }
        .alert("Rename Set", isPresented: $isRenaming) {
            TextField("New name", text: $newName)

            Button("Save") {
                let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, trimmed != movementName else { return }

                Task {
                    await renameMovement(to: trimmed)
                }
            }

            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Rename this set for all past sessions.")
        }
    }

    // MARK: - Helpers

    private func isBest(volume: Double) -> Bool {
        guard let bestVolume else { return false }
        return volume == bestVolume
    }

    /// Build a single line like:
    /// "2 × 16kg · 30 reps" or "16kg · 20 rounds"
    private func metricLine(for block: WorkoutBlock) -> String? {
        var parts: [String] = []

        // Load (kg + implements)
        if let load = block.loadKg {
            let loadInt = Int(load.rounded())
            if let mode = block.loadMode {
                let modeLabel: String
                switch mode {
                case .single:
                    modeLabel = "Single"
                case .double:
                    modeLabel = "Doubles"
                }
                parts.append("\(loadInt)kg \(modeLabel)")
            } else {
                parts.append("\(loadInt)kg")
            }
        }

        // Volume (reps / rounds)
        if let count = block.volumeCount,
           let vType = block.volumeKind {
            let label = (vType == .reps) ? "reps" : "rounds"
            let countInt = Int(count.rounded())
            parts.append("\(countInt) \(label)")
        }

        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func renameMovement(to newName: String) async {
        guard let uid = authService.user?.uid else { return }

        do {
            let allBlocks = try await firestoreService.fetchBlocks(userId: uid)
            let matchingBlocks = allBlocks.filter { $0.name == movementName }

            for var block in matchingBlocks {
                block.name = newName
                try await firestoreService.saveBlock(block)
            }

            await MainActor.run {
                movementName = newName
            }
        } catch {
            print("❌ Error renaming set: \(error.localizedDescription)")
        }
    }
}
