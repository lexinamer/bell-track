import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    @State private var showingBlockCreation = false
    @State private var showingEndBlockAlert = false
    @State private var showingRenameSheet = false
    @State private var newBlockName = ""
    @State private var isRefreshing = false

    var body: some View {
        ZStack {
            Color.brand.background.ignoresSafeArea()

            if appViewModel.isLoading {
                ProgressView("Loading...")
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
        .alert("Error", isPresented: .constant(appViewModel.error != nil)) {
            Button("OK") {
                appViewModel.clearError()
            }
            Button("Retry") {
                Task {
                    await appViewModel.loadData()
                }
            }
        } message: {
            Text(appViewModel.error?.errorDescription ?? "Unknown error")
        }
        .snackbar(
            message: appViewModel.successMessage ?? "",
            isShowing: .constant(appViewModel.successMessage != nil),
            onDismiss: {
                appViewModel.clearSuccessMessage()
            }
        )
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
            isRefreshing = true
            await appViewModel.loadData()
            isRefreshing = false
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
            HStack {
                Text("Progress")
                    .font(Theme.Font.title)
                    .foregroundColor(.brand.textPrimary)
                
                Spacer()
                
                if isRefreshing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button("Refresh") {
                        Task {
                            await appViewModel.refreshProgress()
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.brand.primary)
                }
            }

            if block.workouts.isEmpty {
                Text("No workouts in this block")
                    .font(Theme.Font.body)
                    .foregroundColor(.brand.textSecondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.brand.surface)
                    .cornerRadius(Theme.Radius.sm)
            } else {
                ForEach(block.workouts) { workout in
                    workoutProgressCard(workout)
                }
            }
        }
    }

    private func workoutProgressCard(_ workout: Workout) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("Workout \(workout.name)")
                .font(Theme.Font.body)
                .fontWeight(.medium)
                .foregroundColor(.brand.textPrimary)

            if workout.exercises.isEmpty {
                Text("No exercises added")
                    .font(Theme.Font.meta)
                    .foregroundColor(.brand.textSecondary)
                    .italic()
            } else {
                ForEach(workout.exercises) { exercise in
                    exerciseProgressRow(exercise)
                }
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
        let progress = appViewModel.getProgress(for: exercise.id)

        return HStack {
            Text(exercise.name)
                .font(Theme.Font.meta)
                .foregroundColor(.brand.textPrimary)

            Spacer()

            Group {
                if let first = progress.first, let last = progress.last {
                    if first == last {
                        Text(first)
                            .font(Theme.Font.meta)
                            .foregroundColor(.brand.textSecondary)
                    } else {
                        Text("\(first) → \(last)")
                            .font(Theme.Font.meta)
                            .foregroundColor(.brand.textSecondary)
                    }
                } else {
                    Text("—")
                        .font(Theme.Font.meta)
                        .foregroundColor(.brand.textSecondary)
                }
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
            .disabled(appViewModel.isSaving)

            Button {
                showingEndBlockAlert = true
            } label: {
                HStack {
                    if appViewModel.isSaving {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "checkmark.circle")
                    }
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
            .disabled(appViewModel.isSaving)
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
                HStack {
                    if appViewModel.isSaving {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "plus")
                    }
                    Text("Create Block")
                }
                .font(Theme.Font.body)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, Theme.Space.lg)
                .padding(.vertical, Theme.Space.md)
                .background(Color.brand.primary)
                .cornerRadius(Theme.Radius.sm)
            }
            .disabled(appViewModel.isSaving)
        }
        .navigationTitle("Log Workout")
        .navigationBarTitleDisplayMode(.large)
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
                    .disabled(appViewModel.isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await renameBlock()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(newBlockName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || appViewModel.isSaving)
                }
            }
        }
    }

    private func renameBlock() async {
        guard var block = appViewModel.activeBlock else { return }
        let trimmedName = newBlockName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else { return }
        
        block.name = trimmedName
        await appViewModel.saveBlock(block)
        showingRenameSheet = false
    }
}

// MARK: - Snackbar View Extension

extension View {
    func snackbar(
        message: String,
        isShowing: Binding<Bool>,
        onDismiss: @escaping () -> Void
    ) -> some View {
        ZStack {
            self
            
            if isShowing.wrappedValue && !message.isEmpty {
                VStack {
                    Spacer()
                    
                    HStack {
                        Text(message)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                        
                        Button("Dismiss") {
                            onDismiss()
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    }
                    .padding()
                    .background(Color.green)
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.bottom, 80) // Above tab bar
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            onDismiss()
                        }
                    }
                }
            }
        }
    }
}
