import SwiftUI

struct CalorieCalculatorView: View {
    @ObservedObject var profileManager: ProfileManager
    @ObservedObject var dailyTracker: DailyTracker
    
    @State private var profile: Profile
    @State private var showingActivityLevelPicker = false
    @State private var showBMRInfo = false
    @State private var showTDEEInfo = false
    @State private var showingEditProfile = false
    
    init(profile: Profile, profileManager: ProfileManager, dailyTracker: DailyTracker) {
        self.profileManager = profileManager
        self.dailyTracker = dailyTracker
        self._profile = State(initialValue: profile)
    }
    
    var activityLevel: CalorieCalculator.ActivityLevel {
        CalorieCalculator.ActivityLevel.allCases[profile.activityLevelIndex]
    }
    
    var goal: CalorieCalculator.Goal {
        CalorieCalculator.Goal.allCases[profile.goalIndex]
    }
    
    var bmr: Double {
        CalorieCalculator.calculateBMR(
            weightKg: profile.weight,
            heightCm: profile.height,
            age: profile.age,
            isMale: profile.isMale
        )
    }
    
    var tdee: Double {
        CalorieCalculator.calculateTDEE(bmr: bmr, activityLevel: activityLevel)
    }
    
    var dailyCalories: Double {
        CalorieCalculator.dailyCalories(tdee: tdee, goal: goal)
    }
    
    var body: some View {
        Form {
            Section(header: Text("Goal")) {
                HStack {
                    Text("Current Goal:")
                    Spacer()
                    Text(goal.displayName)
                        .foregroundColor(.blue)
                }
            }
            
            Section {
                NavigationLink(destination: DailyTrackingView(profile: profile, profileManager: profileManager, dailyTracker: dailyTracker)) {
                    HStack {
                        Image(systemName: "fork.knife.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                        Text("Track Today's Calories")
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                
                NavigationLink(destination: CalendarView(profileManager: profileManager, dailyTracker: dailyTracker, profile: profile)) {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.title2)
                            .foregroundColor(.blue)
                        Text("View History & Past Entries")
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Section(header: Text("Results")) {
                HStack {
                    Text("BMR: \(Int(bmr)) calories/day")
                    Spacer()
                    Button {
                        showBMRInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                    }
                    .alert("BMR (Basal Metabolic Rate)", isPresented: $showBMRInfo) {
                        Button("Got it", role: .cancel) { }
                    } message: {
                        Text("BMR is the number of calories your body needs at rest — for breathing, heartbeat, and basic functions.")
                    }
                }
                
                HStack {
                    Text("TDEE: \(Int(tdee)) calories/day")
                    Spacer()
                    Button {
                        showTDEEInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                    }
                    .alert("TDEE (Total Daily Energy Expenditure)", isPresented: $showTDEEInfo) {
                        Button("Got it", role: .cancel) { }
                    } message: {
                        Text("TDEE is the total number of calories you burn per day, including all movement and activity.")
                    }
                }

                Text("Daily Calories for Goal: \(Int(dailyCalories)) calories/day")
                    .fontWeight(.bold)
            }
            
            Section(header: Text("Edit Profile")) {
                Button(action: {
                    showingEditProfile = true
                }) {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.title2)
                            .foregroundColor(.blue)
                        Text("Edit Profile Details")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section(header: Text("Profile Details")) {
                HStack {
                    Image(systemName: "person.circle")
                        .font(.title)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading) {
                        Text(profile.name)
                            .font(.headline)
                        
                        HStack {
                            Text("\(Int(profile.age)) years")
                            Text("•")
                            Text("\(Int(profile.weight)) kg")
                            Text("•")
                            Text("\(Int(profile.height)) cm")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Text("Activity Level:")
                    Spacer()
                    Text(activityLevel.displayName.components(separatedBy: " (")[0])
                        .foregroundColor(.secondary)
                }
                
                Text(profile.isMale ? "Gender: Male" : "Gender: Female")
            }
        }
        .navigationTitle("Calorie Calculator")
        .sheet(isPresented: $showingEditProfile) {
            ProfileEditorView(profileManager: profileManager, profile: profile)
                .onDisappear {
                    refreshProfileData()
                }
        }
        .onAppear {
            refreshProfileData()
        }
    }
    
    private func refreshProfileData() {
        // Make sure we're seeing the latest version of the profile
        if let updatedProfile = profileManager.profiles.first(where: { $0.id == profile.id }) {
            self.profile = updatedProfile
        }
    }
}

#Preview {
    CalorieCalculatorView(
        profile: Profile(
            name: "John Doe",
            weight: 75,
            height: 180,
            age: 30,
            isMale: true,
            activityLevelIndex: 2,
            goalIndex: 0
        ),
        profileManager: ProfileManager(),
        dailyTracker: DailyTracker()
    )
} 
