import SwiftUI

struct DailyTrackingView: View {
    @ObservedObject var profileManager: ProfileManager
    @ObservedObject var dailyTracker: DailyTracker
    
    let profile: Profile
    let date: Date
    
    @State private var entry: DailyEntry
    @State private var caloriesConsumedString: String = "0"
    @State private var stepsTakenString: String = "0"
    @State private var caloriesBurnedGymString: String = "0"
    
    init(profile: Profile, profileManager: ProfileManager, dailyTracker: DailyTracker, date: Date = Date()) {
        self.profile = profile
        self.profileManager = profileManager
        self.dailyTracker = dailyTracker
        self.date = date
        
        let initialEntry = dailyTracker.getEntryFor(profileId: profile.id, date: date)
        self._entry = State(initialValue: initialEntry)
        self._caloriesConsumedString = State(initialValue: "\(initialEntry.caloriesConsumed)")
        self._stepsTakenString = State(initialValue: "\(initialEntry.stepsTaken)")
        self._caloriesBurnedGymString = State(initialValue: "\(initialEntry.caloriesBurnedGym)")
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
    
    var dailyCalories: Int {
        Int(CalorieCalculator.dailyCalories(tdee: tdee, goal: goal))
    }
    
    var caloriesRemaining: Int {
        dailyCalories - entry.caloriesConsumed + entry.totalCaloriesBurned
    }
    
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter
    }
    
    var body: some View {
        Form {
            if !isToday {
                Section {
                    HStack {
                        Spacer()
                        Text("Data for \(dateFormatter.string(from: date))")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            
            Section(header: Text("Daily Goal")) {
                HStack {
                    Text("Calories to Hit Goal:")
                    Spacer()
                    Text("\(dailyCalories)")
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
            }
            
            Section(header: Text("Food & Activity")) {
                HStack {
                    Text("Calories Consumed:")
                    Spacer()
                    TextField("0", text: $caloriesConsumedString)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                        .onChange(of: caloriesConsumedString) { _, newValue in
                            if let value = Int(newValue) {
                                entry.caloriesConsumed = value
                                saveEntry()
                            }
                        }
                }
                
                HStack {
                    Text("Steps Taken:")
                    Spacer()
                    TextField("0", text: $stepsTakenString)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                        .onChange(of: stepsTakenString) { _, newValue in
                            if let value = Int(newValue) {
                                entry.stepsTaken = value
                                saveEntry()
                            }
                        }
                }
                
                HStack {
                    Text("Calories Burned (Gym/Cardio):")
                    Spacer()
                    TextField("0", text: $caloriesBurnedGymString)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                        .onChange(of: caloriesBurnedGymString) { _, newValue in
                            if let value = Int(newValue) {
                                entry.caloriesBurnedGym = value
                                saveEntry()
                            }
                        }
                }
            }
            
            Section(header: Text("Calories from Activity")) {
                HStack {
                    Text("From Steps:")
                    Spacer()
                    Text("\(entry.caloriesFromSteps)")
                        .foregroundColor(.green)
                }
                
                HStack {
                    Text("From Gym/Cardio:")
                    Spacer()
                    Text("\(entry.caloriesBurnedGym)")
                        .foregroundColor(.green)
                }
                
                HStack {
                    Text("Total Calories Burned:")
                    Spacer()
                    Text("\(entry.totalCaloriesBurned)")
                        .foregroundColor(.green)
                        .fontWeight(.bold)
                }
            }
            
            Section(header: Text("Summary")) {
                HStack {
                    Text("Calories Remaining:")
                    Spacer()
                    Text("\(caloriesRemaining)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(caloriesRemaining >= 0 ? .blue : .red)
                }
                
                VStack(alignment: .leading, spacing: 5) {
                    Text("Formula:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Goal (\(dailyCalories)) - Consumed (\(entry.caloriesConsumed)) + Burned (\(entry.totalCaloriesBurned))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle(isToday ? "Today's Tracking" : "Edit Past Entry")
        .onAppear {
            // Make sure we have the most up-to-date data
            let freshEntry = dailyTracker.getEntryFor(profileId: profile.id, date: date)
            entry = freshEntry
            caloriesConsumedString = "\(freshEntry.caloriesConsumed)"
            stepsTakenString = "\(freshEntry.stepsTaken)"
            caloriesBurnedGymString = "\(freshEntry.caloriesBurnedGym)"
        }
    }
    
    private func saveEntry() {
        // Make sure we're saving with the correct date
        var updatedEntry = entry
        updatedEntry.date = date
        
        // Save the entry and update the UI
        dailyTracker.addEntry(updatedEntry)
    }
}

#Preview {
    DailyTrackingView(
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
