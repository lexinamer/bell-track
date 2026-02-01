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
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if workouts.isEmpty {
                    Text("No workouts yet")
                        .font(Theme.Font.body)
                } else {
                    List {
                        ForEach(workouts) { workout in
                            WorkoutCard(workout: workout)
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
                        .listRowBackground(Color.brand.surface)
                        .listRowSeparator(.hidden)
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
            }) {
                LogView(editingWorkout: editingWorkout)
                    .environmentObject(authService)
            }
            .fullScreenCover(isPresented: $showingSettings) {
                SettingsView()
            }
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
            print("Error deleting workout: \(error)")
        }
    }
    
    private func duplicateWorkout(_ workout: Workout) async {
        guard let userId = authService.user?.uid else { return }
        do {
            try await firestoreService.duplicateWorkout(workout, userId: userId)
            await loadWorkouts()
        } catch {
            print("Error duplicating workout: \(error)")
        }
    }
}
