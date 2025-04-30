//
//  Know_your_macrosApp.swift
//  Know your macros
//
//  Created by Jonathan Strømsted on 29/04/2025.
//

import SwiftUI
import HealthKit

// Ensure these keys are added to Info.plist when the app is built
// These lines aren't code but act as annotations to inform the build system
// NSHealthShareUsageDescription: This app needs access to your step count data to automatically track your daily activity.
// NSHealthUpdateUsageDescription: This app needs permission to read your step count from Apple Health.

@main
struct Know_your_macrosApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }
}
