/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A view controller used in developer builds to simulate various app behaviors.
*/

import UIKit
import ExposureNotification

class DeveloperViewController: UITableViewController {
    
    enum Section: Int {
        case general
        case diagnosisKeys
    }
    
    enum GeneralRow: Int {
        case showOnboarding
        case detectExposuresNow
        case simulateExposureDetectionError
        case simulateExposure
        case simulatePositiveDiagnosis
        case disableExposureNotifications
        case resetOnboarded
        case resetExposureDetectionError
        case resetLocalExposures
        case resetLocalTestResults
    }
    
    enum DiagnosisKeysRow: Int {
        case show
        case getAndPost
        case reset
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch Section(rawValue: indexPath.section)! {
        case .general:
            switch GeneralRow(rawValue: indexPath.row)! {
            case .showOnboarding:
                break // handled by segue
                
            case .detectExposuresNow:
                _ = ExposureManager.shared.detectExposures()
                
            case .simulateExposureDetectionError:
                LocalStore.shared.exposureDetectionErrorLocalizedDescription = "Unable to connect to server."
                
            case .simulateExposure:
                let riskLevels: [ENRiskLevel] = [.invalid, .lowest, .low, .lowMedium, .medium, .mediumHigh, .high, .veryHigh, .highest]
                let exposure = Exposure(date: Date() - TimeInterval.random(in: 1...4) * 24 * 60 * 60,
                                        duration: TimeInterval(Int.random(in: 1...5) * 60 * 5),
                                        totalRiskScore: ENRiskScore.random(in: 1...8),
                                        transmissionRiskLevel: riskLevels.randomElement()!.rawValue)
                LocalStore.shared.exposures.append(exposure)
                
            case .simulatePositiveDiagnosis:
                let testResult = TestResult(id: UUID(),
                                            isAdded: true,
                                            dateAdministered: Date() - TimeInterval.random(in: 0...4) * 24 * 60 * 60,
                                            isShared: Bool.random())
                LocalStore.shared.testResults[testResult.id] = testResult
                
            case .disableExposureNotifications:
                ExposureManager.shared.manager.setExposureNotificationEnabled(false) { error in
                    if let error = error {
                        showError(error, from: self)
                    }
                }
                
            case .resetOnboarded:
                LocalStore.shared.isOnboarded = false
                
            case .resetExposureDetectionError:
                LocalStore.shared.exposureDetectionErrorLocalizedDescription = nil
                
            case .resetLocalExposures:
                LocalStore.shared.nextDiagnosisKeyIndex = 0
                LocalStore.shared.exposures = []
                LocalStore.shared.dateLastPerformedExposureDetection = nil
                
            case .resetLocalTestResults:
                LocalStore.shared.testResults = [:]
            }
            
        case .diagnosisKeys:
            switch DiagnosisKeysRow(rawValue: indexPath.row)! {
            case .show:
                break // handled by segue
                
            case .getAndPost:
                ExposureManager.shared.getAndPostDiagnosisKeys { error in
                    if let error = error {
                        showError(error, from: self)
                    }
                }
                
            case .reset:
                Server.shared.diagnosisKeys = []
            }
        }
    }
}
