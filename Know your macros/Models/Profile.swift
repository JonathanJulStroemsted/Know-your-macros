import Foundation
import SwiftUI

struct Profile: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var weight: Double
    var height: Double
    var age: Int
    var isMale: Bool
    var activityLevelIndex: Int
    var goalIndex: Int
    
    static func == (lhs: Profile, rhs: Profile) -> Bool {
        lhs.id == rhs.id
    }
}

class ProfileManager: ObservableObject {
    @Published var profiles: [Profile] = []
    
    private let saveKey = "savedProfiles"
    
    init() {
        loadProfiles()
    }
    
    func addProfile(_ profile: Profile) {
        profiles.append(profile)
        saveProfiles()
    }
    
    func updateProfile(_ profile: Profile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
            saveProfiles()
        }
    }
    
    func getProfile(withId id: UUID) -> Profile? {
        return profiles.first(where: { $0.id == id })
    }
    
    func deleteProfile(at indexSet: IndexSet) {
        profiles.remove(atOffsets: indexSet)
        saveProfiles()
    }
    
    func saveProfiles() {
        if let encoded = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
            // Force a UI update
            objectWillChange.send()
        }
    }
    
    func loadProfiles() {
        if let data = UserDefaults.standard.data(forKey: saveKey) {
            if let decoded = try? JSONDecoder().decode([Profile].self, from: data) {
                profiles = decoded
                return
            }
        }
        
        profiles = []
    }
} 