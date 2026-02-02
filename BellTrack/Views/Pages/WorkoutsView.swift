import SwiftUI
import FirebaseAuth

struct WorkoutsView: View {
    @EnvironmentObject var authService: AuthService
    @State private var firestoreService = FirestoreService()
    @State private var workouts: [Workout] = []
    @State private var isLoading = true
    @State private var showingLogSheet = false
    @State private var showingSettings = false
    @State private var editingWorkout: Workout?
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastType: ToastType = .error
    
    // Group workouts by month
    var groupedWorkouts: [(String, [Workout])] {
        let grouped = Dictionary(grouping: workouts) { workout -> String in
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: workout.date).uppercased()
        }
        return grouped.sorted { first, second in
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            guard let date1 = formatter.date(from: first.0),
                  let date2 = formatter.date(from: second.0) else {
                return first.0 > second.0
            }
            return date1 > date2
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if workouts.isEmpty {
                    Text("No workouts yet")
                        .font(Theme.Font.body)
                        .foregroundColor(Color.brand.textSecondary)
                } else {
                    List {
                        ForEach(groupedWorkouts, id: \.0) { month, monthWorkouts in
                            Section {
                                ForEach(monthWorkouts) { workout in
                                    WorkoutRowCard(workout: workout)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(role: .destructive) {
                                                Task { await deleteWorkout(workout) }
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                            
                                            Button {
                                                Task { await duplicateWorkout(workout) }
                                            } label: {
                                                Label("Duplicate", systemImage: "doc.on.doc")
                                            }
                                            .tint(Color.brand.primary)
                                            
                                            Button {
                                                editingWorkout = workout
                                                showingLogSheet = true
                                            } label: {
                                                Label("Edit", systemImage: "pencil")
                                            }
                                            .tint(.orange)
                                        }
                                }
                                .listRowBackground(Color.brand.background)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                            } header: {
                                Text(month)
                                    .font(Theme.Font.meta)
                                    .fontWeight(.semibold)
                                    .foregroundColor(Color.brand.textSecondary)
                                    .padding(.top, Theme.Space.md)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 20))
                            .foregroundColor(Color.brand.textPrimary)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Workouts")
                        .font(Theme.Font.title)
                        .foregroundColor(Color.brand.textPrimary)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingLogSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color.brand.primary)
                    }
                }
            }
            .toolbarBackground(Color.brand.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .background(Color.brand.background)
            .task {
                await loadWorkouts()
            }
            .refreshable {
                await loadWorkouts()
            }
            .fullScreenCover(isPresented: $showingLogSheet, onDismiss: {
                editingWorkout = nil
                Task { await loadWorkouts() }
            }) {
                LogView(editingWorkout: editingWorkout)
                    .environmentObject(authService)
            }
            .fullScreenCover(isPresented: $showingSettings) {
                SettingsView()
            }
            .toast(isShowing: $showToast, message: toastMessage, type: toastType)
        }
    }
    
    private func loadWorkouts() async {
        guard let userId = authService.user?.uid else { return }
        isLoading = true
        do {
            workouts = try await firestoreService.fetchWorkouts(userId: userId)
        } catch {
            print("Error loading workouts: \(error)")
        }
        isLoading = false
    }
    
    private func deleteWorkout(_ workout: Workout) async {
        do {
            try await firestoreService.deleteWorkout(workout)
            await loadWorkouts()
        } catch {
            toastMessage = "Failed to delete workout"
            toastType = .error
            showToast = true
        }
    }

    private func duplicateWorkout(_ workout: Workout) async {
        guard let userId = authService.user?.uid else { return }
        do {
            try await firestoreService.duplicateWorkout(workout, userId: userId)
            await loadWorkouts()
            toastMessage = "Workout duplicated"
            toastType = .success
            showToast = true
        } catch {
            toastMessage = "Failed to duplicate workout"
            toastType = .error
            showToast = true
        }
    }
}

struct WorkoutRowCard: View {
    let workout: Workout
    @State private var isExpanded = false
    
    var body: some View {
        Button {
            isExpanded.toggle()
        } label: {
            HStack(alignment: .top, spacing: Theme.Space.md) {
                // Date block
                VStack(spacing: 2) {
                    Text(monthAbbreviation)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                    Text(dayNumber)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: 56, height: 56)
                .background(Color.brand.primary)
                .cornerRadius(Theme.Radius.md)
                
                // Workout details
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    // Summary - always show
                    Text("\(workout.exercises.count) exercise\(workout.exercises.count == 1 ? "" : "s")")
                        .font(Theme.Font.body)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.brand.textPrimary)
                    
                    if !isExpanded, let firstExercise = workout.exercises.first {
                        Text(firstExercise.displayString)
                            .font(Theme.Font.meta)
                            .foregroundColor(Color.brand.textSecondary)
                            .lineLimit(1)
                    }
                    
                    // Full list when expanded
                    if isExpanded {
                        ForEach(workout.exercises) { exercise in
                            Text(exercise.displayString)
                                .font(Theme.Font.meta)
                                .foregroundColor(Color.brand.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14))
                    .foregroundColor(Color.brand.textSecondary)
            }
            .padding(Theme.Space.md)
            .background(Color.brand.surface)
            .cornerRadius(Theme.Radius.md)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(Color.brand.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
    
    private var monthAbbreviation: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: workout.date).uppercased()
    }
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: workout.date)
    }
}
