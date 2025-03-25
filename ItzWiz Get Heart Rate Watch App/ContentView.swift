//
//  ContentView.swift
//  ItzWiz Get Heart Rate Watch App
//
//  Created by Admin on 2/27/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var workoutManager = WorkoutManager()
    @State private var currentDate: Date = Date()
    
    var body: some View {
        VStack(spacing: 20) {
            // Display current heart rate (or "DeD" if no update in the last 10 seconds)
            VStack(spacing: 8) {
                Text("Heart Rate")
                    .font(.headline)
                Text(displayHeartRate)
                    .font(.largeTitle)
                    .foregroundColor(.red)
            }
            
            // Toggle button for workout session
            Button(action: {
                if workoutManager.isWorkoutActive {
                    workoutManager.endWorkout()
                } else {
                    workoutManager.startWorkout()
                }
            }) {
                Text(workoutManager.isWorkoutActive ? "End Workout" : "Start Workout")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        // Timer to refresh view for any time-based UI (if needed)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now in
            currentDate = now
        }
    }
    
    var displayHeartRate: String {
        if let last = workoutManager.lastUpdate, Date().timeIntervalSince(last) < 10 {
            return String(format: "%.0f BPM", workoutManager.heartRate)
        } else {
            return "DeD"
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
