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
    @State private var showingExerciseSelection = false
    @State private var showingWorkoutDetail = false
    @State private var selectedExercise: UserExercise?
    @State private var showingSaveConfirmation = false
    
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
        let adjustment = entry.caloriesAvailableAdjustment ?? 0
        return dailyCalories - entry.caloriesConsumed + entry.totalCaloriesBurned + adjustment
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
                
                Section(header: Text("Exercise")) {
                    NavigationLink {
                        makeExerciseSelectionView()
                            .environmentObject(dailyTracker)
                    } label: {
                        HStack {
                            Image(systemName: "figure.run")
                                .font(.title2)
                                .foregroundColor(.blue)
                            Text("Add Exercise")
                            Spacer()
                        }
                    }
                    
                    if let exercises = entry.exercises, !exercises.isEmpty {
                        ForEach(exercises) { exercise in
                            NavigationLink {
                                WorkoutDetailView(exercise: exercise)
                            } label: {
                                HStack {
                                    Image(systemName: "figure.run")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                    VStack(alignment: .leading) {
                                        Text(exercise.exercise.name)
                                            .font(.headline)
                                        if let sets = exercise.workoutSets, !sets.isEmpty {
                                            Text("\(sets.count) sets")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        } else {
                                            Text("\(exercise.sets) sets")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                 
                                }
                            }
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
                    Text("From Exercises:")
                    Spacer()
                    Text("\(entry.caloriesBurnedExercise)")
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
            
            Section(header: Text("Logged Exercises")) {
                if let exercises = entry.exercises, !exercises.isEmpty {
                    ForEach(exercises) { exercise in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(exercise.exercise.name)
                                    .font(.headline)
                                
                                HStack {
                                    if let workoutSets = exercise.workoutSets, !workoutSets.isEmpty {
                                        Text("\(workoutSets.count) sets")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("\(exercise.sets) sets • \(exercise.reps) reps")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    if exercise.weight > 0 {
                                        Text("• \(Int(exercise.weight)) kg")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            // Show detailed info button if the exercise has workout sets
                            if let workoutSets = exercise.workoutSets, !workoutSets.isEmpty {
                                Button(action: {
                                    selectedExercise = exercise
                                    showingWorkoutDetail = true
                                }) {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.mint)
                                }
                            }
                        }
                    }
                } else {
                    Text("No exercises logged for this day")
                        .foregroundColor(.gray)
                        .italic()
                }
                
                NavigationLink {
                    makeExerciseSelectionView()
                        .environmentObject(dailyTracker)
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.mint)
                        Text("Add or Edit Exercises")
                        Spacer()
                    }
                }
                
                // Add explicit save button for exercises
                if let exercises = entry.exercises, !exercises.isEmpty {
                    Button(action: {
                        // Explicitly save the exercises to ensure they're properly stored
                        var updatedEntry = entry
                        updatedEntry.exercises = exercises
                        
                        // Calculate calories burned (more accurate with MET values)
                        let burnedCalories = calculateCaloriesBurned(from: exercises)
                        updatedEntry.caloriesBurnedExercise = burnedCalories
                        
                        // Adjust available calories based on exercise
                        updatedEntry.caloriesAvailableAdjustment = burnedCalories
                        
                        // Save the updated entry
                        dailyTracker.updateEntry(profileId: profile.id, date: date, entry: updatedEntry)
                        
                        // Show confirmation
                        showingSaveConfirmation = true
                        
                        // Update the view with the new data
                        entry = updatedEntry
                        
                    }) {
                        Label("Save Workout Data", systemImage: "arrow.down.doc.fill")
                            .foregroundColor(.mint)
                    }
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
                    
                    if let adjustment = entry.caloriesAvailableAdjustment, adjustment > 0 {
                        Text("+ Exercise Adjustment (\(adjustment) extra calories available)")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
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
            
            // Verify if we have exercise data
            if let exercises = freshEntry.exercises, !exercises.isEmpty {
                print("Found \(exercises.count) exercises for \(dateFormatter.string(from: date))")
            } else {
                print("No exercises found for \(dateFormatter.string(from: date))")
            }
            
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
        .alert("Workout Data Saved", isPresented: $showingSaveConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your workout data has been saved and calories updated.")
        }
        .onChange(of: healthKitManager.permissionsError) { _, newValue in
            if newValue {
                showingPermissionsError = true
            }
        }
        .onChange(of: showingWorkoutDetail) { _, isShowing in
            if !isShowing {
                // Refresh the entry when returning from workout detail view
                let updatedEntry = dailyTracker.getEntryFor(profileId: profile.id, date: date)
                entry = updatedEntry
                // Update the UI
                caloriesConsumedString = "\(updatedEntry.caloriesConsumed)"
                caloriesBurnedGymString = "\(updatedEntry.caloriesBurnedGym)" 
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
    
    private func makeExerciseSelectionView() -> some View {
        let viewModel = ExerciseViewModel()
        
        // Explicitly load the entry to get the most up-to-date data
        let freshEntry = dailyTracker.getEntryFor(profileId: profile.id, date: date)
        
        // Pre-populate the viewModel with saved exercises if they exist
        if let savedExercises = freshEntry.exercises, !savedExercises.isEmpty {
            print("Pre-populating ExerciseSelectionView with \(savedExercises.count) saved exercises")
            viewModel.selectedExercises = savedExercises
        } else {
            print("No saved exercises to pre-populate")
        }
        
        // Create the view and pass environment objects
        return ExerciseSelectionView(viewModel: viewModel, dailyTracker: dailyTracker, profile: profile, date: date)
            .environmentObject(profileManager)
            .onDisappear {
                // Refresh the entry when returning from exercise selection
                let updatedEntry = dailyTracker.getEntryFor(profileId: profile.id, date: date)
                entry = updatedEntry
                // Update the calories in the UI
                caloriesConsumedString = "\(updatedEntry.caloriesConsumed)"
                caloriesBurnedGymString = "\(updatedEntry.caloriesBurnedGym)" 
            }
    }
    
    private func calculateCaloriesBurned(from exercises: [UserExercise]) -> Int {
        var totalCalories = 0
        
        for userExercise in exercises {
            let exercise = userExercise.exercise
            let metValue = exercise.met
            
            // If we have detailed workout sets, use them for calculation
            if let workoutSets = userExercise.workoutSets, !workoutSets.isEmpty {
                for set in workoutSets {
                    // Each set duration in minutes (estimate based on reps and tempo)
                    var setDuration = Double(set.reps) * 0.05 // Base: 3 seconds per rep
                    
                    // Adjust for tempo
                    switch set.tempo {
                    case .slow:
                        setDuration *= 1.5
                    case .normal:
                        setDuration *= 1.0
                    case .fast:
                        setDuration *= 0.8
                    case .stopAndGo:
                        setDuration *= 1.3
                    }
                    
                    // Convert to hours for MET formula
                    let durationInHours = setDuration / 60.0
                    
                    // Use profile weight for calculation
                    let weight = Double(profile.weight)
                    
                    // MET formula: Calories = MET × weight(kg) × duration(hrs)
                    let setCalories = metValue * weight * durationInHours
                    totalCalories += Int(setCalories)
                }
            } else {
                // For exercises without detailed data, use the traditional estimate
                // Estimate: 1 set takes about 1 minute
                let durationInHours = Double(userExercise.sets) / 60.0
                let weight = Double(profile.weight)
                let calories = metValue * weight * durationInHours
                totalCalories += Int(calories)
            }
        }
        
        return totalCalories
    }
}

struct WorkoutDetailView: View {
    let exercise: UserExercise
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Exercise header
                Text(exercise.exercise.name)
                    .font(.largeTitle)
                    .bold()
                    .padding(.bottom, 4)
                
                if let description = exercise.exercise.description, !description.isEmpty {
                    Text(description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)
                }
                
                // MET value
                Text("MET Value: \(exercise.exercise.met, specifier: "%.1f")")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .padding(.bottom, 16)
                
                // Sets detail
                if let workoutSets = exercise.workoutSets, !workoutSets.isEmpty {
                    Text("Sets")
                        .font(.headline)
                        .padding(.bottom, 2)
                    
                    ForEach(Array(workoutSets.enumerated()), id: \.element.id) { index, set in
                        VStack(alignment: .leading) {
                            Text("Set \(index + 1)")
                                .font(.subheadline)
                                .fontWeight(.bold)
                            
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Weight")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(set.weight, specifier: "%.1f") kg")
                                        .font(.body)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .leading) {
                                    Text("Reps")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(set.reps)")
                                        .font(.body)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .leading) {
                                    Text("Tempo")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(set.tempo.rawValue)
                                        .font(.body)
                                }
                            }
                            
                            if index < workoutSets.count - 1 {
                                HStack {
                                    Text("Rest: \(set.restTimeSeconds) seconds")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                } else {
                    // Basic exercise info without detailed sets
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Sets:")
                                .font(.headline)
                            Text("\(exercise.sets)")
                        }
                        
                        HStack {
                            Text("Reps:")
                                .font(.headline)
                            Text("\(exercise.reps)")
                        }
                        
                        if exercise.weight > 0 {
                            HStack {
                                Text("Weight:")
                                    .font(.headline)
                                Text("\(exercise.weight, specifier: "%.1f") kg")
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                // Notes
                if let notes = exercise.notes, !notes.isEmpty {
                    Text("Notes")
                        .font(.headline)
                        .padding(.top, 8)
                    
                    Text(notes)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
            .padding()
        }
        .navigationTitle("Workout Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    let profile = Profile(
        name: "John Doe",
        weight: 75,
        height: 180,
        age: 30,
        isMale: true,
        activityLevelIndex: 2,
        goalIndex: 0
    )
    
    let profileManager = ProfileManager()
    let dailyTracker = DailyTracker()
    
    // Create a sample entry to make preview work
    var entry = DailyEntry(profileId: profile.id)
    entry.caloriesConsumed = 1500
    entry.stepsTaken = 8000
    entry.caloriesBurnedGym = 200
    
    // Add it to the tracker so it's available in the preview
    dailyTracker.addEntry(entry)
    
    return DailyTrackingView(
        profile: profile,
        profileManager: profileManager,
        dailyTracker: dailyTracker
    )
} 
