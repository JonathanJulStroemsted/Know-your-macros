import Foundation

struct Exercise: Codable, Identifiable, Hashable {
    let id: Int
    let uuid: String
    let name: String
    let description: String?
    let category: Category
    let muscles: [Int]
    let musclesSecondary: [Int]
    let equipment: [Int]
    let language: Int
    let variations: Int?
    let met: Double
    
    enum CodingKeys: String, CodingKey {
        case id, uuid, name, description, category, muscles, equipment, language, variations, met
        case musclesSecondary = "muscles_secondary"
    }
    
    struct Category: Codable, Hashable {
        let id: Int
        let name: String
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Exercise, rhs: Exercise) -> Bool {
        return lhs.id == rhs.id
    }
}

// Model for user-selected exercises with additional metadata
struct UserExercise: Identifiable, Codable {
    let id = UUID()
    let exercise: Exercise
    var sets: Int
    var reps: Int
    var weight: Double
    var notes: String?
    var date: Date
    var workoutSets: [WorkoutSet]?
    
    init(exercise: Exercise, sets: Int = 3, reps: Int = 10, weight: Double = 0, notes: String? = nil, date: Date = Date(), workoutSets: [WorkoutSet]? = nil) {
        self.exercise = exercise
        self.sets = sets
        self.reps = reps
        self.weight = weight
        self.notes = notes
        self.date = date
        self.workoutSets = workoutSets
    }
}

// Enum for set tempo
enum SetTempo: String, CaseIterable, Codable {
    case slow = "Slow"
    case normal = "Normal"
    case fast = "Fast"
    case stopAndGo = "Stop and Go"
}

// Model for workout set
struct WorkoutSet: Identifiable, Codable {
    var id = UUID()
    var weight: Double = 0
    var reps: Int = 8
    var tempo: SetTempo = .normal
    var restTimeSeconds: Int = 60
    
    // Create a copy of the workout set
    func copy() -> WorkoutSet {
        var newSet = WorkoutSet()
        newSet.weight = self.weight
        newSet.reps = self.reps
        newSet.tempo = self.tempo
        newSet.restTimeSeconds = self.restTimeSeconds
        return newSet
    }
} 