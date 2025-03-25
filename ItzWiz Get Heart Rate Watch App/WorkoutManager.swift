//
//  ItzWiz_Get_Heart_RateApp.swift
//  ItzWiz Get Heart Rate Watch App
//
//  Created by Admin on 2/27/25.
//

import HealthKit
import WatchConnectivity
import SwiftUI

class WorkoutManager: NSObject, ObservableObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate, WCSessionDelegate {
    let healthStore = HKHealthStore()
    @Published var heartRate: Double = 0.0
    @Published var lastUpdate: Date? = nil  // Tracks when the last heart rate reading was received
    @Published var isWorkoutActive: Bool = false  // New property to track workout state

    var workoutSession: HKWorkoutSession?
    var workoutBuilder: HKLiveWorkoutBuilder?
    var anchoredQuery: HKAnchoredObjectQuery?
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
        requestAuthorization { success in
            if success {
                print("HealthKit authorization granted.")
                // Always start the anchored query to pull the latest heart rate regardless of mode.
                self.startAnchoredQuery()
            } else {
                print("HealthKit authorization denied.")
            }
        }
    }
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable(),
              let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            completion(false)
            return
        }
        let workoutType = HKObjectType.workoutType()
        let typesToShare: Set<HKSampleType> = [workoutType]
        let typesToRead: Set<HKObjectType> = [heartRateType]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }
    
    // MARK: - Anchored Query (for non-workout mode)
    
    func startAnchoredQuery() {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        anchoredQuery = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { query, samples, deletedObjects, newAnchor, error in
            self.processSamples(samples)
        }
        anchoredQuery?.updateHandler = { query, samples, deletedObjects, newAnchor, error in
            self.processSamples(samples)
        }
        if let query = anchoredQuery {
            healthStore.execute(query)
        }
    }
    
    private func processSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample] else { return }
        if let latestSample = samples.last {
            let unit = HKUnit.count().unitDivided(by: HKUnit.minute())
            let value = latestSample.quantity.doubleValue(for: unit)
            DispatchQueue.main.async {
                self.heartRate = value
                self.lastUpdate = Date()
            }
            print("Anchored query update: \(value) BPM")
            
            // Send update to iOS even in non-workout mode
            if WCSession.default.isReachable {
                let message = ["heartRate": value]
                WCSession.default.sendMessage(message, replyHandler: nil) { error in
                    print("Error sending anchored heart rate: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Workout Session Methods (for live updates)
    
    func startWorkout() {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .other
        configuration.locationType = .indoor
        
        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()
            
            workoutSession?.delegate = self
            workoutBuilder?.delegate = self
            
            workoutBuilder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore,
                                                                 workoutConfiguration: configuration)
            
            let startDate = Date()
            workoutSession?.startActivity(with: startDate)
            workoutBuilder?.beginCollection(withStart: startDate) { success, error in
                if success {
                    print("Workout started and collecting live data.")
                    DispatchQueue.main.async {
                        self.isWorkoutActive = true
                    }
                } else {
                    print("Error starting live collection: \(error?.localizedDescription ?? "unknown error")")
                }
            }
        } catch {
            print("Error starting workout: \(error.localizedDescription)")
        }
    }
    
    func endWorkout() {
        let endDate = Date()
        workoutSession?.end()
        workoutBuilder?.endCollection(withEnd: endDate) { success, error in
            if success {
                print("Workout ended.")
                DispatchQueue.main.async {
                    self.isWorkoutActive = false
                }
            } else {
                print("Error ending workout: \(error?.localizedDescription ?? "unknown error")")
            }
        }
    }
    
    // MARK: - HKWorkoutSessionDelegate Methods
    
    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState,
                        date: Date) {
        print("Workout session state changed from \(fromState.rawValue) to \(toState.rawValue) at \(date)")
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout session error: \(error.localizedDescription)")
    }
    
    // MARK: - HKLiveWorkoutBuilderDelegate Methods
    
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf types: Set<HKSampleType>) {
        for type in types {
            if let quantityType = type as? HKQuantityType,
               quantityType == HKObjectType.quantityType(forIdentifier: .heartRate) {
                if let statistics = workoutBuilder.statistics(for: quantityType) {
                    let unit = HKUnit.count().unitDivided(by: HKUnit.minute())
                    if let latestQuantity = statistics.mostRecentQuantity() {
                        let value = latestQuantity.doubleValue(for: unit)
                        DispatchQueue.main.async {
                            self.heartRate = value
                            self.lastUpdate = Date()
                        }
                        print("Live workout update: \(value) BPM")
                        
                        // Send live workout update to your API
                        self.sendHeartRateToAPI(value)
                        
                        // Forward via WatchConnectivity to the iOS app
                        if WCSession.default.isReachable {
                            let message = ["heartRate": value]
                            WCSession.default.sendMessage(message, replyHandler: nil) { error in
                                print("Error sending live heart rate: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            }
        }
    }
    
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        print("Live workout builder collected an event.")
    }
    
    // MARK: - API Communication
    
    private func sendHeartRateToAPI(_ heartRate: Double) {
        guard let url = URL(string: "http://192.168.1.251:5000/api/heart-rate") else {
            print("Invalid API URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "heartRate": heartRate,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
            request.httpBody = jsonData
        } catch {
            print("Error serializing JSON: \(error.localizedDescription)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error sending heart rate: \(error.localizedDescription)")
            } else if let response = response as? HTTPURLResponse {
                print("API response code: \(response.statusCode)")
            }
        }.resume()
    }
    
    // MARK: - WCSessionDelegate Methods
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation failed: \(error.localizedDescription)")
        } else {
            print("WCSession activated: \(activationState.rawValue)")
        }
    }
    
    // Additional WCSession delegate methods can be implemented as needed.
}
