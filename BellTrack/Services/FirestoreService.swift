import Foundation
import FirebaseFirestore

final class FirestoreService {
    private let db = Firestore.firestore()
    
    // MARK: - Workouts
    func fetchWorkouts(userId: String) async throws -> [Workout] {
        let snapshot = try await db.collection("users/\(userId)/workouts")
            .order(by: "date", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { try? $0.data(as: Workout.self) }
    }

    func saveWorkout(_ workout: Workout) async throws {
        let userId = workout.userId
        let workoutsRef = db.collection("users/\(userId)/workouts")
        
        if let id = workout.id {
            // Update existing
            try workoutsRef.document(id).setData(from: workout)
        } else {
            // Create new
            _ = try workoutsRef.addDocument(from: workout)
        }
    }

    func deleteWorkout(_ workout: Workout) async throws {
        guard let id = workout.id else { return }
        let userId = workout.userId
        try await db.collection("users/\(userId)/workouts").document(id).delete()
    }

    func duplicateWorkout(_ workout: Workout, userId: String) async throws {
        var newWorkout = workout
        newWorkout.id = nil
        newWorkout.date = Date()
        newWorkout.userId = userId
        try await saveWorkout(newWorkout)
    }
    
    // MARK: - Settings
    func fetchSettings(userId: String) async throws -> Settings {
        let docRef = db.collection("users/\(userId)/settings").document("main")
        
        if let settings = try? await docRef.getDocument(as: Settings.self) {
            return settings
        } else {
            let newSettings = Settings(id: "main", userId: userId, exercises: Settings.defaultExercises)
            try docRef.setData(from: newSettings)
            return newSettings
        }
    }
    
    func saveSettings(_ settings: Settings) async throws {
        try db.collection("users/\(settings.userId)/settings").document("main").setData(from: settings)
    }
}
