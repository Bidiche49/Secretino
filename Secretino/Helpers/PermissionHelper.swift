//
//  PermissionsHelper.swift
//  Secretino
//
//  Gestionnaire des permissions système et première configuration AMÉLIORÉ
//

import Cocoa
import SwiftUI

class PermissionsHelper {
    static let shared = PermissionsHelper()
    
    private enum UserDefaultsKeys {
        static let lastVersion = "secretino_last_version"
        static let hasShownWelcome = "secretino_has_shown_welcome"
        static let lastPermissionCheck = "secretino_last_permission_check"
    }
    
    private init() {}
    
    /// Vérifie les permissions et gère la première configuration
    func checkInitialPermissions() {
        let currentVersion = getCurrentVersion()
        let lastVersion = UserDefaults.standard.string(forKey: UserDefaultsKeys.lastVersion)
        let hasShownWelcome = UserDefaults.standard.bool(forKey: UserDefaultsKeys.hasShownWelcome)
        
        print("🔍 Vérification initiale des permissions...")
        print("   Version actuelle: \(currentVersion)")
        print("   Dernière version: \(lastVersion ?? "aucune")")
        print("   Bienvenue montrée: \(hasShownWelcome)")
        
        // Mettre à jour la version
        UserDefaults.standard.set(currentVersion, forKey: UserDefaultsKeys.lastVersion)
        
        let isFirstLaunch = (lastVersion == nil)
        let isNewVersion = (lastVersion != currentVersion)
        
        if isFirstLaunch {
            print("🆕 Premier lancement détecté")
            handleFirstLaunch()
        } else if isNewVersion {
            print("🔄 Nouvelle version détectée")
            handleVersionUpdate(from: lastVersion, to: currentVersion)
        } else {
            print("ℹ️ Lancement normal")
            performSilentPermissionCheck()
        }
    }
    
