import SwiftUI

struct ExerciseSelectionView: View {
    @ObservedObject var viewModel: ExerciseViewModel
    @ObservedObject var dailyTracker: DailyTracker
    let profile: Profile
    let date: Date
    @EnvironmentObject var profileManager: ProfileManager
    
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedExercise: Exercise?
    @State private var showingSaveConfirmation = false
    @State private var navigateToExerciseDetail = false
    
    var body: some View {
        VStack {
            searchBar
            
            exerciseContent
            
            NavigationLink {
                UserExercisesView(viewModel: viewModel, dailyTracker: dailyTracker, profile: profile, date: date)
                    .environmentObject(profileManager)
            } label: {
                HStack {
                    Image(systemName: "list.bullet")
                    Text("View Selected Exercises (\(viewModel.selectedExercises.count))")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.mint)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
            }
            .disabled(viewModel.selectedExercises.isEmpty)
            .padding(.bottom)
        }
        .navigationTitle("Select Exercises")
        .onAppear(perform: loadExercises)
        .background(exerciseDetailNavLink)
        .toolbar {
            
        }
        .alert("Exercise Saved", isPresented: $showingSaveConfirmation) {
            Button("OK", role: .cancel) {
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("Your exercise has been saved. Remember to click 'Save Exercises' on the main screen to update your daily record.")
        }
    }
    
    // MARK: - View Components
    
    // Search bar component
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search exercises", text: $viewModel.searchText)
                .disableAutocorrection(true)
            
            if !viewModel.searchText.isEmpty {
                Button(action: {
                    viewModel.searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    // Main content showing exercises or loading states
    private var exerciseContent: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .padding()
            } else if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            } else if viewModel.exercises.isEmpty {
                emptyExercisesView
            } else {
                categoryGrid
                    .padding()
            }
        }
    }
    
    // View shown when no exercises are found
    private var emptyExercisesView: some View {
        VStack {
            Text("No exercises found")
                .foregroundColor(.gray)
                .padding()
            
            Button("Reload") {
                viewModel.loadExercises()
            }
            .padding()
        }
    }
    
    // Grid of exercise categories
    private var categoryGrid: some View {
        VStack {
            HStack {
                categoryView(name: "Chest", filter: "Chest")
                categoryView(name: "Shoulders", filter: "Shoulders")
            }
            HStack {
                categoryView(name: "Back", filter: "Back")
                categoryView(name: "Stomach", filter: "Abs")
            }
            HStack {
                categoryView(name: "Glutes", filter: "Glutes")
                categoryView(name: "Legs", filter: "Legs")
            }
        }
    }
    
    // Helper to create category views
    private func categoryView(name: String, filter: String) -> some View {
        CategoryBoxView(
            categoryName: name,
            exercises: viewModel.exercises.filter { $0.category.name == filter },
            viewModel: viewModel,
            selectedExercise: $selectedExercise,
            date: date,
            profile: profile
        )
    }
    
    // Navigation link for exercise detail
    private var exerciseDetailNavLink: some View {
        NavigationLink(isActive: $navigateToExerciseDetail) {
            if let exercise = selectedExercise {
                ExerciseDetailView(exercise: exercise, viewModel: viewModel, date: date, profile: profile)
                    .environmentObject(dailyTracker)
                    .environmentObject(profileManager)
            } else {
                EmptyView()
            }
        } label: {
            EmptyView()
        }
    }
    
    // MARK: - Actions
    
    // Load exercises on appear
    private func loadExercises() {
        viewModel.loadExercises()
        
        // Load any previously saved exercises for this day
        let existingEntry = dailyTracker.getEntryFor(profileId: profile.id, date: date)
        if let savedExercises = existingEntry.exercises, !savedExercises.isEmpty {
            // Initialize the viewModel with saved exercises
            print("Loading \(savedExercises.count) saved exercises")
            viewModel.selectedExercises = savedExercises
        }
    }
}

