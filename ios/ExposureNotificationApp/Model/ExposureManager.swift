/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A class that manages a singleton ENManager object.
*/

import Foundation
import ExposureNotification

class ExposureManager {
    
    static let shared = ExposureManager()
    
    let manager = ENManager()
    
    init() {
        manager.activate { _ in
            // Ensure exposure notifications are enabled if the app is authorized. The app
            // could get into a state where it is authorized, but exposure
            // notifications are not enabled,  if the user initially denied Exposure Notifications
            // during onboarding, but then flipped on the "COVID-19 Exposure Notifications" switch
            // in Settings.
            if ENManager.authorizationStatus == .authorized && !self.manager.exposureNotificationEnabled {
                self.manager.setExposureNotificationEnabled(true) { _ in
                    // No error handling for attempts to enable on launch
                }
            }
        }
    }
    
    deinit {
        manager.invalidate()
    }
    
    static let authorizationStatusChangeNotification = Notification.Name("ExposureManagerAuthorizationStatusChangedNotification")
    
    var detectingExposures = false
    
    func detectExposures(completionHandler: ((Bool) -> Void)? = nil) -> Progress {
        
        let progress = Progress()
        
        // Disallow concurrent exposure detection, because if allowed we might try to detect the same diagnosis keys more than once
        guard !detectingExposures else {
            completionHandler?(false)
            return progress
        }
        detectingExposures = true
        
        let session = ENExposureDetectionSession()
        let batchSize = session.maximumKeyCount

        var newExposures = [Exposure]()
        
        // Keep track of how many total diagnosis keys we have processed, to ensure
        // we never run detection on a diagnosis key more than once on this device
        var nextDiagnosisKeyIndex = LocalStore.shared.nextDiagnosisKeyIndex
        
        func finish(_ error: Error?) {
            session.invalidate()
            if !progress.isCancelled {
                if let error = error {
                    LocalStore.shared.exposureDetectionErrorLocalizedDescription = error.localizedDescription
                    // Consider posting a user notification that an error occured
                } else {
                    LocalStore.shared.nextDiagnosisKeyIndex = nextDiagnosisKeyIndex
                    LocalStore.shared.exposures.append(contentsOf: newExposures)
                    LocalStore.shared.exposures.sort { $0.date < $1.date }
                    LocalStore.shared.dateLastPerformedExposureDetection = Date()
                    LocalStore.shared.exposureDetectionErrorLocalizedDescription = nil
                }
            }
            detectingExposures = false
            completionHandler?(error != nil)
        }
        func getAllExposures() {
            session.getExposureInfo(withMaximumCount: 100) { newExposuresBatch, done, error in
                if let error = error {
                    finish(error)
                    return
                }
                newExposures.append(contentsOf: newExposuresBatch!.lazy.map { exposure in
                    return Exposure(date: exposure.date,
                                    duration: exposure.duration,
                                    totalRiskScore: exposure.totalRiskScore,
                                    transmissionRiskLevel: exposure.transmissionRiskLevel.rawValue)
                })
                if done {
                    finish(nil)
                } else {
                    getAllExposures()
                }
            }
        }
        
        /// Get diagnosis keys from server and processes them locally in parallel.
        ///
        /// This diagram shows the sequence of calls, where calls on the second line happen in parallel with the calls above them.
        /// Server requests and local processing are rate limited by the slower task.
        /// ```
        ///       | add..... | add.....       | add.... | finishedPositive
        /// get.. | get...   | get........... |
        /// ```
        /// `checkExposure` calls itself recursively until finished. For the above pattern of events, the calls to `checkExposure` would be:
        /// ```
        /// checkExposure(index: 0, diagnosisKeys: nil, done: false) // Kick off the first batch
        /// checkExposure(index: batchSize, diagnosisKeys: [firstBatch], done: false)
        /// checkExposure(index: 2 * batchSize, diagnosisKeys: [secondBatch], done: false)
        /// checkExposure(index: 3 * batchSize, diagnosisKeys: [thirdBatch], done: true)
        /// ```
        /// - Parameter index: The first index of the next batch of keys to fetch from the server.
        /// - Parameter diagnosisKeys: The keys from the last server call to `getDiagnosisKeysResult`.
        /// - Parameter done: Whether the last server call to `getDiagnosisKeysResult` retreived the final batch of keys.
        func checkExposure(index: Int, diagnosisKeys: [ENTemporaryExposureKey]?, done: Bool) {
            
            let dispatchGroup = DispatchGroup()
            
            var addPositiveDiagnosisKeysError: Error?
            if let diagnosisKeys = diagnosisKeys {
                dispatchGroup.enter()
                session.addDiagnosisKeys(diagnosisKeys) { error in
                    addPositiveDiagnosisKeysError = error
                    dispatchGroup.leave()
                }
            }
            
            var getDiagnosisKeysResult: Result<(diagnosisKeys: [ENTemporaryExposureKey], done: Bool), Error>?
            if !done {
                dispatchGroup.enter()
                Server.shared.getDiagnosisKeys(index: index, maximumCount: batchSize) { result in
                    getDiagnosisKeysResult = result
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                
                if let addPositiveDiagnosisKeysError = addPositiveDiagnosisKeysError {
                    finish(addPositiveDiagnosisKeysError)
                    return
                }
                
                if let getDiagnosisKeysResult = getDiagnosisKeysResult {
                    switch getDiagnosisKeysResult {
                    case let .success((diagnosisKeys, done)):
                        nextDiagnosisKeyIndex += diagnosisKeys.count
                        checkExposure(index: index + batchSize, diagnosisKeys: diagnosisKeys, done: done)
                    case let .failure(error):
                        finish(error)
                    }
                } else {
                    // If there is no getDiagnosisKeysResult, we're done!
                    session.finishedDiagnosisKeys { summary, error in
                        if let error = error {
                            finish(error)
                            return
                        }
                        getAllExposures()
                    }
                }
            }
        }

        Server.shared.getExposureConfiguration { result in
            switch result {
            case let .success(configuration):
                session.configuration = configuration
                session.activate { error in
                    if let error = error {
                        finish(error)
                        return
                    }
                    checkExposure(index: nextDiagnosisKeyIndex, diagnosisKeys: nil, done: false)
                }
            case let .failure(error):
                finish(error)
            }
        }
        
        return progress
    }
    
    func getAndPostDiagnosisKeys(completion: @escaping (Error?) -> Void) {
        manager.getDiagnosisKeys { temporaryExposureKeys, error in
            if let error = error {
                completion(error)
            } else {
                Server.shared.postDiagnosisKeys(temporaryExposureKeys ?? []) { error in
                    completion(error)
                }
            }
        }
    }
}
