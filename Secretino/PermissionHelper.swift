//
//  PermissionsHelper.swift
//  Secretino
//
//  Gestionnaire des permissions système et première configuration
//

import Cocoa
import SwiftUI

class PermissionsHelper {
    static let shared = PermissionsHelper()
    
    @AppStorage("hasRequestedAccessibility") private var hasRequestedAccessibility: Bool = false
    @AppStorage("hasShownWelcome") private var hasShownWelcome: Bool = false
    
    private init() {}
    
    /// Vérifie et demande les permissions nécessaires au premier lancement
    func checkInitialPermissions() {
        // Si c'est le premier lancement, afficher un message de bienvenue
        if !hasShownWelcome {
            showWelcomeAlert()
            hasShownWelcome = true
        }
        
        // Vérifier les permissions d'accessibilité
        if !hasRequestedAccessibility {
            requestAccessibilityPermission()
        }
    }
    
    /// Affiche un message de bienvenue expliquant les fonctionnalités
    private func showWelcomeAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Bienvenue dans Secretino! 🔐"
            alert.informativeText = """
            Secretino vous permet de chiffrer et déchiffrer du texte rapidement avec des raccourcis globaux.
            
            Fonctionnalités principales :
            • Chiffrement AES-256-GCM ultra-sécurisé
            • Raccourcis globaux ⌘⌥E et ⌘⌥D
            • Fonctionne dans toutes les applications
            
            Pour utiliser les raccourcis globaux, vous devrez autoriser Secretino dans les préférences d'accessibilité.
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Commencer")
            alert.runModal()
        }
    }
    
    /// Demande la permission d'accessibilité
    private func requestAccessibilityPermission() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Autorisation requise"
            alert.informativeText = """
            Pour utiliser les raccourcis globaux, Secretino a besoin de votre autorisation.
            
            Cliquez sur "Autoriser" puis ajoutez Secretino dans:
            Préférences Système > Sécurité > Accessibilité
            """
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Autoriser")
            alert.addButton(withTitle: "Plus tard")
            
            let response = alert.runModal()
            
            if response == .alertFirstButtonReturn {
                // Forcer la demande d'accessibilité
                self.triggerAccessibilityRequest()
                self.hasRequestedAccessibility = true
            }
        }
    }
    
    /// Force macOS à afficher la demande d'accessibilité
    func triggerAccessibilityRequest() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options)
        
        if !trusted {
            // Si pas encore autorisé, ouvrir les préférences après un délai
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.openAccessibilityPreferences()
            }
        }
    }
    
    /// Ouvre directement les préférences d'accessibilité
    func openAccessibilityPreferences() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    
    /// Vérifie si l'app a les permissions sans demander
    func hasAccessibilityPermission() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options)
    }
    
    /// Affiche des instructions détaillées pour activer les permissions
    func showPermissionInstructions() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Comment activer les permissions"
            alert.informativeText = """
            1. Cliquez sur "Ouvrir Préférences" ci-dessous
            2. Cliquez sur le cadenas 🔒 en bas à gauche
            3. Entrez votre mot de passe Mac
            4. Cliquez sur le bouton "+" 
            5. Naviguez vers Applications et sélectionnez Secretino
            6. Assurez-vous que la case est cochée ✓
            
            Vous devrez peut-être redémarrer Secretino après.
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Ouvrir Préférences")
            alert.addButton(withTitle: "OK")
            
            if alert.runModal() == .alertFirstButtonReturn {
                self.openAccessibilityPreferences()
            }
        }
    }
}
