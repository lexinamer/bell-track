import Foundation

struct Exercise: Identifiable, Codable {
    var id = UUID()
    var exerciseName: String
    var rounds: Int?
    var reps: Int?
    var time: String?
    var weightKg: Double?
    var isDoubleWeight: Bool = false
    var note: String?
    
    var displayString: String {
        var parts: [String] = [exerciseName]
        
        // Rounds, reps, time logic
        var workPart = ""
        if let rounds = rounds {
            workPart += "\(rounds)x"
            if let reps = reps {
                workPart += "\(reps)"
            }
        } else if let reps = reps {
            workPart += "\(reps)"
        }
        
        if let time = time, !time.isEmpty {
            if !workPart.isEmpty {
                workPart += " \(time)"
            } else {
                workPart = time
            }
        }
        
        if !workPart.isEmpty {
            parts.append(workPart)
        }
        
        // Weight
        if let weight = weightKg {
            let weightStr = isDoubleWeight ? "2x\(Int(weight))kg" : "\(Int(weight))kg"
            parts.append(weightStr)
        }
        
        // Note
        if let note = note, !note.isEmpty {
            parts.append(note)
        }
        
        return parts.joined(separator: " • ")
    }
}
