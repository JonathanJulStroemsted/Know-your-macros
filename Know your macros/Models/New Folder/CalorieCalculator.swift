import Foundation

struct CalorieCalculator {
    static func calculateBMR(weightKg: Double, heightCm: Double, age: Int, isMale: Bool) -> Double {
        if isMale {
            return 10 * weightKg + 6.25 * heightCm - 5 * Double(age) + 5
        } else {
            return 10 * weightKg + 6.25 * heightCm - 5 * Double(age) - 161
        }
    }
    
    static func calculateTDEE(bmr: Double, activityLevel: ActivityLevel) -> Double {
        return bmr * activityLevel.multiplier
    }
    
    static func dailyCalories(tdee: Double, goal: Goal) -> Double {
        switch goal {
        case .maintain:
            return tdee
        case .gain:
            return tdee + 300
        case .lose:
            return tdee - 300
        }
    }

    
    enum ActivityLevel: CaseIterable {
        case sedentary, lightlyActive, moderatelyActive, veryActive, superActive
        
        var multiplier: Double {
            switch self {
            case .sedentary: return 1.2
            case .lightlyActive: return 1.375
            case .moderatelyActive: return 1.55
            case .veryActive: return 1.725
            case .superActive: return 1.9
            }
        }
        
        var displayName: String {
            switch self {
            case .sedentary:
                return "Sedentary (Office job, <5k steps/day, no exercise)"
            case .lightlyActive:
                return "Light Activity (Office job, 5-8k steps/day, 1-2 light workouts/week)"
            case .moderatelyActive:
                return "Moderate Activity (8-10k steps/day, 3-4 medium workouts/week)"
            case .veryActive:
                return "Very Active (Active job OR 10k+ steps/day with 4-5 intense workouts/week)"
            case .superActive:
                return "Super Active (Physical job + regular intense exercise, athlete training)"
            }
        }
    }
    
    enum Goal: CaseIterable {
        case maintain, gain, lose
        
        var displayName: String {
            switch self {
            case .maintain: return "Maintain Weight"
            case .gain: return "Gain Weight"
            case .lose: return "Lose Weight"
            }
        }
    }
} 
