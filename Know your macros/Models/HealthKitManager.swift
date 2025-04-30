import Foundation
import HealthKit

class HealthKitManager: ObservableObject {
    private var healthStore: HKHealthStore?
    @Published var isAuthorized = false
    @Published var isAvailable = false
    @Published var permissionsError = false
    @Published var lastErrorMessage: String = ""
    @Published var isImportingBulkData = false
    @Published var bulkImportProgress: Double = 0.0
    
    // Check if HealthKit is available on the device
    var isHealthDataAvailable: Bool {
        return isAvailable
    }
    
    init() {
        print("HealthKitManager: Initializing...")
        // Initialize HealthKit if available
        if HKHealthStore.isHealthDataAvailable() {
            print("HealthKitManager: HealthKit is available")
            isAvailable = true
            healthStore = HKHealthStore()
            checkAuthorization()
        } else {
            print("HealthKitManager: HealthKit is not available on this device/simulator")
            isAvailable = false
            isAuthorized = false
        }
    }
    
    // Request authorization to access HealthKit data
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        print("HealthKitManager: Requesting authorization...")
        // Ensure HealthKit is available
        guard isAvailable, let healthStore = healthStore else {
            print("HealthKitManager: HealthKit is not available for authorization")
            lastErrorMessage = "HealthKit is not available on this device"
            completion(false, nil)
            return
        }
        
        // Define the step count type we want to read
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            print("HealthKitManager: Failed to get step count type")
            lastErrorMessage = "Failed to get step count type"
            completion(false, nil)
            return
        }
        
        // Request authorization for step data
        do {
            print("HealthKitManager: Requesting HealthKit authorization...")
            healthStore.requestAuthorization(toShare: [], read: [stepType]) { success, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("HealthKitManager: Authorization error: \(error.localizedDescription)")
                        self.lastErrorMessage = error.localizedDescription
                        
                        // Check if this is a permissions-related error
                        if (error as NSError).domain == "com.apple.healthkit" {
                            print("HealthKitManager: Permission error detected")
                            self.permissionsError = true
                        }
                    } else if success {
                        print("HealthKitManager: Authorization successful")
                    } else {
                        print("HealthKitManager: Authorization denied by user")
                        self.lastErrorMessage = "Authorization denied by user"
                    }
                    
                    self.isAuthorized = success
                    completion(success, error)
                }
            }
        } catch {
            print("HealthKitManager: Authorization exception: \(error.localizedDescription)")
            lastErrorMessage = error.localizedDescription
            DispatchQueue.main.async {
                self.permissionsError = true
                completion(false, error)
            }
        }
    }
    
    // Check existing authorization status
    func checkAuthorization() {
        guard isAvailable, let healthStore = healthStore else { 
            print("HealthKitManager: Cannot check authorization, HealthKit not available")
            return 
        }
        
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { 
            print("HealthKitManager: Failed to get step count type for auth check")
            return 
        }
        
        let status = healthStore.authorizationStatus(for: stepType)
        isAuthorized = (status == .sharingAuthorized)
        print("HealthKitManager: Authorization status: \(status.rawValue) (authorized: \(isAuthorized))")
    }
    
    // Get steps for a specific date
    func getStepsForDate(_ date: Date, completion: @escaping (Int, Error?) -> Void) {
        print("HealthKitManager: Getting steps for \(date)")
        guard isAvailable, isAuthorized, let healthStore = healthStore else {
            print("HealthKitManager: Cannot get steps, not available or not authorized")
            completion(0, nil)
            return
        }
        
        // Define step type
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            print("HealthKitManager: Failed to get step count type for query")
            completion(0, nil)
            return
        }
        
        // Set up predicate for the specific day
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        print("HealthKitManager: Querying steps from \(startOfDay) to \(endOfDay)")
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        
        // Set up query for statistics
        let query = HKStatisticsQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("HealthKitManager: Error getting steps: \(error.localizedDescription)")
                    self.lastErrorMessage = error.localizedDescription
                    completion(0, error)
                    return
                }
                
                guard let result = result, let sum = result.sumQuantity() else {
                    print("HealthKitManager: No step data found")
                    completion(0, nil)
                    return
                }
                
                // Get the step count as an integer
                let steps = Int(sum.doubleValue(for: HKUnit.count()))
                print("HealthKitManager: Found \(steps) steps")
                completion(steps, nil)
            }
        }
        
        // Execute query
        do {
            print("HealthKitManager: Executing step query")
            healthStore.execute(query)
        } catch {
            print("HealthKitManager: Error executing query: \(error.localizedDescription)")
            lastErrorMessage = error.localizedDescription
            DispatchQueue.main.async {
                completion(0, error)
            }
        }
    }
    
    // Get steps for a range of dates (current month and previous month)
    func importHistoricalStepData(completion: @escaping ([(Date, Int)], Error?) -> Void) {
        print("HealthKitManager: Starting historical step data import")
        guard isAvailable, isAuthorized, let healthStore = healthStore else {
            print("HealthKitManager: Cannot import historical data, not available or not authorized")
            completion([], nil)
            return
        }
        
        // Define step type
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            print("HealthKitManager: Failed to get step count type for historical query")
            completion([], nil)
            return
        }
        
        // Set up date range for current month and previous month
        let calendar = Calendar.current
        let today = Date()
        
        // Calculate first day of previous month
        var components = calendar.dateComponents([.year, .month], from: today)
        components.month = components.month! - 1 // Previous month
        components.day = 1
        
        guard let startDate = calendar.date(from: components) else {
            print("HealthKitManager: Failed to calculate start date for import")
            completion([], nil)
            return
        }
        
        // End date is end of today
        let endDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: today)!
        
        print("HealthKitManager: Importing step data from \(startDate) to \(endDate)")
        DispatchQueue.main.async {
            self.isImportingBulkData = true
            self.bulkImportProgress = 0.0
        }
        
        // Set up interval components - we'll query by day
        let dailyComponents = DateComponents(day: 1)
        
        // Create the collection query
        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate),
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: dailyComponents
        )
        
        // Set the results handler
        query.initialResultsHandler = { query, results, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("HealthKitManager: Error getting historical steps: \(error.localizedDescription)")
                    self.lastErrorMessage = error.localizedDescription
                    self.isImportingBulkData = false
                    completion([], error)
                    return
                }
                
                guard let results = results else {
                    print("HealthKitManager: No historical step data found")
                    self.isImportingBulkData = false
                    completion([], nil)
                    return
                }
                
                var stepsByDate: [(Date, Int)] = []
                
                // Calculate total number of days for progress tracking
                let totalDays = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 1
                var processedDays = 0
                
                // Enumerate the statistics objects returned
                results.enumerateStatistics(from: startDate, to: endDate) { statistics, stop in
                    let date = statistics.startDate
                    let steps = statistics.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
                    stepsByDate.append((date, Int(steps)))
                    
                    // Update progress
                    processedDays += 1
                    self.bulkImportProgress = Double(processedDays) / Double(totalDays)
                }
                
                print("HealthKitManager: Successfully imported historical step data for \(stepsByDate.count) days")
                self.isImportingBulkData = false
                completion(stepsByDate, nil)
            }
        }
        
        // Execute the query
        do {
            healthStore.execute(query)
        } catch {
            print("HealthKitManager: Error executing historical query: \(error.localizedDescription)")
            lastErrorMessage = error.localizedDescription
            DispatchQueue.main.async {
                self.isImportingBulkData = false
                completion([], error)
            }
        }
    }
} 