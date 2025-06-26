//
//  TestCommon.swift
//  Secretino
//
//  Types et structures communes pour tous les tests
//

import Foundation
import Cocoa

// MARK: - Énumérations et structures de test

enum TestStatus {
    case passed
    case failed
    case skipped
    case manual
    case warning
}

struct TestResult {
    let status: TestStatus
    let message: String
    let details: String?
    let timestamp: Date
    
    init(_ status: TestStatus, _ message: String, details: String? = nil) {
        self.status = status
        self.message = message
        self.details = details
        self.timestamp = Date()
    }
}

struct TestSuite {
    let name: String
    let results: [TestResult]
    let startTime: Date
    let endTime: Date
    
    var duration: TimeInterval {
        return endTime.timeIntervalSince(startTime)
    }
    
    var passedCount: Int {
        return results.filter { $0.status == .passed }.count
    }
    
    var failedCount: Int {
        return results.filter { $0.status == .failed }.count
    }
    
    var skippedCount: Int {
        return results.filter { $0.status == .skipped }.count
    }
    
    var successRate: Double {
        guard !results.isEmpty else { return 0.0 }
        return Double(passedCount) / Double(results.count) * 100.0
    }
}

// MARK: - Protocole pour les testeurs

protocol TestRunner {
    var testName: String { get }
    func runTests() -> [TestResult]
    func cleanup()
}

// MARK: - Utilitaires de test

class TestUtils {
    
    /// Affiche un résultat de test formaté
    static func printTestResult(_ result: TestResult, indent: String = "   ") {
        let statusIcon = getStatusIcon(result.status)
        let timestamp = DateFormatter.timeFormatter.string(from: result.timestamp)
        
        print("\(indent)\(statusIcon) \(result.message) [\(timestamp)]")
        
        if let details = result.details {
            print("\(indent)   Details: \(details)")
        }
    }
    
    /// Affiche un résumé de suite de tests
    static func printTestSuite(_ suite: TestSuite) {
        print("\n📊 === RÉSUMÉ \(suite.name.uppercased()) ===")
        print("   Durée: \(String(format: "%.2f", suite.duration))s")
        print("   Total: \(suite.results.count)")
        print("   Réussis: \(suite.passedCount) (\(String(format: "%.1f", suite.successRate))%)")
        print("   Échecs: \(suite.failedCount)")
        print("   Ignorés: \(suite.skippedCount)")
        
        if suite.failedCount == 0 {
            print("   🎉 TOUS LES TESTS SONT PASSÉS!")
        } else {
            print("   ⚠️ Des tests ont échoué")
        }
        print("========================================\n")
    }
    
    /// Retourne l'icône pour un statut
    private static func getStatusIcon(_ status: TestStatus) -> String {
        switch status {
        case .passed: return "✅"
        case .failed: return "❌"
        case .skipped: return "⏭️"
        case .manual: return "👤"
        case .warning: return "⚠️"
        }
    }
    
    /// Mesure le temps d'exécution d'une fonction
    static func measureTime<T>(_ block: () throws -> T) rethrows -> (result: T, duration: TimeInterval) {
        let start = Date()
        let result = try block()
        let duration = Date().timeIntervalSince(start)
        return (result, duration)
    }
    
    /// Attend avec timeout pour une condition
    static func waitForCondition(
        timeout: TimeInterval = 5.0,
        interval: TimeInterval = 0.1,
        condition: () -> Bool
    ) -> Bool {
        let endTime = Date().addingTimeInterval(timeout)
        
        while Date() < endTime {
            if condition() {
                return true
            }
            Thread.sleep(forTimeInterval: interval)
        }
        
        return false
    }
    
    /// Crée une alerte de test (non-bloquante)
    static func showTestAlert(title: String, message: String, completion: @escaping () -> Void = {}) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            
            alert.beginSheetModal(for: NSApp.mainWindow ?? NSApp.windows.first ?? NSWindow()) { _ in
                completion()
            }
        }
    }
}

// MARK: - Extensions utiles

extension DateFormatter {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
    
    static let fullFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}

extension String {
    /// Tronque une chaîne pour l'affichage
    func truncated(to length: Int) -> String {
        if self.count <= length {
            return self
        } else {
            return String(self.prefix(length)) + "..."
        }
    }
}

// MARK: - Constantes de test

enum TestConstants {
    static let defaultTimeout: TimeInterval = 5.0
    static let testPassphrase = "TestPassphrase123!"
    static let testText = "Ceci est un message de test pour Secretino"
    static let legacyKeys = [
        "secretino_temp_passphrase",
        "secretino_has_passphrase"
    ]
}
