//
//  DiagnosticHelper.swift
//  Secretino
//
//  Utilitaire de diagnostic pour déboguer les problèmes de raccourcis
//

import Cocoa
import Carbon

class DiagnosticHelper {
    static func runFullDiagnostic() {
        print("\n🔍 === DIAGNOSTIC SECRETINO ===")
        
        // 1. Vérifier les permissions
        checkPermissions()
        
        // 2. Vérifier l'environnement d'exécution
        checkEnvironment()
        
        // 3. Tester l'API Carbon
        testCarbonAPI()
        
        // 4. Vérifier les conflits de raccourcis
        checkHotkeyConflicts()
        
        print("=== FIN DIAGNOSTIC ===\n")
    }
    
    private static func checkPermissions() {
        print("\n📋 Vérification des permissions:")
        
        // Accessibilité
        let accessibilityTrusted = AXIsProcessTrustedWithOptions([
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false
        ] as CFDictionary)
        
        print("   Accessibilité: \(accessibilityTrusted ? "✅ Accordée" : "❌ Refusée")")
        
        // Événements Apple
        let appleEvents = checkAppleEventPermissions()
        print("   Événements Apple: \(appleEvents ? "✅ OK" : "❌ Problème")")
        
        // Sandbox
        let sandboxed = isRunningInSandbox()
        print("   Sandbox: \(sandboxed ? "⚠️ Activé (peut bloquer les raccourcis)" : "✅ Désactivé")")
    }
    
    private static func checkEnvironment() {
        print("\n🖥️ Environnement d'exécution:")
        
        let bundle = Bundle.main
        print("   Bundle ID: \(bundle.bundleIdentifier ?? "Non défini")")
        print("   Version: \(bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")")
        print("   Build: \(bundle.infoDictionary?["CFBundleVersion"] as? String ?? "?")")
        
        // Mode d'exécution
        if NSApp.activationPolicy() == .accessory {
            print("   Mode: ✅ Agent (LSUIElement)")
        } else {
            print("   Mode: ⚠️ Application normale")
        }
        
        // Processus parent
        let parentPID = getppid()
        print("   PID parent: \(parentPID)")
    }
    
    private static func testCarbonAPI() {
        print("\n⚙️ Test de l'API Carbon:")
        
        // Tester l'installation d'un gestionnaire temporaire
        var eventHandler: EventHandlerRef?
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, _, _) -> OSStatus in return OSStatus(noErr) },
            1,
            &eventType,
            nil,
            &eventHandler
        )
        
        if status == noErr {
            print("   Gestionnaire d'événements: ✅ Installation réussie")
            if let handler = eventHandler {
                RemoveEventHandler(handler)
                print("   Gestionnaire d'événements: ✅ Suppression réussie")
            }
        } else {
            print("   Gestionnaire d'événements: ❌ Erreur \(status)")
        }
        
        // Tester l'enregistrement d'un raccourci temporaire
        var hotkeyRef: EventHotKeyRef?
        var hotkeyID = EventHotKeyID(signature: fourCharCode("TEST"), id: 999)
        
        let hotkeyStatus = RegisterEventHotKey(
            UInt32(kVK_F19), // Touche peu utilisée
            0, // Pas de modificateurs
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )
        
        if hotkeyStatus == noErr {
            print("   Enregistrement raccourci: ✅ Succès")
            if let hotkey = hotkeyRef {
                UnregisterEventHotKey(hotkey)
                print("   Désenregistrement raccourci: ✅ Succès")
            }
        } else {
            print("   Enregistrement raccourci: ❌ Erreur \(hotkeyStatus)")
        }
    }
    
    private static func checkHotkeyConflicts() {
        print("\n🔍 Vérification des conflits de raccourcis:")
        
        // Lister les raccourcis système connus qui pourraient entrer en conflit
        let knownConflicts = [
            "⌘⌥E": "Finder - Éjecter",
            "⌘⌥D": "Dock - Masquer/Afficher"
        ]
        
        for (hotkey, conflict) in knownConflicts {
            print("   \(hotkey): ⚠️ Peut entrer en conflit avec \(conflict)")
        }
        
        print("   💡 Conseil: Vérifiez Préférences Système > Clavier > Raccourcis")
    }
    
    // MARK: - Fonctions utilitaires
    
    private static func checkAppleEventPermissions() -> Bool {
        // Tentative d'envoi d'un événement Apple simple pour tester
        let script = NSAppleScript(source: "tell application \"System Events\" to get name")
        var error: NSDictionary?
        let result = script?.executeAndReturnError(&error)
        return error == nil
    }
    
    private static func isRunningInSandbox() -> Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }
    
    private static func fourCharCode(_ string: String) -> FourCharCode {
        assert(string.count == 4)
        var result: FourCharCode = 0
        for char in string.utf8 {
            result = (result << 8) + FourCharCode(char)
        }
        return result
    }
}
