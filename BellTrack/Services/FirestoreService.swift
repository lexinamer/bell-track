import Foundation
import FirebaseFirestore

class FirestoreService {
    private let db = Firestore.firestore()
    
    // MARK: - Workout Blocks
    
    func fetchBlocks(userId: String) async throws -> [WorkoutBlock] {
        let snapshot = try await db.collection("blocks")
            .whereField("userId", isEqualTo: userId)
            .order(by: "date", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: WorkoutBlock.self)
        }
    }
    
    func saveBlock(_ block: WorkoutBlock) async throws {
        if let id = block.id {
            try db.collection("blocks").document(id).setData(from: block)
        } else {
            try db.collection("blocks").addDocument(from: block)
        }
    }
    
    func deleteBlock(id: String) async throws {
        try await db.collection("blocks").document(id).delete()
    }
    
    // MARK: - Notes
    func fetchDateNote(userId: String, date: Date) async throws -> DateNote? {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let snapshot = try await db.collection("date_notes")
            .whereField("userId", isEqualTo: userId)
            .whereField("date", isGreaterThanOrEqualTo: startOfDay)
            .whereField("date", isLessThan: endOfDay)
            .getDocuments()
        
        return snapshot.documents.first.flatMap { try? $0.data(as: DateNote.self) }  // Changed map to flatMap
    }

    func saveDateNote(_ note: DateNote) async throws {
        if let id = note.id {
            try db.collection("date_notes").document(id).setData(from: note)
        } else {
            try db.collection("date_notes").addDocument(from: note)
        }
    }

    func deleteDateNote(id: String) async throws {
        try await db.collection("date_notes").document(id).delete()
    }
    
    // MARK: - Settings
    
    func fetchSettings(userId: String) async throws -> UserSettings? {
        let snapshot = try await db.collection("settings")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        return snapshot.documents.first.flatMap { try? $0.data(as: UserSettings.self) }
    }
    
    func saveSettings(_ settings: UserSettings) async throws {
        if let id = settings.id {
            try db.collection("settings").document(id).setData(from: settings)
        } else {
            try db.collection("settings").addDocument(from: settings)
        }
    }
}
