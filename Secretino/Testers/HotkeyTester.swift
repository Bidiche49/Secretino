//
//  HotkeyTester.swift
//  Secretino
//
//  Tests isolés pour les raccourcis globaux
//

import Foundation
import Cocoa
import Carbon

class HotkeyTester: TestRunner {
    let testName = "Raccourcis Globaux"
    
    func runTests() -> [TestResult] {
        print("🧪 === TESTS RACCOURCIS GLOBAUX ===")
        
        var results: [TestResult] = []
        
        // Test 1: Prérequis système
        results.append(testSystemRequirements())
        
        // Test 2: API Carbon disponible
        results.append(testCarbonAPI())
        
        // Test 3: Permissions d'accessibilité
        results.append(testAccessibilityPermissions())
        
        // Test 4: Configuration du gestionnaire
        results.append(testHotkeyManagerSetup())
        
        // Test 5: Enregistrement des raccourcis
        results.append(testHotkeyRegistration())
        
        // Test 6: Simulation d'événements
        results.append(testEventSimulation())
        
        // Test 7: Nettoyage
        results.append(testCleanup())
        
        return results
    }
    
    func cleanup() {
        // Nettoyer les raccourcis de test
        GlobalHotkeyManager.shared.disableHotkeys()
    }
    
    // MARK: - Tests individuels
    
    private func testSystemRequirements() -> TestResult {
        print("1️⃣ Test prérequis système...")
        
        var requirements: [String] = []
        
        // Vérifier macOS
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        if osVersion.majorVersion >= 10 && osVersion.minorVersion >= 15 {
            requirements.append("✅ macOS compatible")
        } else {
            requirements.append("❌ macOS trop ancien")
        }
        
        // Vérifier Carbon framework
        let carbonAvailable = true // Carbon est toujours disponible sur macOS
        requirements.append(carbonAvailable ? "✅ Carbon disponible" : "❌ Carbon manquant")
        
        // Vérifier mode app
        let isAgent = NSApp.activationPolicy() == .accessory
        requirements.append(isAgent ? "✅ Mode agent (LSUIElement)" : "⚠️ Mode application normale")
        
        let allPassed = requirements.allSatisfy { $0.hasPrefix("✅") }
        let status: TestStatus = allPassed ? .passed : (requirements.contains { $0.hasPrefix("❌") } ? .failed : .warning)
        
        return TestResult(status, "Prérequis système", details: requirements.joined(separator: ", "))
    }
    
