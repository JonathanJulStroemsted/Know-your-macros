import SwiftUI

struct MainView: View {
    @StateObject private var profileManager = ProfileManager()
    @StateObject private var dailyTracker = DailyTracker()
    @State private var showingAddProfile = false
    
    var body: some View {
        NavigationView {
            VStack {
                if profileManager.profiles.isEmpty {
                    ContentUnavailableView(
                        "No Profiles",
                        systemImage: "person.crop.circle.badge.plus",
                        description: Text("Add a profile to get started")
                    )
                    .padding()
                    
                    Button("Add Profile") {
                        showingAddProfile = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(.blue)
                } else {
                    List {
                        ForEach(profileManager.profiles) { profile in
                            NavigationLink(destination: CalorieCalculatorView(profile: profile, profileManager: profileManager, dailyTracker: dailyTracker)) {
                                HStack {
                                    Image(systemName: "person.circle")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                    
                                    VStack(alignment: .leading) {
                                        Text(profile.name)
                                            .font(.headline)
                                        
                                        HStack {
                                            Text("\(Int(profile.age)) years")
                                            Text("•")
                                            Text("\(Int(profile.weight)) kg")
                                            Text("•")
                                            Text("\(Int(profile.height)) cm")
                                        }
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete { indexSet in
                            profileManager.deleteProfile(at: indexSet)
                        }
                    }
                }
            }
            .navigationTitle("Know Your Macros")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddProfile = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddProfile) {
                ProfileEditorView(profileManager: profileManager)
            }
        }
    }
} 