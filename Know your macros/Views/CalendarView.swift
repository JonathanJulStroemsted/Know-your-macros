import SwiftUI

struct CalendarView: View {
    @ObservedObject var profileManager: ProfileManager
    @ObservedObject var dailyTracker: DailyTracker
    let profile: Profile
    
    @State private var displayDate = Date()
    @State private var selectedDate = Date()
    @State private var showingEntry = false
    @State private var showingNewEntry = false
    
    let calendar = Calendar.current
    
    var body: some View {
        ZStack {
            // Calendar UI
            VStack {
                // Month and year header
                HStack {
                    Spacer()
                    
                    Text(monthYearFormatter.string(from: displayDate))
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
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
                
                // Calendar grid with drag gesture
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                    ForEach(Array(daysInMonth().enumerated()), id: \.offset) { index, date in
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
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            let threshold: CGFloat = 50
                            if value.translation.width > threshold {
                                withAnimation {
                                    changeMonth(by: -1)
                                }
                            } else if value.translation.width < -threshold {
                                withAnimation {
                                    changeMonth(by: 1)
                                }
                            }
                        }
                )
                
                Spacer()
                
                // Summary for selected month
                CalendarSummaryView(dailyTracker: dailyTracker, profile: profile, month: displayDate)
                    .padding()
            }
            
            // Hidden navigation link
            NavigationLink(
                destination: DailyTrackingView(
                    profile: profile,
                    profileManager: profileManager,
                    dailyTracker: dailyTracker,
                    date: selectedDate
                )
                .navigationTitle(dateFormatter.string(from: selectedDate)),
                isActive: $showingEntry
            ) {
                EmptyView()
            }
            .hidden()
            
            // Navigation link for new entry
            NavigationLink(
                destination: DailyTrackingView(
                    profile: profile,
                    profileManager: profileManager,
                    dailyTracker: dailyTracker
                )
                .navigationTitle("Today"),
                isActive: $showingNewEntry
            ) {
                EmptyView()
            }
            .hidden()
        }
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingNewEntry = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
    }
    
    // Helper to get all days in the current month view
    private func daysInMonth() -> [Date?] {
        var days = [Date?]()
        
        let range = calendar.range(of: .day, in: .month, for: displayDate)!
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: displayDate))!
        
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
    
    private func changeMonth(by value: Int) {
        if let newDate = calendar.date(byAdding: .month, value: value, to: displayDate) {
            print("🔄 displayDate was \(displayDate), now \(newDate)")
            displayDate = newDate
        }
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
    @State private var showingStepExplanation = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Month Summary")
                .font(.headline)
            
            VStack(spacing: 20) {
                // Calories consumed section and step counter in one row
                HStack {
                    // Calories counter
                    VStack {
                        HStack {
                            Text("\(totalCaloriesConsumed)/\(totalCalorieAllowance)")
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
                        
                        Text("Calories")
                            .font(.caption)
                    }
                    
                    Spacer()
                    
                    // Step counter with average for the month
                    VStack {
                        HStack {
                            Image(systemName: "figure.walk")
                                .foregroundColor(.blue)
                            
                            let averageSteps = calculateAverageSteps()
                            Text("\(averageSteps)")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(averageSteps >= 7500 ? .green : (averageSteps >= 5000 ? .orange : .red))
                            
                            Button(action: {
                                showingStepExplanation = true
                            }) {
                                Image(systemName: "info.circle")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        Text("Avg Steps")
                            .font(.caption)
                    }
                }
                .padding(.horizontal, 20) // control the space between the two rows for calories consumed and steps
                .padding(.vertical, 10)
                .alert("Step Goals", isPresented: $showingStepExplanation) {
                    Button("Got it", role: .cancel) { }
                } message: {
                    Text("Daily step targets: 7,500+ is excellent, 5,000-7,499 is good, below 5,000 needs improvement. The average is calculated only from days with recorded data.")
                }
                .alert("Calorie Calculation", isPresented: $showingCalorieExplanation) {
                    Button("Got it", role: .cancel) { }
                } message: {
                    Text("Your total calorie allowance includes calories burned from exercise. It is calculated as: Base Goal (\(trackedDaysCalorieGoal)) + Burned (\(totalCaloriesBurned)) = \(totalCalorieAllowance)")
                }
                
                // Days tracked and calories burned section
                HStack {
                    
                    
                    VStack {
                        Text("\(totalCaloriesBurned)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        Text("Calories Burned")
                            .font(.caption)
                    }
                    Spacer()
                    VStack {
                        Text("\(entriesInMonth.count)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        Text("Days Tracked")
                            .font(.caption)
                    }
                }
                                .padding(.horizontal, 10) // control the space between the two rows for calories burned and days tracked

            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.2))
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
    
    private func calculateAverageSteps() -> Int {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: month)!
        
        var totalSteps = 0
        var daysWithStepData = 0
        
        for day in range {
            let date = calendar.date(bySetting: .day, value: day, of: month)!
            
            // Get all entries for this profile and date
            let entriesForDay = dailyTracker.getEntryFor(profileId: profile.id, date: date)
            
            // Only count days where we have step data
            if entriesForDay.stepsTaken > 0 {
                totalSteps += entriesForDay.stepsTaken
                daysWithStepData += 1
            }
        }
        
        // Return the average, or 0 if no days with data
        return daysWithStepData > 0 ? totalSteps / daysWithStepData : 0
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