    private func testCarbonAPI() -> TestResult {
        print("2️⃣ Test API Carbon...")
        
        var tests: [String] = []
        
        // Test 1: Installation gestionnaire d'événements
        var eventHandler: EventHandlerRef?
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )
        
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, _, _) -> OSStatus in return OSStatus(noErr) },
            1,
            &eventType,
            nil,
            &eventHandler
        )
        
        if handlerStatus == noErr {
            tests.append("✅ Installation gestionnaire")
            if let handler = eventHandler {
                RemoveEventHandler(handler)
                tests.append("✅ Suppression gestionnaire")
            }
        } else {
            tests.append("❌ Installation gestionnaire: \(handlerStatus)")
        }
        
        // Test 2: Enregistrement raccourci temporaire
        var hotkeyRef: EventHotKeyRef?
        let hotkeyID = EventHotKeyID(signature: fourCharCode("TEST"), id: 999)
        
        let hotkeyStatus = RegisterEventHotKey(
            UInt32(kVK_F19), // Touche peu utilisée
            0, // Pas de modificateurs
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )
        
        if hotkeyStatus == noErr {
            tests.append("✅ Enregistrement raccourci")
            if let hotkey = hotkeyRef {
                UnregisterEventHotKey(hotkey)
                tests.append("✅ Désenregistrement raccourci")
            }
        } else {
            tests.append("❌ Enregistrement raccourci: \(hotkeyStatus)")
        }
        
        let allPassed = tests.allSatisfy { $0.hasPrefix("✅") }
        return TestResult(allPassed ? .passed : .failed, "API Carbon", details: tests.joined(separator: ", "))
    }
    
    private func testAccessibilityPermissions() -> TestResult {
        print("3️⃣ Test permissions d'accessibilité...")
        
        let hasPermission = PermissionsHelper.shared.hasAccessibilityPermission()
        
        if hasPermission {
            return TestResult(.passed, "Permissions d'accessibilité accordées")
        } else {
            return TestResult(.manual, "Permissions d'accessibilité requises",
                            details: "Accordez les permissions via Préférences Système → Sécurité → Accessibilité")
        }
    }
    
    private func testHotkeyManagerSetup() -> TestResult {
        print("4️⃣ Test configuration gestionnaire...")
        
        let manager = GlobalHotkeyManager.shared
        
        // Vérifier l'état initial
        var checks: [String] = []
        
        // Vérifier si une passphrase est configurée
        let hasPassphrase = manager.hasConfiguredPassphrase
        checks.append(hasPassphrase ? "✅ Passphrase configurée" : "⚠️ Passphrase manquante")
        
        // Vérifier les permissions
        let hasPermissions = PermissionsHelper.shared.hasAccessibilityPermission()
        checks.append(hasPermissions ? "✅ Permissions OK" : "⚠️ Permissions manquantes")
        
        // Vérifier la capacité d'activation
        let canEnable = manager.canEnable
        checks.append(canEnable ? "✅ Peut activer" : "⚠️ Ne peut pas activer")
        
        let allReady = hasPassphrase && hasPermissions && canEnable
        let status: TestStatus = allReady ? .passed : .manual
        
        return TestResult(status, "Configuration gestionnaire", details: checks.joined(separator: ", "))
    }
    
    private func testHotkeyRegistration() -> TestResult {
        print("5️⃣ Test enregistrement raccourcis...")
        
        let manager = GlobalHotkeyManager.shared
        
        // Sauvegarder l'état initial
        let wasEnabled = manager.isEnabled
        
        // Si pas de prérequis, retourner manuel
        if !manager.canEnable {
            return TestResult(.manual, "Prérequis manquants pour test enregistrement")
        }
        
        // Désactiver d'abord
        manager.disableHotkeys()
        
        // Attendre un peu
        Thread.sleep(forTimeInterval: 0.5)
        
        // Tenter d'activer
        manager.setupHotkeys()
        
        // Attendre que l'activation se fasse
        let activated = TestUtils.waitForCondition(timeout: 3.0) {
            return manager.isEnabled
        }
        
        let result: TestResult
        if activated {
            result = TestResult(.passed, "Raccourcis enregistrés avec succès")
        } else {
            result = TestResult(.failed, "Échec enregistrement raccourcis")
        }
        
        // Restaurer l'état initial
        if !wasEnabled {
            manager.disableHotkeys()
        }
        
        return result
    }
    
    private func testEventSimulation() -> TestResult {
        print("6️⃣ Test simulation d'événements...")
        
        var tests: [String] = []
        
        // Test simulation copier (Cmd+C)
        let copyResult = simulateKeyPress(keyCode: CGKeyCode(kVK_ANSI_C), flags: .maskCommand)
        tests.append(copyResult ? "✅ Simulation Cmd+C" : "❌ Simulation Cmd+C")
        
        // Test simulation coller (Cmd+V)
        let pasteResult = simulateKeyPress(keyCode: CGKeyCode(kVK_ANSI_V), flags: .maskCommand)
        tests.append(pasteResult ? "✅ Simulation Cmd+V" : "❌ Simulation Cmd+V")
        
        // Test manipulation presse-papiers
        let clipboardResult = testClipboardManipulation()
        tests.append(clipboardResult ? "✅ Manipulation presse-papiers" : "❌ Manipulation presse-papiers")
        
        let allPassed = tests.allSatisfy { $0.hasPrefix("✅") }
        return TestResult(allPassed ? .passed : .failed, "Simulation d'événements", details: tests.joined(separator: ", "))
    }
    
    private func testCleanup() -> TestResult {
        print("7️⃣ Test nettoyage...")
        
        let manager = GlobalHotkeyManager.shared
        
        // Activer puis désactiver
        if manager.canEnable {
            manager.setupHotkeys()
            Thread.sleep(forTimeInterval: 0.5)
            
            if manager.isEnabled {
                manager.disableHotkeys()
                Thread.sleep(forTimeInterval: 0.5)
                
                if !manager.isEnabled {
                    return TestResult(.passed, "Nettoyage réussi")
                } else {
                    return TestResult(.failed, "Raccourcis toujours actifs après nettoyage")
                }
            } else {
                return TestResult(.skipped, "Impossible d'activer pour tester le nettoyage")
            }
        } else {
            return TestResult(.skipped, "Prérequis manquants pour test nettoyage")
        }
    }
    
    // MARK: - Méthodes utilitaires
    
    private func simulateKeyPress(keyCode: CGKeyCode, flags: CGEventFlags) -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            return false
        }
        
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return false
        }
        
        keyDown.flags = flags
        keyUp.flags = flags
        
        keyDown.post(tap: .cghidEventTap)
        usleep(50000) // 50ms
        keyUp.post(tap: .cghidEventTap)
        
        return true
    }
    
    private func testClipboardManipulation() -> Bool {
        let pasteboard = NSPasteboard.general
        
        // Sauvegarder contenu original
        let originalContent = pasteboard.string(forType: .string)
        
        // Tester écriture
        let testContent = "Test Secretino - \(UUID().uuidString)"
        pasteboard.clearContents()
        pasteboard.setString(testContent, forType: .string)
        
        // Tester lecture
        let readContent = pasteboard.string(forType: .string)
        
        // Restaurer contenu original
        pasteboard.clearContents()
        if let original = originalContent {
            pasteboard.setString(original, forType: .string)
        }
        
        return readContent == testContent
    }
    
    private func fourCharCode(_ string: String) -> FourCharCode {
        assert(string.count == 4)
        var result: FourCharCode = 0
        for char in string.utf8 {
            result = (result << 8) + FourCharCode(char)
        }
        return result
    }
}
