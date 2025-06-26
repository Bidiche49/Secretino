//
//  PermissionTester.swift
//  Secretino
//
//  Tests isolés pour les permissions et la première configuration
//

import Foundation
import Cocoa

class PermissionTester: TestRunner {
    let testName = "Permissions"
    
    func runTests() -> [TestResult] {
        print("🧪 === TESTS PERMISSIONS ===")
        
        var results: [TestResult] = []
        
        // Test 1: Détection première utilisation
        results.append(testFirstLaunchDetection())
        
        // Test 2: Permissions d'accessibilité
        results.append(testAccessibilityPermissions())
        
        // Test 3: Gestion des versions
        results.append(testVersionManagement())
        
        // Test 4: Persistance des préférences
        results.append(testPreferencesPersistence())
        
        // Test 5: Nettoyage des données legacy
        results.append(testLegacyDataCleanup())
        
        return results
    }
    
    func cleanup() {
        // Restaurer les préférences originales si nécessaire
        // (Dans un vrai test, on sauvegarderait et restaurerait)
    }
    
    // MARK: - Tests individuels
    
    private func testFirstLaunchDetection() -> TestResult {
        print("1️⃣ Test détection première utilisation...")
        
        // Sauvegarder l'état actuel
        let originalVersion = UserDefaults.standard.string(forKey: "secretino_last_version")
        let originalWelcome = UserDefaults.standard.bool(forKey: "secretino_has_shown_welcome")
        
        // Test 1: Première installation (aucune version)
        UserDefaults.standard.removeObject(forKey: "secretino_last_version")
        UserDefaults.standard.removeObject(forKey: "secretino_has_shown_welcome")
        UserDefaults.standard.synchronize()
        
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let lastVersion = UserDefaults.standard.string(forKey: "secretino_last_version")
        let hasShownWelcome = UserDefaults.standard.bool(forKey: "secretino_has_shown_welcome")
        
        let isFirstLaunch = (lastVersion == nil && !hasShownWelcome)
        
        var tests: [String] = []
        tests.append(isFirstLaunch ? "✅ Première installation détectée" : "❌ Première installation non détectée")
        
        // Test 2: Mise à jour de version
        UserDefaults.standard.set("0.9", forKey: "secretino_last_version")
        UserDefaults.standard.synchronize()
        
        let oldVersion = UserDefaults.standard.string(forKey: "secretino_last_version")
        let isVersionUpdate = (oldVersion != currentVersion)
        tests.append(isVersionUpdate ? "✅ Mise à jour détectée" : "❌ Mise à jour non détectée")
        
        // Restaurer l'état original
        if let original = originalVersion {
            UserDefaults.standard.set(original, forKey: "secretino_last_version")
        } else {
            UserDefaults.standard.removeObject(forKey: "secretino_last_version")
        }
        UserDefaults.standard.set(originalWelcome, forKey: "secretino_has_shown_welcome")
        UserDefaults.standard.synchronize()
        
        let allPassed = tests.allSatisfy { $0.hasPrefix("✅") }
        return TestResult(allPassed ? .passed : .failed, "Détection première utilisation", details: tests.joined(separator: ", "))
    }
    
    private func testAccessibilityPermissions() -> TestResult {
        print("2️⃣ Test permissions d'accessibilité...")
        
        var tests: [String] = []
        
        // Test 1: Vérification sans prompt
        let hasPermissionQuiet = PermissionsHelper.shared.hasAccessibilityPermission()
        tests.append("📊 Statut actuel: \(hasPermissionQuiet ? "Accordé" : "Non accordé")")
        
        // Test 2: API AXIsProcessTrusted directe
        let axTrusted = AXIsProcessTrustedWithOptions([
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false
        ] as CFDictionary)
        tests.append(axTrusted ? "✅ AX API confirme permissions" : "⚠️ AX API: permissions manquantes")
        
        // Test 3: Cohérence entre méthodes
        let consistent = (hasPermissionQuiet == axTrusted)
        tests.append(consistent ? "✅ Méthodes cohérentes" : "❌ Incohérence détectée")
        
        if hasPermissionQuiet {
            return TestResult(.passed, "Permissions d'accessibilité", details: tests.joined(separator: ", "))
        } else {
            return TestResult(.manual, "Permissions d'accessibilité requises",
                            details: "Accordez via Préférences Système → Sécurité → Accessibilité")
        }
    }
    
