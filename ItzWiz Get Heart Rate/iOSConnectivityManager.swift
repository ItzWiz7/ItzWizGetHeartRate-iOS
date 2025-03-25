//
//  ItzWiz_Get_Heart_RateApp.swift
//  ItzWiz Get Heart Rate
//
//  Created by Admin on 2/27/25.
//

import WatchConnectivity
import SwiftUI

class iOSConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var heartRate: Double = 0.0
    @Published var lastUpdate: Date? = nil
    @Published var updateInterval: TimeInterval = 0  // (Not shown in UI now)
    
    // New properties for stats
    @Published var minHeartRate: Double? = nil
    @Published var minHeartRateTimestamp: Date? = nil
    @Published var maxHeartRate: Double? = nil
    @Published var maxHeartRateTimestamp: Date? = nil
    @Published var averageHeartRate: Double = 0.0
    
    private var heartRateSum: Double = 0.0
    private var heartRateCount: Int = 0

    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let hr = message["heartRate"] as? Double {
            DispatchQueue.main.async {
                let now = Date()
                // Update interval (if needed)
                if let previous = self.lastUpdate {
                    self.updateInterval = now.timeIntervalSince(previous)
                } else {
                    self.updateInterval = 0
                }
                self.lastUpdate = now
                self.heartRate = hr
                
                // Update min value and timestamp
                if let currentMin = self.minHeartRate {
                    if hr < currentMin {
                        self.minHeartRate = hr
                        self.minHeartRateTimestamp = now
                    }
                } else {
                    self.minHeartRate = hr
                    self.minHeartRateTimestamp = now
                }
                
                // Update max value and timestamp
                if let currentMax = self.maxHeartRate {
                    if hr > currentMax {
                        self.maxHeartRate = hr
                        self.maxHeartRateTimestamp = now
                    }
                } else {
                    self.maxHeartRate = hr
                    self.maxHeartRateTimestamp = now
                }
                
                // Update average stats
                self.heartRateSum += hr
                self.heartRateCount += 1
                self.averageHeartRate = self.heartRateSum / Double(self.heartRateCount)
            }
            print("Received heart rate from watch: \(hr) BPM")
        }
    }
    
    // Required WCSession delegate stubs:
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // Handle activation if needed.
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) { }
    
    func sessionDidDeactivate(_ session: WCSession) { }
}
