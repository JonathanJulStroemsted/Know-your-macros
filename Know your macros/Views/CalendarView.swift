import SwiftUI

struct CalendarView: View {
    @ObservedObject var profileManager: ProfileManager
    @ObservedObject var dailyTracker: DailyTracker
    let profile: Profile
    
    @State private var selectedDate = Date()
    @State private var showingEntry = false
    
    let calendar = Calendar.current
    
    var body: some View {
        VStack {
            // Month and year header
            HStack {
                Button(action: {
                    if let newDate = calendar.date(byAdding: .month, value: -1, to: selectedDate) {
                        selectedDate = newDate
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Text(monthYearFormatter.string(from: selectedDate))
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {
                    if let newDate = calendar.date(byAdding: .month, value: 1, to: selectedDate) {
                        selectedDate = newDate
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            .padding(.top, 20)
            
            // Day of week headers
            HStack {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 8)
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                ForEach(daysInMonth(), id: \.self) { date in
                    if let date = date {
                        let hasEntry = dailyTracker.hasEntryFor(profileId: profile.id, date: date)
                        Button(action: {
                            selectedDate = date
                            showingEntry = true
                        }) {
                            Text(dayFormatter.string(from: date))
                                .fontWeight(hasEntry ? .bold : .regular)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .aspectRatio(1, contentMode: .fill)
                                .background(
                                    Circle()
                                        .fill(hasEntry ? Color.blue.opacity(0.3) : Color.clear)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(
                                            calendar.isDateInToday(date) ? Color.blue : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        Text("")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Summary for selected month
            CalendarSummaryView(dailyTracker: dailyTracker, profile: profile, month: selectedDate)
                .padding()
        }
        .navigationTitle("History")
        .sheet(isPresented: $showingEntry) {
            NavigationView {
                DailyTrackingView(profile: profile, profileManager: profileManager, dailyTracker: dailyTracker, date: selectedDate)
                    .navigationTitle(dateFormatter.string(from: selectedDate))
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                showingEntry = false
                            }
                        }
                    }
            }
        }
    }
    
    // Helper to get all days in the current month view
    private func daysInMonth() -> [Date?] {
        var days = [Date?]()
        
        let range = calendar.range(of: .day, in: .month, for: selectedDate)!
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate))!
        
        // Add empty days for start of month
        let weekday = calendar.component(.weekday, from: firstDay)
        let numEmptyDays = (weekday - calendar.firstWeekday + 7) % 7
        days.append(contentsOf: Array(repeating: nil, count: numEmptyDays))
        
        // Add actual days
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        
        // Add empty days to fill last row if needed
        let remainingDays = (7 - (days.count % 7)) % 7
        days.append(contentsOf: Array(repeating: nil, count: remainingDays))
        
        return days
    }
    
    private var daysOfWeek: [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        
        var weekdaySymbols = formatter.shortWeekdaySymbols ?? ["S", "M", "T", "W", "T", "F", "S"]
        
        // Adjust for calendar's first weekday if needed
        let firstWeekdayIndex = calendar.firstWeekday - 1
        if firstWeekdayIndex > 0 {
            let start = weekdaySymbols[firstWeekdayIndex...]
            let end = weekdaySymbols[..<firstWeekdayIndex]
            weekdaySymbols = Array(start + end)
        }
        
        return weekdaySymbols
    }
    
    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }
    
    private var monthYearFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
}

struct CalendarSummaryView: View {
    @ObservedObject var dailyTracker: DailyTracker
    let profile: Profile
    let month: Date
    @State private var showingCalorieExplanation = false
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Month Summary")
                .font(.headline)
            
            VStack(spacing: 16) {
                // Calories consumed section
                VStack {
                    HStack {
                        Text("\(totalCaloriesConsumed)/\(totalCalorieAllowance) !")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(totalCaloriesConsumed > totalCalorieAllowance ? .red : .green)
                        
                        Button(action: {
                            showingCalorieExplanation = true
                        }) {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .alert("Calorie Calculation", isPresented: $showingCalorieExplanation) {
                        Button("Got it", role: .cancel) { }
                    } message: {
                        Text("Your total calorie allowance includes calories burned from exercise. It is calculated as: Base Goal (\(trackedDaysCalorieGoal)) + Burned (\(totalCaloriesBurned)) = \(totalCalorieAllowance)")
                    }
                    
                    Text("Calories Consumed")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                
                // Days tracked and calories burned section
                HStack(spacing: 40) {
                    VStack {
                        Text("\(entriesInMonth.count)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        Text("Days Tracked")
                            .font(.caption)
                    }
                    
                    VStack {
                        Text("\(totalCaloriesBurned)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        Text("Calories Burned")
                            .font(.caption)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    var entriesInMonth: [DailyEntry] {
        dailyTracker.getEntriesForMonth(profileId: profile.id, date: month)
    }
    
    var totalCaloriesConsumed: Int {
        entriesInMonth.reduce(0) { $0 + $1.caloriesConsumed }
    }
    
    var totalCaloriesBurned: Int {
        entriesInMonth.reduce(0) { $0 + $1.totalCaloriesBurned }
    }
    
    var dailyCalorieGoal: Int {
        let bmr = CalorieCalculator.calculateBMR(
            weightKg: profile.weight,
            heightCm: profile.height,
            age: profile.age,
            isMale: profile.isMale
        )
        
        let tdee = CalorieCalculator.calculateTDEE(
            bmr: bmr,
            activityLevel: CalorieCalculator.ActivityLevel.allCases[profile.activityLevelIndex]
        )
        
        return Int(CalorieCalculator.dailyCalories(
            tdee: tdee,
            goal: CalorieCalculator.Goal.allCases[profile.goalIndex]
        ))
    }
    
    var trackedDaysCalorieGoal: Int {
        // Calculate calorie goal only for tracked days
        return dailyCalorieGoal * entriesInMonth.count
    }
    
    var totalCalorieAllowance: Int {
        // Base goal + burned calories
        return trackedDaysCalorieGoal + totalCaloriesBurned
    }
}

#Preview {
    NavigationView {
        CalendarView(
            profileManager: ProfileManager(),
            dailyTracker: DailyTracker(),
            profile: Profile(
                name: "John Doe",
                weight: 75,
                height: 180,
                age: 30,
                isMale: true,
                activityLevelIndex: 2,
                goalIndex: 0
            )
        )
    }
} 