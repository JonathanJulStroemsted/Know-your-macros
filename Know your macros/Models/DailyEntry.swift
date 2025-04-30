import Foundation

struct DailyEntry: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var caloriesConsumed: Int
    var stepsTaken: Int
    var caloriesBurnedGym: Int
    var profileId: UUID
    
    init(profileId: UUID, date: Date = Date(), caloriesConsumed: Int = 0, stepsTaken: Int = 0, caloriesBurnedGym: Int = 0) {
        self.profileId = profileId
        self.date = date
        self.caloriesConsumed = caloriesConsumed
        self.stepsTaken = stepsTaken
        self.caloriesBurnedGym = caloriesBurnedGym
    }
    
    var caloriesFromSteps: Int {
        // Rough estimate: 1 step burns ~0.04 calories
        return Int(Double(stepsTaken) * 0.04)
    }
    
    var totalCaloriesBurned: Int {
        return caloriesFromSteps + caloriesBurnedGym
    }
}

class DailyTracker: ObservableObject {
    @Published var entries: [DailyEntry] = []
    
    private let saveKey = "dailyEntries"
    private let calendar = Calendar.current
    
    init() {
        loadEntries()
    }
    
    func addEntry(_ entry: DailyEntry) {
        // Check if we already have an entry for this profile and date
        if let index = entries.firstIndex(where: { 
            calendar.isDate($0.date, inSameDayAs: entry.date) && 
            $0.profileId == entry.profileId 
        }) {
            entries[index] = entry
        } else {
            entries.append(entry)
        }
        saveEntries()
    }
    
    func getEntryFor(profileId: UUID, date: Date = Date()) -> DailyEntry {
        if let entry = entries.first(where: { 
            calendar.isDate($0.date, inSameDayAs: date) && 
            $0.profileId == profileId 
        }) {
            return entry
        }
        
        // Create a new entry if none exists
        return DailyEntry(profileId: profileId, date: date)
    }
    
    func hasEntryFor(profileId: UUID, date: Date) -> Bool {
        return entries.contains {
            calendar.isDate($0.date, inSameDayAs: date) && 
            $0.profileId == profileId
        }
    }
    
    func getEntriesForMonth(profileId: UUID, date: Date) -> [DailyEntry] {
        let components = calendar.dateComponents([.year, .month], from: date)
        
        return entries.filter { entry in
            let entryComponents = calendar.dateComponents([.year, .month], from: entry.date)
            return entry.profileId == profileId && 
                  entryComponents.year == components.year && 
                  entryComponents.month == components.month
        }
    }
    
    func getEntriesForProfile(profileId: UUID) -> [DailyEntry] {
        return entries.filter { $0.profileId == profileId }
            .sorted(by: { $0.date > $1.date }) // Sort by date, newest first
    }
    
    func saveEntries() {
        if let encoded = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
            objectWillChange.send()
        }
    }
    
    func loadEntries() {
        if let data = UserDefaults.standard.data(forKey: saveKey) {
            if let decoded = try? JSONDecoder().decode([DailyEntry].self, from: data) {
                entries = decoded
                return
            }
        }
        
        entries = []
    }
} 