import SwiftUI

struct ProfileEditorView: View {
    @ObservedObject var profileManager: ProfileManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var weight: Double = 75
    @State private var height: Double = 180
    @State private var age: Int = 25
    @State private var isMale: Bool = true
    @State private var activityLevelIndex: Int = 2
    @State private var goalIndex: Int = 0
    @State private var showingActivityLevelPicker = false
    
    // For editing mode
    let editingProfile: Profile?
    
    init(profileManager: ProfileManager, profile: Profile? = nil) {
        self.profileManager = profileManager
        self.editingProfile = profile
        
        if let profile = profile {
            _name = State(initialValue: profile.name)
            _weight = State(initialValue: profile.weight)
            _height = State(initialValue: profile.height)
            _age = State(initialValue: profile.age)
            _isMale = State(initialValue: profile.isMale)
            _activityLevelIndex = State(initialValue: profile.activityLevelIndex)
            _goalIndex = State(initialValue: profile.goalIndex)
        }
    }
    
    var activityLevel: CalorieCalculator.ActivityLevel {
        CalorieCalculator.ActivityLevel.allCases[activityLevelIndex]
    }
    
    var body: some View {
        Form {
            Section(header: Text("Profile Information")) {
                TextField("Name", text: $name)
            }
            
            Section(header: Text("Physical Details")) {
                Stepper("Weight: \(Int(weight)) kg", value: $weight, in: 30...200)
                Stepper("Height: \(Int(height)) cm", value: $height, in: 120...220)
                Stepper("Age: \(age) years", value: $age, in: 10...100)
                Picker("Gender", selection: $isMale) {
                    Text("Male").tag(true)
                    Text("Female").tag(false)
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            Section(header: Text("Goal")) {
                Picker("Goal", selection: $goalIndex) {
                    ForEach(0..<CalorieCalculator.Goal.allCases.count, id: \.self) { index in
                        Text(CalorieCalculator.Goal.allCases[index].displayName)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            Section(header: Text("Activity Level")) {
                NavigationLink(destination: ActivityLevelPickerView(activityLevelIndex: $activityLevelIndex)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(activityLevel.displayName.components(separatedBy: " (")[0])
                                .font(.headline)
                            
                            if let description = activityLevel.displayName.components(separatedBy: " (").dropFirst().first?.dropLast() {
                                Text(String(description))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(editingProfile == nil ? "Add Profile" : "Edit Profile")
        .toolbar {     
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveProfile()
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
    
    private func saveProfile() {
        let profile = Profile(
            id: editingProfile?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            weight: weight,
            height: height,
            age: age,
            isMale: isMale,
            activityLevelIndex: activityLevelIndex,
            goalIndex: goalIndex
        )
        
        if editingProfile != nil {
            profileManager.updateProfile(profile)
        } else {
            profileManager.addProfile(profile)
        }
        
        // Force an immediate UI update
        DispatchQueue.main.async {
            profileManager.objectWillChange.send()
        }
    }
}

struct ActivityLevelPickerView: View {
    @Binding var activityLevelIndex: Int
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            ForEach(0..<CalorieCalculator.ActivityLevel.allCases.count, id: \.self) { index in
                let activityLevel = CalorieCalculator.ActivityLevel.allCases[index]
                Button(action: {
                    activityLevelIndex = index
                    dismiss()
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(activityLevel.displayName.components(separatedBy: " (")[0])
                                .font(.headline)
                            
                            if let description = activityLevel.displayName.components(separatedBy: " (").dropFirst().first?.dropLast() {
                                Text(String(description))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if index == activityLevelIndex {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .navigationTitle("Select Activity Level")
    }
}

struct ProfileEditorView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileEditorView(profileManager: ProfileManager())
    }
}