    private func handleFirstLaunch() {
        // Marquer comme première exécution
        UserDefaults.standard.set(true, forKey: UserDefaultsKeys.hasShownWelcome)
        
        // Afficher le message de bienvenue et demander les permissions immédiatement
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showWelcomeAndRequestPermissions()
        }
    }
    
    private func handleVersionUpdate(from oldVersion: String?, to newVersion: String) {
        print("📈 Mise à jour de \(oldVersion ?? "inconnue") vers \(newVersion)")
        
        // Vérifier silencieusement les permissions
        performSilentPermissionCheck()
        
        // Si c'est une mise à jour majeure, on peut afficher des informations
        // Pour l'instant, on reste silencieux
    }
    
    private func performSilentPermissionCheck() {
        let hasAccessibility = hasAccessibilityPermission()
        let hasPassphrase = SecureKeychainManager.shared.hasGlobalPassphrase()
        
        print("📊 État des permissions:")
        print("   Accessibilité: \(hasAccessibility ? "✅" : "❌")")
        print("   Passphrase configurée: \(hasPassphrase ? "✅" : "❌")")
        
        // Enregistrer la dernière vérification
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: UserDefaultsKeys.lastPermissionCheck)
        
        // Si tout est configuré, on peut essayer d'activer automatiquement
        if hasAccessibility && hasPassphrase {
            print("🎯 Configuration complète détectée - activation automatique possible")
        }
    }
    
    /// Affiche le message de bienvenue et demande les permissions
    private func showWelcomeAndRequestPermissions() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Bienvenue dans Secretino! 🔐"
            alert.informativeText = """
            Secretino protège vos données avec un chiffrement militaire AES-256-GCM.
            
            Fonctionnalités principales :
            • Chiffrement ultra-sécurisé avec protection biométrique
            • Raccourcis globaux ⌃⇧E (chiffrer) et ⌃⇧D (déchiffrer)
            • Fonctionne dans toutes les applications
            • Stockage sécurisé dans le Keychain macOS
            
            Pour utiliser les raccourcis globaux, Secretino a besoin :
            1. D'une passphrase sécurisée (avec Touch ID/Face ID)
            2. De l'autorisation d'accessibilité
            
            Voulez-vous configurer cette autorisation maintenant ?
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Autoriser maintenant")
            alert.addButton(withTitle: "Plus tard")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // Déclencher directement la demande de permissions
                self.triggerAccessibilityRequest()
                
                // Ouvrir les préférences après un court délai
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.openSettingsForConfiguration()
                }
            }
        }
    }

    /// Démarre le processus de configuration complète
    private func startSetupProcess() {
        print("🚀 Démarrage du processus de configuration...")
        
        // Étape 1: Vérifier/demander les permissions d'accessibilité
        if !hasAccessibilityPermission() {
            requestAccessibilityPermission()
        } else {
            // Permissions déjà accordées, ouvrir directement les préférences
            openSettingsForConfiguration()
        }
    }
    
    /// Demande les permissions d'accessibilité avec instructions
    func requestAccessibilityPermission() {
        print("🔐 Demande des permissions d'accessibilité...")
        
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Autorisation d'accessibilité requise"
            alert.informativeText = """
            Pour que les raccourcis globaux fonctionnent, Secretino doit être autorisé dans les préférences d'accessibilité.
            
            macOS va maintenant ouvrir les Préférences Système.
            
            Instructions :
            1. Cliquez sur le cadenas 🔒 et entrez votre mot de passe
            2. Cochez la case à côté de "Secretino" ✓
            3. Revenez à Secretino pour terminer la configuration
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Ouvrir Préférences Système")
            alert.addButton(withTitle: "Plus tard")
            
            if alert.runModal() == .alertFirstButtonReturn {
                self.triggerAccessibilityRequest()
                
                // Surveiller les changements de permissions
                self.startPermissionMonitoring()
            }
        }
    }
    
    /// Force macOS à afficher la demande d'accessibilité
    func triggerAccessibilityRequest() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options)
        
        print("🔓 Demande d'accessibilité déclenchée, statut: \(trusted)")
        
        // Ne PAS ouvrir automatiquement les préférences
        // L'utilisateur peut cliquer sur le bouton dans la fenêtre système
    }
    
    /// Surveille les changements de permissions après la demande
    private func startPermissionMonitoring() {
        var checkCount = 0
        let maxChecks = 30 // 30 secondes maximum
        
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            checkCount += 1
            
            if self.hasAccessibilityPermission() {
                timer.invalidate()
                print("✅ Permissions d'accessibilité accordées!")
                
                DispatchQueue.main.async {
                    self.onPermissionGranted()
                }
            } else if checkCount >= maxChecks {
                timer.invalidate()
                print("⏰ Timeout de surveillance des permissions")
            }
        }
        
        // Garder une référence au timer pour éviter qu'il soit deallocated
        Timer.scheduledTimer(withTimeInterval: 31.0, repeats: false) { _ in
            timer.invalidate()
        }
    }
    
    /// Appelé quand les permissions sont accordées
    private func onPermissionGranted() {
        let alert = NSAlert()
        alert.messageText = "Permissions accordées! ✅"
        alert.informativeText = """
        Excellent! Secretino peut maintenant utiliser les raccourcis globaux.
        
        Étape suivante : configurez votre passphrase sécurisée dans les préférences.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Ouvrir Préférences")
        alert.addButton(withTitle: "Plus tard")
        
        if alert.runModal() == .alertFirstButtonReturn {
            openSettingsForConfiguration()
        }
    }
    
    /// Ouvre les préférences de l'app pour configuration
    private func openSettingsForConfiguration() {
        // Envoyer une notification pour ouvrir les préférences
        NotificationCenter.default.post(name: NSNotification.Name("OpenSettings"), object: nil)
    }
    
    /// Ouvre directement les préférences d'accessibilité système
    func openAccessibilityPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
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
            alert.messageText = "Comment activer les permissions d'accessibilité"
            alert.informativeText = """
            📋 Instructions détaillées :
            
            1. Ouvrez "Préférences Système" (ou "Réglages Système" sur macOS 13+)
            2. Allez dans "Sécurité et confidentialité" → "Accessibilité"
            3. Cliquez sur le cadenas 🔒 en bas à gauche
            4. Entrez votre mot de passe Mac
            5. Cochez la case à côté de "Secretino" ✓
            
            💡 Astuces :
            • Si Secretino n'apparaît pas, glissez-déposez l'app dans la liste
            • Redémarrez Secretino après avoir activé les permissions
            • Vous pouvez désactiver ces permissions à tout moment
            
            ⚠️ Ces permissions permettent à Secretino de :
            • Lire le texte sélectionné dans d'autres apps
            • Simuler des frappes clavier (copier/coller)
            • Écouter les raccourcis globaux ⌃⇧E et ⌃⇧D
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Ouvrir Préférences Système")
            alert.addButton(withTitle: "Compris")
            
            if alert.runModal() == .alertFirstButtonReturn {
                self.openAccessibilityPreferences()
            }
        }
    }
    
    /// Affiche une alerte si les permissions sont manquantes
    func showPermissionRequiredAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Permissions d'accessibilité requises"
            alert.informativeText = """
            Les raccourcis globaux ne peuvent pas fonctionner sans l'autorisation d'accessibilité.
            
            Sans cette permission :
            ❌ Les raccourcis ⌃⇧E et ⌃⇧D ne fonctionneront pas
            ❌ Secretino ne peut pas lire le texte sélectionné
            ❌ Le remplacement automatique du texte est impossible
            
            ✅ Avec cette permission :
            • Chiffrement/déchiffrement instantané dans toute app
            • Workflow fluide et sécurisé
            • Protection automatique de vos données sensibles
            """
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Configurer maintenant")
            alert.addButton(withTitle: "Instructions détaillées")
            alert.addButton(withTitle: "Plus tard")
            
            let response = alert.runModal()
            switch response {
            case .alertFirstButtonReturn:
                self.triggerAccessibilityRequest()
            case .alertSecondButtonReturn:
                self.showPermissionInstructions()
            default:
                break
            }
        }
    }
    
    /// Vérifie périodiquement si les permissions ont changé
    func startPeriodicPermissionCheck() {
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            let hasPermission = self.hasAccessibilityPermission()
            let lastCheck = UserDefaults.standard.double(forKey: UserDefaultsKeys.lastPermissionCheck)
            let now = Date().timeIntervalSince1970
            
            // Si les permissions ont changé depuis la dernière vérification
            if now - lastCheck > 30 { // Vérifier toutes les 30 secondes minimum
                UserDefaults.standard.set(now, forKey: UserDefaultsKeys.lastPermissionCheck)
                
                // Mettre à jour l'état du gestionnaire de raccourcis si nécessaire
                if hasPermission && SecureKeychainManager.shared.hasGlobalPassphrase() {
                    // Les conditions sont remplies, on peut activer automatiquement
                    if !GlobalHotkeyManager.shared.isEnabled {
                        print("🔄 Permissions restaurées - tentative d'activation automatique")
                        DispatchQueue.main.async {
                            GlobalHotkeyManager.shared.setupHotkeys()
                        }
                    }
                } else if !hasPermission && GlobalHotkeyManager.shared.isEnabled {
                    // Permissions révoquées
                    print("⚠️ Permissions d'accessibilité révoquées")
                    DispatchQueue.main.async {
                        GlobalHotkeyManager.shared.disableHotkeys()
                    }
                }
            }
        }
    }
    
    // MARK: - Utilitaires
    
    private func getCurrentVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    /// Nettoie toutes les préférences liées aux permissions
    func resetPermissionPreferences() {
        let keys = [
            UserDefaultsKeys.lastVersion,
            UserDefaultsKeys.hasShownWelcome,
            UserDefaultsKeys.lastPermissionCheck
        ]
        
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        UserDefaults.standard.synchronize()
        print("🧹 Préférences de permissions réinitialisées")
    }
}
