import SwiftUI

struct DailyTrackingView: View {
    @ObservedObject var profileManager: ProfileManager
    @ObservedObject var dailyTracker: DailyTracker
    @StateObject private var healthKitManager = HealthKitManager()
    
    let profile: Profile
    let date: Date
    
    @State private var entry: DailyEntry
    @State private var caloriesConsumedString: String = "0"
    @State private var stepsTakenString: String = "0"
    @State private var caloriesBurnedGymString: String = "0"
    @State private var showingHealthKitPrompt = false
    @State private var showingHealthKitNotAvailable = false
    @State private var showingPermissionsError = false
    @State private var showingErrorMessage = false
    @State private var showingHistoricalImportSuccess = false
    @State private var isLoadingSteps = false
    
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
                    
                    if isLoadingSteps {
                        ProgressView()
                            .frame(width: 20, height: 20)
                            .padding(.trailing, 8)
                    }
                    
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
                
                // Show Apple Health Buttons
                if healthKitManager.isHealthDataAvailable && !healthKitManager.permissionsError {
                    if healthKitManager.isImportingBulkData {
                        VStack {
                            ProgressView(value: healthKitManager.bulkImportProgress, total: 1.0) {
                                Text("Importing Historical Step Data...")
                                    .font(.caption)
                            }
                            Text("\(Int(healthKitManager.bulkImportProgress * 100))%")
                                .font(.caption2)
                        }
                        .padding(.vertical, 8)
                    } else {
                        Button(action: {
                            loadStepsFromHealthKit()
                        }) {
                            HStack {
                                Image(systemName: "heart.fill")
                                    .foregroundColor(.pink)
                                Text(healthKitManager.isAuthorized ? "Sync Today's Steps" : "Connect Apple Health")
                                Spacer()
                            }
                        }
                        .disabled(isLoadingSteps)
                        
                        Button(action: {
                            importHistoricalStepData()
                        }) {
                            HStack {
                                Image(systemName: "calendar.badge.clock")
                                    .foregroundColor(.blue)
                                Text("Import 2 Months of Step Data")
                                Spacer()
                            }
                        }
                        .disabled(isLoadingSteps || !healthKitManager.isAuthorized)
                    }
                }
                
                // Show this debug info only if we encountered an error
                if !healthKitManager.lastErrorMessage.isEmpty {
                    Button(action: {
                        showingErrorMessage = true
                    }) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text("Show Health Error Details")
                            Spacer()
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
            
            // Auto-sync steps for today if authorized and no permissions errors
            if isToday && healthKitManager.isAuthorized && !healthKitManager.permissionsError {
                loadStepsFromHealthKit()
            }
        }
        .alert("Connect to Apple Health", isPresented: $showingHealthKitPrompt) {
            Button("Cancel", role: .cancel) { }
            Button("Connect") {
                requestHealthKitAuthorization()
            }
        } message: {
            Text("Allow this app to access your step count data from Apple Health?")
        }
        .alert("Health Data Not Available", isPresented: $showingHealthKitNotAvailable) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("HealthKit is not available on this device. This is normal in the simulator - on a real device, make sure Health app is installed and accessible.")
        }
        .alert("Health Permissions Required", isPresented: $showingPermissionsError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This app needs permission descriptions in Info.plist to access HealthKit data. When testing in a simulator, you can manually enter steps instead.")
        }
        .alert("HealthKit Error Details", isPresented: $showingErrorMessage) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(healthKitManager.lastErrorMessage)
        }
        .alert("Historical Data Import Complete", isPresented: $showingHistoricalImportSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Successfully imported step data for the current and previous month.")
        }
        .onChange(of: healthKitManager.permissionsError) { _, newValue in
            if newValue {
                showingPermissionsError = true
            }
        }
    }
    
    private func saveEntry() {
        // Make sure we're saving with the correct date
        var updatedEntry = entry
        updatedEntry.date = date
        
        // Save the entry and update the UI
        dailyTracker.addEntry(updatedEntry)
    }
    
    private func loadStepsFromHealthKit() {
        print("DailyTrackingView: Attempting to load steps from HealthKit")
        // First check if HealthKit is available on this device
        if !healthKitManager.isAvailable {
            print("DailyTrackingView: HealthKit not available")
            showingHealthKitNotAvailable = true
            return
        }
        
        // Then check if we're authorized
        if !healthKitManager.isAuthorized {
            print("DailyTrackingView: Not authorized for HealthKit, showing prompt")
            showingHealthKitPrompt = true
            return
        }
        
        isLoadingSteps = true
        
        healthKitManager.getStepsForDate(date) { steps, error in
            isLoadingSteps = false
            
            if let error = error {
                print("DailyTrackingView: Error fetching steps: \(error.localizedDescription)")
                showingErrorMessage = true
                return
            }
            
            entry.stepsTaken = steps
            stepsTakenString = "\(steps)"
            saveEntry()
            print("DailyTrackingView: Successfully updated steps to \(steps)")
        }
    }
    
    private func importHistoricalStepData() {
        print("DailyTrackingView: Attempting to import historical step data")
        // First check if HealthKit is available on this device
        if !healthKitManager.isAvailable {
            print("DailyTrackingView: HealthKit not available for historical import")
            showingHealthKitNotAvailable = true
            return
        }
        
        // Then check if we're authorized
        if !healthKitManager.isAuthorized {
            print("DailyTrackingView: Not authorized for HealthKit historical import, showing prompt")
            showingHealthKitPrompt = true
            return
        }
        
        healthKitManager.importHistoricalStepData { stepsByDate, error in
            if let error = error {
                print("DailyTrackingView: Error importing historical step data: \(error.localizedDescription)")
                showingErrorMessage = true
                return
            }
            
            print("DailyTrackingView: Successfully imported \(stepsByDate.count) days of step data")
            
            // Create entries for each day with the imported step data
            for (date, steps) in stepsByDate {
                // Get the existing entry for this date, if any
                var dailyEntry = dailyTracker.getEntryFor(profileId: profile.id, date: date)
                
                // Only update if we have meaningful step data (greater than 0)
                if steps > 0 {
                    dailyEntry.stepsTaken = steps
                    dailyTracker.addEntry(dailyEntry)
                }
            }
            
            // If we're viewing today's data, update the current entry
            if isToday, let todaySteps = stepsByDate.first(where: { Calendar.current.isDate($0.0, inSameDayAs: date) })?.1 {
                if todaySteps > 0 {
                    entry.stepsTaken = todaySteps
                    stepsTakenString = "\(todaySteps)"
                    saveEntry()
                }
            }
            
            // Show success alert
            showingHistoricalImportSuccess = true
        }
    }
    
    private func requestHealthKitAuthorization() {
        print("DailyTrackingView: Requesting HealthKit authorization")
        healthKitManager.requestAuthorization { success, error in
            if success {
                print("DailyTrackingView: HealthKit authorization successful")
                loadStepsFromHealthKit()
            } else if let error = error {
                print("DailyTrackingView: HealthKit authorization failed: \(error.localizedDescription)")
                if healthKitManager.permissionsError {
                    showingPermissionsError = true
                } else {
                    showingErrorMessage = true
                }
            }
        }
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