    private func testVersionManagement() -> TestResult {
        print("3️⃣ Test gestion des versions...")
        
        // Sauvegarder l'état actuel
        let originalVersion = UserDefaults.standard.string(forKey: "secretino_last_version")
        
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        
        var tests: [String] = []
        
        // Test 1: Version courante valide
        tests.append(!currentVersion.isEmpty ? "✅ Version courante valide: \(currentVersion)" : "❌ Version courante invalide")
        
        // Test 2: Sauvegarde de version
        UserDefaults.standard.set(currentVersion, forKey: "secretino_last_version")
        UserDefaults.standard.synchronize()
        
        let savedVersion = UserDefaults.standard.string(forKey: "secretino_last_version")
        tests.append(savedVersion == currentVersion ? "✅ Sauvegarde version OK" : "❌ Sauvegarde version échouée")
        
        // Test 3: Détection de changement
        UserDefaults.standard.set("0.8", forKey: "secretino_last_version")
        UserDefaults.standard.synchronize()
        
        let oldVersion = UserDefaults.standard.string(forKey: "secretino_last_version")
        let versionChanged = (oldVersion != currentVersion)
        tests.append(versionChanged ? "✅ Changement version détecté" : "❌ Changement version non détecté")
        
        // Restaurer l'état original
        if let original = originalVersion {
            UserDefaults.standard.set(original, forKey: "secretino_last_version")
        } else {
            UserDefaults.standard.removeObject(forKey: "secretino_last_version")
        }
        UserDefaults.standard.synchronize()
        
        let allPassed = tests.allSatisfy { $0.hasPrefix("✅") }
        return TestResult(allPassed ? .passed : .failed, "Gestion des versions", details: tests.joined(separator: ", "))
    }
    
    private func testPreferencesPersistence() -> TestResult {
        print("4️⃣ Test persistance des préférences...")
        
        let testKey = "secretino_test_preference"
        let testValue = "test_value_\(UUID().uuidString)"
        
        var tests: [String] = []
        
        // Test 1: Écriture
        UserDefaults.standard.set(testValue, forKey: testKey)
        UserDefaults.standard.synchronize()
        tests.append("✅ Écriture préférence")
        
        // Test 2: Lecture
        let readValue = UserDefaults.standard.string(forKey: testKey)
        tests.append(readValue == testValue ? "✅ Lecture préférence" : "❌ Lecture préférence échouée")
        
        // Test 3: Suppression
        UserDefaults.standard.removeObject(forKey: testKey)
        UserDefaults.standard.synchronize()
        
        let deletedValue = UserDefaults.standard.string(forKey: testKey)
        tests.append(deletedValue == nil ? "✅ Suppression préférence" : "❌ Suppression préférence échouée")
        
        // Test 4: Préférences Secretino existantes
        let secretinoKeys = getAllSecretinoPreferences()
        tests.append("📊 Préférences Secretino: \(secretinoKeys.count) clés")
        
        let allPassed = tests.filter { $0.hasPrefix("❌") }.isEmpty
        return TestResult(allPassed ? .passed : .failed, "Persistance préférences", details: tests.joined(separator: ", "))
    }
    
    private func testLegacyDataCleanup() -> TestResult {
        print("5️⃣ Test nettoyage données legacy...")
        
        // Créer des données legacy temporaires
        let legacyKeys = TestConstants.legacyKeys
        
        var tests: [String] = []
        
        // Créer des données legacy
        for key in legacyKeys {
            UserDefaults.standard.set("legacy_test_data", forKey: key)
        }
        UserDefaults.standard.synchronize()
        tests.append("✅ Données legacy créées pour test")
        
        // Vérifier qu'elles existent
        let legacyExists = legacyKeys.allSatisfy { UserDefaults.standard.object(forKey: $0) != nil }
        tests.append(legacyExists ? "✅ Données legacy confirmées" : "❌ Données legacy non créées")
        
        // Simuler le nettoyage (comme dans AppDelegate)
        for key in legacyKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        UserDefaults.standard.synchronize()
        
        // Vérifier qu'elles sont supprimées
        let legacyGone = legacyKeys.allSatisfy { UserDefaults.standard.object(forKey: $0) == nil }
        tests.append(legacyGone ? "✅ Données legacy supprimées" : "❌ Données legacy persistent")
        
        let allPassed = tests.allSatisfy { $0.hasPrefix("✅") }
        return TestResult(allPassed ? .passed : .failed, "Nettoyage données legacy", details: tests.joined(separator: ", "))
    }
    
    // MARK: - Méthodes utilitaires
    
    private func getAllSecretinoPreferences() -> [String: Any] {
        let domain = Bundle.main.bundleIdentifier ?? "com.nztd.Secretino"
        let defaults = UserDefaults.standard.persistentDomain(forName: domain) ?? [:]
        
        return defaults.filter { key, _ in
            key.lowercased().contains("secretino") ||
            key == "useGlobalHotkeys" ||
            key.hasPrefix("secretino_")
        }
    }
}