struct ExerciseRow: View {
    let exercise: Exercise
    let isSelected: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(exercise.name)
                    .font(.headline)
                
                if let description = exercise.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ExerciseDetailView: View {
    let exercise: Exercise
    @ObservedObject var viewModel: ExerciseViewModel
    let date: Date
    let profile: Profile
    
    @State private var showingProfileInfo = true
    @State private var sets: [WorkoutSet] = [WorkoutSet()]
    @State private var notes: String = ""
    @State private var showingSaveConfirmation = false
    @Environment(\.presentationMode) var presentationMode
    
    // Add these properties to access the daily tracker and profile
    @EnvironmentObject var dailyTracker: DailyTracker
    @EnvironmentObject var profileManager: ProfileManager
    
    var body: some View {
        NavigationView {
            VStack {
                // Profile Info Card (similar to Apple Health connection)
                if showingProfileInfo {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Quick Reference")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button(action: {
                                showingProfileInfo = false
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        // MET value information
                        Text("Exercise MET: \(exercise.met, specifier: "%.1f")")
                            .font(.subheadline)
                        
                        Text("This helps calculate calories burned based on your profile.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                
                // Exercise info
                VStack(alignment: .leading) {
                    Text(exercise.name)
                        .font(.title2)
                        .bold()
                    
                    if let description = exercise.description, !description.isEmpty {
                        Text(description)
                            .font(.body)
                            .padding(.top, 2)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 4)
                
                // Sets
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(0..<sets.count, id: \.self) { index in
                            WorkoutSetView(
                                setNumber: index + 1,
                                workoutSet: $sets[index],
                                onDelete: {
                                    if sets.count > 1 {
                                        sets.remove(at: index)
                                    }
                                },
                                onCopyPrevious: {
                                    if index > 0 {
                                        sets[index] = sets[index-1].copy()
                                    }
                                }
                            )
                        }
                        
                        // Add new set button
                        Button(action: {
                            sets.append(WorkoutSet())
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Set")
                            }
                            .foregroundColor(.mint)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        
                        // Total time
                        HStack {
                            Text("Total Estimated Time:")
                                .font(.headline)
                            Spacer()
                            Text(totalTimeFormatted)
                                .font(.headline)
                                .foregroundColor(.mint)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                        .padding(.horizontal)
                        
                        // Notes
                        VStack(alignment: .leading) {
                            Text("Notes:")
                            TextEditor(text: $notes)
                                .frame(height: 100)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
                
                // Save button
                Button(action: saveExerciseAction) {
                    Text("Save Exercise")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.mint)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Exercise Details")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert("Exercise Saved", isPresented: $showingSaveConfirmation) {
                Button("OK", role: .cancel) {
                    presentationMode.wrappedValue.dismiss()
                }
            } message: {
                Text("Your exercise has been saved and added to your workout.")
            }
        }
    }
    
    var isSelected: Bool {
        viewModel.isExerciseSelected(exercise)
    }
    
    var totalTime: Int {
        // Sum of all rest times (in seconds)
        let restTimeTotal = sets.dropLast().reduce(0) { $0 + $1.restTimeSeconds }
        
        // Estimate workout time - assume 30 seconds per set
        let workoutTimeEstimate = sets.count * 30
        
        return restTimeTotal + workoutTimeEstimate
    }
    
    var totalTimeFormatted: String {
        let minutes = totalTime / 60
        let seconds = totalTime % 60
        return "\(minutes)m \(seconds)s"
    }
    
    // Break up the complex calorie calculation into separate functions
    private func createUserExercise() -> UserExercise {
        return UserExercise(
            exercise: exercise,
            sets: sets.count,
            reps: sets.first?.reps ?? 0,
            weight: sets.first?.weight ?? 0,
            notes: notes.isEmpty ? nil : notes,
            date: date,
            workoutSets: sets
        )
    }
    
    private func updateSelectedExercises(with userExercise: UserExercise) {
        if let index = viewModel.selectedExercises.firstIndex(where: { $0.exercise.id == exercise.id }) {
            print("Updating existing exercise at index \(index)")
            viewModel.selectedExercises[index] = userExercise
        } else {
            print("Adding new exercise to selected exercises")
            viewModel.selectedExercises.append(userExercise)
        }
    }
    
    private func calculateSetCalories(set: WorkoutSet, metValue: Double, weight: Double) -> Int {
        // Calculate work phase calories
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
        let workDurationInHours = setDuration / 60.0
        
        // Work phase calories (using higher MET for active lifting)
        let workCalories = metValue * weight * workDurationInHours
        
        // Calculate mechanical work calories
        let weightLifted = set.weight
        let reps = set.reps
        let distancePerRep = 0.6 // meters (typical squat depth)
        let mechanicalWork = weightLifted * 9.81 * distancePerRep * Double(reps) // Joules
        let mechanicalCalories = (mechanicalWork / 4184.0) / 0.25 // Convert to calories and account for 25% efficiency
        
        // Rest phase calories (using lower MET for rest)
        let restDurationInHours = Double(set.restTimeSeconds) / 3600.0 // Use actual rest time from the set
        let restCalories = 1.3 * weight * restDurationInHours // 1.3 MET for rest
        
        // Add work, mechanical, and rest calories
        return Int(workCalories + mechanicalCalories + restCalories)
    }
    
    private func calculateTotalCalories(for profile: Profile) -> Int {
        var totalCalories = 0
        for userExercise in viewModel.selectedExercises {
            let metValue = userExercise.exercise.met
            
            if let workoutSets = userExercise.workoutSets, !workoutSets.isEmpty {
                for set in workoutSets {
                    totalCalories += calculateSetCalories(set: set, metValue: metValue, weight: Double(profile.weight))
                }
            } else {
                let durationInHours = Double(userExercise.sets) / 60.0
                let weight = Double(profile.weight)
                let calories = metValue * weight * durationInHours
                totalCalories += Int(calories)
            }
        }
        return totalCalories
    }
    
    private func updateDailyEntry(profile: Profile) {
        // Get current entry
        let dailyEntry = dailyTracker.getEntryFor(profileId: profile.id, date: date)
        var updatedEntry = dailyEntry
        
        // Save exercises to the daily entry
        updatedEntry.exercises = viewModel.selectedExercises
        
        // Calculate calories burned
        let totalCalories = calculateTotalCalories(for: profile)
        
        // Update calories
        let previousExerciseCalories = updatedEntry.caloriesBurnedExercise
        updatedEntry.caloriesBurnedExercise = totalCalories
        
        // Adjust available calories
        let calorieDifference = totalCalories - previousExerciseCalories
        if calorieDifference != 0 {
            if updatedEntry.caloriesAvailableAdjustment == nil {
                updatedEntry.caloriesAvailableAdjustment = calorieDifference
            } else {
                updatedEntry.caloriesAvailableAdjustment! += calorieDifference
            }
        }
        
        // Save to daily tracker
        dailyTracker.updateEntry(updatedEntry)
        dailyTracker.saveEntries()
        
        print("Exercise saved directly to daily entry with \(totalCalories) calories")
    }
    
    // Add saveExerciseAction method
    private func saveExerciseAction() {
        // Create UserExercise with workout data
        let userExercise = createUserExercise()
        
        print("Saving exercise: \(exercise.name) with \(sets.count) sets")
        
        // Add or update exercise in the view model
        updateSelectedExercises(with: userExercise)
        
        // DIRECTLY SAVE TO DAILY TRACKER
        updateDailyEntry(profile: profile)
        
        print("Total selected exercises: \(viewModel.selectedExercises.count)")
        
        showingSaveConfirmation = true
    }
}

// View for a single workout set
struct WorkoutSetView: View {
    let setNumber: Int
    @Binding var workoutSet: WorkoutSet
    let onDelete: () -> Void
    let onCopyPrevious: () -> Void
    
    // Rest time presets
    let restTimePresets = [30, 60, 90, 120, 180]
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("Set \(setNumber)")
                    .font(.headline)
                
                Spacer()
                
                if setNumber > 1 {
                    Button("Same as previous") {
                        onCopyPrevious()
                    }
                    .font(.caption)
                    .foregroundColor(.mint)
                }
                
                if setNumber > 1 {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            
            // Set details
            HStack {
                // Weight
                VStack(alignment: .leading) {
                    Text("Weight (kg)")
                        .font(.caption)
                    TextField("0", value: $workoutSet.weight, formatter: NumberFormatter())
                        .padding(8)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
                
                // Reps
                VStack(alignment: .leading) {
                    Text("Reps")
                        .font(.caption)
                    TextField("0", value: $workoutSet.reps, formatter: NumberFormatter())
                        .padding(8)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            
            // Tempo
            VStack(alignment: .leading) {
                Text("Tempo")
                    .font(.caption)
                Picker("Tempo", selection: $workoutSet.tempo) {
                    ForEach(SetTempo.allCases, id: \.self) { tempo in
                        Text(tempo.rawValue).tag(tempo)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            // Rest time
            VStack(alignment: .leading) {
                Text("Rest Time (seconds)")
                    .font(.caption)
                
                HStack {
                    ForEach(restTimePresets, id: \.self) { seconds in
                        Button(action: {
                            workoutSet.restTimeSeconds = seconds
                        }) {
                            Text("\(seconds)s")
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(workoutSet.restTimeSeconds == seconds ? Color.mint : Color.gray.opacity(0.2))
                                .foregroundColor(workoutSet.restTimeSeconds == seconds ? .white : .primary)
                                .cornerRadius(8)
                        }
                    }
                    
                    Button(action: {
                        // Custom time option
                    }) {
                        Image(systemName: "ellipsis")
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(!restTimePresets.contains(workoutSet.restTimeSeconds) ? Color.mint : Color.gray.opacity(0.2))
                            .foregroundColor(!restTimePresets.contains(workoutSet.restTimeSeconds) ? .white : .primary)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

struct UserExercisesView: View {
    @ObservedObject var viewModel: ExerciseViewModel
    @ObservedObject var dailyTracker: DailyTracker
    let profile: Profile
    let date: Date
    
    @Environment(\.presentationMode) var presentationMode
    @State private var editingExerciseIndex: Int? = nil
    @State private var showingSaveConfirmation = false
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.selectedExercises.isEmpty {
                    Text("No exercises selected yet")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    List {
                        ForEach(Array(viewModel.selectedExercises.enumerated()), id: \.element.id) { index, userExercise in
                            NavigationLink {
                                EditUserExerciseView(
                                    userExercise: userExercise,
                                    onSave: { updated in
                                        var exercise = viewModel.selectedExercises[index]
                                        exercise.sets = updated.sets
                                        exercise.reps = updated.reps
                                        exercise.weight = updated.weight
                                        exercise.notes = updated.notes
                                        viewModel.selectedExercises[index] = exercise
                                    }
                                )
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(userExercise.exercise.name)
                                        .font(.headline)
                                    
                                    HStack {
                                        Text("\(userExercise.sets) sets")
                                        Text("•")
                                        Text("\(userExercise.reps) reps")
                                        if userExercise.weight > 0 {
                                            Text("•")
                                            Text("\(Int(userExercise.weight)) kg")
                                        }
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    
                                    if let notes = userExercise.notes, !notes.isEmpty {
                                        Text(notes)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                            .padding(.top, 4)
                                    }
                                }
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                viewModel.removeExercise(at: index)
                            }
                        }
                    }
                }
                
                Button(action: {
                    // Save exercises to daily tracker
                    saveExercises()
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Save Exercises")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.mint)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding()
                .disabled(viewModel.selectedExercises.isEmpty)
            }
            .navigationTitle("Selected Exercises")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        // Save exercises when user presses Done
                        saveExercises()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert("Workout Data Saved", isPresented: $showingSaveConfirmation) {
                Button("OK", role: .cancel) { 
                    presentationMode.wrappedValue.dismiss()
                }
            } message: {
                Text("Your workout data has been saved and calories updated.")
            }
        }
    }
    
    // Function to save exercises to the daily entry
    private func saveExercises() {
        print("Saving \(viewModel.selectedExercises.count) exercises to daily entry")
        
        // Get the current entry and update it
        let updatedEntry = prepareUpdatedEntry()
        
        // Update daily tracker
        dailyTracker.updateEntry(updatedEntry)
        
        // Force a save to ensure data is persisted
        dailyTracker.saveEntries()
        print("Updated entry with \(viewModel.selectedExercises.count) exercises and \(updatedEntry.caloriesBurnedExercise) calories burned")
        
        showingSaveConfirmation = true
    }
    
    // Prepare the updated entry with exercises and calorie calculations
    private func prepareUpdatedEntry() -> DailyEntry {
        let dailyEntry = dailyTracker.getEntryFor(profileId: profile.id, date: date)
        var updatedEntry = dailyEntry
        
        // Calculate calories burned based on MET values and exercise details
        let caloriesBurned = calculateCaloriesBurned()
        
        // Only update if there was a change
        let previousExerciseCalories = updatedEntry.caloriesBurnedExercise
        updatedEntry.caloriesBurnedExercise = caloriesBurned
        
        // Save exercises to the daily entry
        updatedEntry.exercises = viewModel.selectedExercises
        
        // Adjust available calories
        updateCalorieAdjustment(entry: &updatedEntry, caloriesBurned: caloriesBurned, previousCalories: previousExerciseCalories)
        
        return updatedEntry
    }
    
    // Update the calorie adjustment based on the difference
    private func updateCalorieAdjustment(entry: inout DailyEntry, caloriesBurned: Int, previousCalories: Int) {
        let calorieDifference = caloriesBurned - previousCalories
        if calorieDifference != 0 {
            // If there was no adjustment before, initialize it
            if entry.caloriesAvailableAdjustment == nil {
                entry.caloriesAvailableAdjustment = calorieDifference
            } else {
                entry.caloriesAvailableAdjustment! += calorieDifference
            }
        }
    }
    
    // Calculate calories burned based on MET values and exercise details
    private func calculateCaloriesBurned() -> Int {
        var totalCalories = 0
        
        for userExercise in viewModel.selectedExercises {
            totalCalories += calculateCaloriesForExercise(userExercise)
        }
        
        return totalCalories
    }
    
    // Calculate calories for a single exercise
    private func calculateCaloriesForExercise(_ userExercise: UserExercise) -> Int {
        let exercise = userExercise.exercise
        let metValue = exercise.met
        
        // If we have detailed workout sets, use them for calculation
        if let workoutSets = userExercise.workoutSets, !workoutSets.isEmpty {
            return calculateCaloriesForSets(workoutSets, metValue: metValue)
        } else {
            // For exercises without detailed data, use the traditional estimate
            return calculateEstimatedCalories(sets: userExercise.sets, metValue: metValue)
        }
    }
    
    // Calculate calories for workout sets
    private func calculateCaloriesForSets(_ sets: [WorkoutSet], metValue: Double) -> Int {
        var totalCalories = 0
        let weight = Double(profile.weight)
        
        for (index, set) in sets.enumerated() {
            // Calculate work phase calories
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
            let workDurationInHours = setDuration / 60.0
            
            // Work phase calories (using higher MET for active lifting)
            let workCalories = metValue * weight * workDurationInHours
            
            // Calculate mechanical work calories
            let weightLifted = set.weight
            let reps = set.reps
            let distancePerRep = 0.6 // meters (typical squat depth)
            let mechanicalWork = weightLifted * 9.81 * distancePerRep * Double(reps) // Joules
            let mechanicalCalories = (mechanicalWork / 4184.0) / 0.25 // Convert to calories and account for 25% efficiency
            
            // Rest phase calories (using lower MET for rest)
            // Only count rest if it's not the last set
            var restCalories = 0.0
            if index < sets.count - 1 {
                let restDurationInHours = Double(set.restTimeSeconds) / 3600.0
                restCalories = 1.3 * weight * restDurationInHours // 1.3 MET for rest
            }
            
            // Add work, mechanical, and rest calories
            totalCalories += Int(workCalories + mechanicalCalories + restCalories)
        }
        
        return totalCalories
    }
    
    // Calculate estimated calories for basic exercises
    private func calculateEstimatedCalories(sets: Int, metValue: Double) -> Int {
        // Estimate: 1 set takes about 1 minute
        let durationInHours = Double(sets) / 60.0
        let weight = Double(profile.weight)
        return Int(metValue * weight * durationInHours)
    }
}

extension Int: Identifiable {
    public var id: Int { self }
}

struct EditUserExerciseView: View {
    let userExercise: UserExercise
    let onSave: (UserExercise) -> Void
    
    @State private var sets: Int
    @State private var reps: Int
    @State private var weight: Double
    @State private var notes: String
    
    @Environment(\.presentationMode) var presentationMode
    
    init(userExercise: UserExercise, onSave: @escaping (UserExercise) -> Void) {
        self.userExercise = userExercise
        self.onSave = onSave
        
        _sets = State(initialValue: userExercise.sets)
        _reps = State(initialValue: userExercise.reps)
        _weight = State(initialValue: userExercise.weight)
        _notes = State(initialValue: userExercise.notes ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text(userExercise.exercise.name)
                        .font(.headline)
                } header: {
                    Text("Exercise Info")
                }
                
                Section {
                    Stepper("Sets: \(sets)", value: $sets, in: 1...10)
                    Stepper("Reps: \(reps)", value: $reps, in: 1...100)
                    
                    HStack {
                        Text("Weight (kg):")
                        Spacer()
                        TextField("0", value: $weight, formatter: NumberFormatter())
                            .multilineTextAlignment(.trailing)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Notes:")
                        TextEditor(text: $notes)
                            .frame(height: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                } header: {
                    Text("Customize Exercise")
                }
            }
            .navigationTitle("Edit Exercise")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        var updated = userExercise
                        updated.sets = sets
                        updated.reps = reps
                        updated.weight = weight
                        updated.notes = notes.isEmpty ? nil : notes
                        
                        onSave(updated)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// Define a new view for category boxes
struct CategoryBoxView: View {
    let categoryName: String
    let exercises: [Exercise]
    @ObservedObject var viewModel: ExerciseViewModel
    @Binding var selectedExercise: Exercise?
    let date: Date
    let profile: Profile
    
    // Environment objects
    @EnvironmentObject var dailyTracker: DailyTracker
    @EnvironmentObject var profileManager: ProfileManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationLink {
            List(exercises) { exercise in
                NavigationLink {
                    ExerciseDetailView(exercise: exercise, viewModel: viewModel, date: date, profile: profile)
                        .environmentObject(dailyTracker)
                        .environmentObject(profileManager)
                } label: {
                    ExerciseRow(exercise: exercise, isSelected: viewModel.isExerciseSelected(exercise))
                }
            }
            .navigationTitle(categoryName)
        } label: {
            Text(categoryName)
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .frame(minHeight: 100)
                .background(Color.mint)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
    }
}

#Preview {
    ExerciseSelectionView(
        viewModel: ExerciseViewModel(),
        dailyTracker: DailyTracker(),
        profile: Profile(
            name: "Jane Doe",
            weight: 65,
            height: 170,
            age: 28,
            isMale: false,
            activityLevelIndex: 1,
            goalIndex: 1
        ),
        date: Date()
    )
} 
