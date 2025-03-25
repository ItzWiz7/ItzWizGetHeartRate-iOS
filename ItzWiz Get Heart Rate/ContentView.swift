//
//  ContentView.swift
//  ItzWiz Get Heart Rate
//
//  Created by Admin on 2/27/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var connectivityManager = iOSConnectivityManager()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Live Heart Rate from Watch:")
                .font(.headline)
            
            if connectivityManager.lastUpdate != nil {
                Text(String(format: "%.0f BPM", connectivityManager.heartRate))
                    .font(.largeTitle)
                    .foregroundColor(.red)
            } else {
                Text("No Data")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
            }
            
            // Show the measured interval between the last two updates:
            Text("Interval between updates: \(Int(connectivityManager.updateInterval))s")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            // Horizontal layout for Min, Average, and Max
            HStack {
                // Min Column
                VStack(spacing: 4) {
                    Text("Min")
                        .font(.subheadline)
                    if let minHR = connectivityManager.minHeartRate {
                        Text(String(format: "%.0f BPM", minHR))
                            .font(.headline)
                            .foregroundColor(.red)
                    } else {
                        Text("--")
                            .font(.headline)
                    }
                    if let minTime = connectivityManager.minHeartRateTimestamp {
                        Text(formattedDate(minTime))
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else {
                        Text("")
                            .font(.caption)
                    }
                }
                
                Spacer()
                
                // Average Column
                VStack(spacing: 4) {
                    Text("Average")
                        .font(.subheadline)
                    Text(String(format: "%.0f BPM", connectivityManager.averageHeartRate))
                        .font(.headline)
                        .foregroundColor(.red)
                    // No timestamp for average
                }
                
                Spacer()
                
                // Max Column
                VStack(spacing: 4) {
                    Text("Max")
                        .font(.subheadline)
                    if let maxHR = connectivityManager.maxHeartRate {
                        Text(String(format: "%.0f BPM", maxHR))
                            .font(.headline)
                            .foregroundColor(.red)
                    } else {
                        Text("--")
                            .font(.headline)
                    }
                    if let maxTime = connectivityManager.maxHeartRateTimestamp {
                        Text(formattedDate(maxTime))
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else {
                        Text("")
                            .font(.caption)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
