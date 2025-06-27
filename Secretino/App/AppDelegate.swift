//
//  AppDelegate.swift
//  Secretino
//
//  Gestionnaire de l'application menu bar CORRIGÉ avec gestion sécurisée
//

import Cocoa
import SwiftUI
import LocalAuthentication

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var settingsWindow: NSWindow?
    private var settingsHostingController: NSHostingController<SettingsView>?
    private var menu: NSMenu!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialiser OpenSSL
        init_openssl()
        
        // Créer l'icône dans la menu bar
        setupMenuBar()
        
        // Créer le popover pour l'interface
        setupPopover()
        
        // Créer le menu contextuel
        setupMenu()
        
        // Ajouter le menu debug en mode debug
        addDebugMenu()
        
        // Configuration initiale et vérifications
        performInitialSetup()
        
        // Test rapide de l'intégration crypto
        testCryptoIntegration()
        
        // Écouter les notifications pour ouvrir les préférences
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openSettings),
            name: NSNotification.Name("OpenSettings"),
            object: nil
        )
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Désactiver les raccourcis globaux et nettoyer la session
        GlobalHotkeyManager.shared.disableHotkeys()
        
        // Nettoyer OpenSSL à la fermeture
        cleanup_openssl()
        
        // Nettoyer les observers
        NotificationCenter.default.removeObserver(self)
    }
    
    private func performInitialSetup() {
        print("🚀 Configuration initiale de Secretino...")
        
        // Nettoyer les anciennes données non sécurisées
        cleanupLegacyData()
        
        // Vérifier les permissions si c'est le premier lancement ou une nouvelle version
        PermissionsHelper.shared.checkInitialPermissions()
        
        // Diagnostic du système
        DiagnosticHelper.runFullDiagnostic()
        
        // Vérifier si l'utilisateur a une passphrase configurée
        let hasPassphrase = SecureKeychainManager.shared.hasGlobalPassphrase()
        let hasPermissions = PermissionsHelper.shared.hasAccessibilityPermission()
        
        print("📊 État initial:")
        print("   - Passphrase sécurisée: \(hasPassphrase ? "✅" : "❌")")
        print("   - Permissions accessibilité: \(hasPermissions ? "✅" : "❌")")
        
        // Mettre à jour l'état du gestionnaire de raccourcis
        GlobalHotkeyManager.shared.hasConfiguredPassphrase = hasPassphrase
        
        // Tenter d'activer automatiquement les raccourcis si tout est configuré
        if hasPassphrase && hasPermissions {
            print("🎯 Conditions remplies - tentative d'activation automatique des raccourcis")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                GlobalHotkeyManager.shared.setupHotkeys()
            }
        } else {
            print("ℹ️ Configuration incomplète - raccourcis non activés automatiquement")
        }
    }
    
    private func cleanupLegacyData() {
        // Nettoyer les anciennes données UserDefaults non sécurisées
        let legacyKeys = [
            "secretino_temp_passphrase", // CRITIQUE: passphrase en clair
            "secretino_has_passphrase"
        ]
        
        var foundLegacyData = false
        for key in legacyKeys {
            if UserDefaults.standard.object(forKey: key) != nil {
                print("🧹 Suppression des données legacy non sécurisées: \(key)")
                UserDefaults.standard.removeObject(forKey: key)
                foundLegacyData = true
            }
        }
        
        if foundLegacyData {
            UserDefaults.standard.synchronize()
            print("✅ Nettoyage des données legacy terminé")
        }
    }
    
    private func setupMenuBar() {
        // Créer l'item dans la status bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            // Icône améliorée
            if let image = NSImage(systemSymbolName: "lock.shield.fill", accessibilityDescription: "Secretino") {
                image.size = NSSize(width: 18, height: 18)
                button.image = image
            } else {
                button.title = "🔐"
            }
            
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }
    
    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 500)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: SecretinoView())
    }
    
    private func setupMenu() {
        menu = NSMenu()
        
        // Item principal
        menu.addItem(NSMenuItem(title: "Ouvrir Secretino", action: #selector(showPopover), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        
        // Raccourcis globaux
        let hotkeyItem = NSMenuItem(title: "Raccourcis globaux", action: nil, keyEquivalent: "")
        let hotkeySubmenu = NSMenu()
        
        let encryptItem = NSMenuItem(title: "Chiffrer sélection (⌃⇧E)", action: #selector(encryptSelection), keyEquivalent: "")
        hotkeySubmenu.addItem(encryptItem)
        
        let decryptItem = NSMenuItem(title: "Déchiffrer sélection (⌃⇧D)", action: #selector(decryptSelection), keyEquivalent: "")
        hotkeySubmenu.addItem(decryptItem)
        
        hotkeySubmenu.addItem(NSMenuItem.separator())
        
        // Statut des raccourcis (sera mis à jour dynamiquement)
        let statusItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        statusItem.tag = 999 // Tag pour l'identifier
        hotkeySubmenu.addItem(statusItem)
        
        hotkeyItem.submenu = hotkeySubmenu
        menu.addItem(hotkeyItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Préférences
        menu.addItem(NSMenuItem(title: "Préférences...", action: #selector(showSettings), keyEquivalent: ","))
        
        menu.addItem(NSMenuItem.separator())
        
        // À propos et Quitter
        menu.addItem(NSMenuItem(title: "À propos de Secretino", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quitter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }
    
    // MARK: - Actions Debug - DÉFINIES AVANT UTILISATION
    
    @objc func runAutomatedTests() {
        TestOrchestrator.shared.runAllTests()
    }
    
    @objc func runQuickValidation() {
        TestOrchestrator.shared.runQuickValidation()
    }
    
    @objc func runSpecificTest() {
        // Demander quel test lancer
        let alert = NSAlert()
        alert.messageText = "Quel test lancer ?"
        alert.informativeText = "Tests disponibles: Crypto, Keychain, Migration, Permissions, Raccourcis, Intégration"
        alert.addButton(withTitle: "Crypto")
        alert.addButton(withTitle: "Keychain")
        alert.addButton(withTitle: "Raccourcis")
        alert.addButton(withTitle: "Annuler")
        
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            TestOrchestrator.shared.runSpecificTest("crypto")
        case .alertSecondButtonReturn:
            TestOrchestrator.shared.runSpecificTest("keychain")
        case .alertThirdButtonReturn:
            TestOrchestrator.shared.runSpecificTest("raccourcis")
        default:
            break
        }
    }
    
    @objc func generateDiagnosticReport() {
        let report = TestOrchestrator.shared.generateDiagnosticReport()
        
        // Copier dans le presse-papiers
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(report, forType: .string)
        
        showAlert(title: "Rapport généré", message: "Le rapport de diagnostic a été copié dans le presse-papiers")
    }
    
    @objc func testKeychain() {
        KeychainTester.shared.runFullKeychainTest()
        KeychainTester.shared.debugKeychainInfo()
    }
    
    @objc func testMigration() {
        MigrationTester.shared.testMigration()
    }
    
    @objc func createLegacyData() {
        MigrationTester.shared.createLegacyData()
        showAlert(title: "Debug", message: "Données legacy créées pour test")
    }
    
    @objc func cleanAllData() {
        let alert = NSAlert()
        alert.messageText = "Nettoyer toutes les données ?"
        alert.informativeText = "Ceci supprimera TOUTES les données Secretino pour permettre un test de première installation."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Nettoyer")
        alert.addButton(withTitle: "Annuler")
        
        if alert.runModal() == .alertFirstButtonReturn {
            MigrationTester.shared.cleanAllDataForTesting()
            showAlert(title: "Debug", message: "Toutes les données ont été supprimées. Relancez l'app.")
        }
    }
    
    @objc func showUserDefaults() {
        MigrationTester.shared.listAllUserDefaults()
        showAlert(title: "Debug", message: "UserDefaults affichés dans la console")
    }
    
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
    
    // MARK: - Menu Debug
    
    /// Ajouter ceci dans setupMenu() pour créer un menu de debug
    private func addDebugMenu() {
        #if DEBUG
        menu.addItem(NSMenuItem.separator())
        
        let debugItem = NSMenuItem(title: "🧪 Debug", action: nil, keyEquivalent: "")
        let debugSubmenu = NSMenu()
        
        // Tests automatisés
        debugSubmenu.addItem(NSMenuItem(title: "🚀 Tous les tests", action: #selector(runAutomatedTests), keyEquivalent: ""))
        debugSubmenu.addItem(NSMenuItem(title: "⚡ Validation rapide", action: #selector(runQuickValidation), keyEquivalent: ""))
        debugSubmenu.addItem(NSMenuItem(title: "🎯 Test spécifique", action: #selector(runSpecificTest), keyEquivalent: ""))
        
        debugSubmenu.addItem(NSMenuItem.separator())
        
        // Tests individuels
        debugSubmenu.addItem(NSMenuItem(title: "🔐 Test Keychain", action: #selector(testKeychain), keyEquivalent: ""))
        debugSubmenu.addItem(NSMenuItem(title: "🔄 Test Migration", action: #selector(testMigration), keyEquivalent: ""))
        debugSubmenu.addItem(NSMenuItem(title: "📊 Rapport diagnostic", action: #selector(generateDiagnosticReport), keyEquivalent: ""))
        
        debugSubmenu.addItem(NSMenuItem.separator())
        
        // Outils de données
        debugSubmenu.addItem(NSMenuItem(title: "➕ Créer données legacy", action: #selector(createLegacyData), keyEquivalent: ""))
        debugSubmenu.addItem(NSMenuItem(title: "🧹 Nettoyer toutes données", action: #selector(cleanAllData), keyEquivalent: ""))
        debugSubmenu.addItem(NSMenuItem(title: "📋 Afficher UserDefaults", action: #selector(showUserDefaults), keyEquivalent: ""))
        
        debugItem.submenu = debugSubmenu
        menu.addItem(debugItem)
        #endif
    }
    
    // MARK: - Actions Debug
//    
//    /// Ajouter cette méthode à votre AppDelegate pour lancer les tests
//    @objc func runAutomatedTests() {
//        TestOrchestrator.shared.runAllTests()
//    }
//    
//    @objc func runQuickValidation() {
//        TestOrchestrator.shared.runQuickValidation()
//    }
//    
//    @objc func runSpecificTest() {
//        // Demander quel test lancer
//        let alert = NSAlert()
//        alert.messageText = "Quel test lancer ?"
//        alert.informativeText = "Tests disponibles: Crypto, Keychain, Migration, Permissions, Raccourcis, Intégration"
//        alert.addButton(withTitle: "Crypto")
//        alert.addButton(withTitle: "Keychain")
//        alert.addButton(withTitle: "Raccourcis")
//        alert.addButton(withTitle: "Annuler")
//        
//        let response = alert.runModal()
//        switch response {
//        case .alertFirstButtonReturn:
//            TestOrchestrator.shared.runSpecificTest("crypto")
//        case .alertSecondButtonReturn:
//            TestOrchestrator.shared.runSpecificTest("keychain")
//        case .alertThirdButtonReturn:
//            TestOrchestrator.shared.runSpecificTest("raccourcis")
//        default:
//            break
//        }
//    }
//    
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp {
            // Mettre à jour le statut avant d'afficher le menu
            updateMenuStatus()
            
            // Clic droit : afficher le menu
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            // Clic gauche : afficher le popover
            togglePopover()
        }
    }
    
    private func updateMenuStatus() {
        // Mettre à jour le statut des raccourcis dans le menu
        if let hotkeySubmenu = menu.item(withTitle: "Raccourcis globaux")?.submenu,
           let statusItem = hotkeySubmenu.items.first(where: { $0.tag == 999 }) {
            
            let manager = GlobalHotkeyManager.shared
            let isEnabled = manager.isEnabled
            let hasPassphrase = manager.hasConfiguredPassphrase
            let hasPermissions = PermissionsHelper.shared.hasAccessibilityPermission()
            
            let statusText: String
            let statusColor: NSColor
            
            if isEnabled {
                statusText = "✅ Raccourcis actifs"
                statusColor = .systemGreen
            } else if !hasPassphrase {
                statusText = "⚙️ Passphrase non configurée"
                statusColor = .systemOrange
            } else if !hasPermissions {
                statusText = "🔒 Permissions manquantes"
                statusColor = .systemOrange
            } else {
                statusText = "❌ Raccourcis inactifs"
                statusColor = .systemRed
            }
            
            statusItem.attributedTitle = NSAttributedString(
                string: statusText,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 12),
                    .foregroundColor: statusColor
                ]
            )
        }
    }
    
    @objc private func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
                
                // S'assurer que la fenêtre du popover devient key
                if let popoverWindow = popover.contentViewController?.view.window {
                    popoverWindow.makeKey()
                }
            }
        }
    }
    
    @objc private func showPopover() {
        if let button = statusItem.button {
            if !popover.isShown {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
            }
        }
    }
    
    @objc private func showSettings() {
        openSettings()
    }
    
    @objc private func openSettings() {
        if settingsWindow == nil {
            // Créer le hosting controller une seule fois
            settingsHostingController = NSHostingController(rootView: SettingsView())
            
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 720),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.title = "Préférences Secretino"
            settingsWindow?.center()
            settingsWindow?.contentViewController = settingsHostingController
            settingsWindow?.minSize = NSSize(width: 400, height: 720)
            settingsWindow?.maxSize = NSSize(width: 600, height: 800)
            
            // Observer la fermeture de la fenêtre
            settingsWindow?.delegate = self
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Secretino"
        
        let manager = GlobalHotkeyManager.shared
        let securityStatus = manager.hasConfiguredPassphrase ? "🔐 Passphrase sécurisée" : "⚠️ Passphrase non configurée"
        let hotkeyStatus = manager.isEnabled ? "⚡ Raccourcis actifs" : "❌ Raccourcis inactifs"
        
        alert.informativeText = """
        Version 1.0
        
        Cryptage militaire AES-256-GCM
        pour macOS avec sécurité renforcée
        
        État actuel :
        \(securityStatus)
        \(hotkeyStatus)
        
        Raccourcis disponibles :
        ⌃⇧E - Chiffrer la sélection
        ⌃⇧D - Déchiffrer la sélection
        
        Sécurité :
        • Stockage Keychain avec biométrie
        • Effacement sécurisé de la mémoire
        • Session avec timeout automatique
        
        © 2025 Secretino
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        
        if !manager.hasConfiguredPassphrase {
            alert.addButton(withTitle: "Configurer")
            let response = alert.runModal()
            if response == .alertSecondButtonReturn {
                openSettings()
            }
        } else {
            alert.runModal()
        }
    }
    
    @objc private func encryptSelection() {
        let manager = GlobalHotkeyManager.shared
        if manager.canEnable {
            manager.processSelectedText(encrypt: true)
        } else {
            showSetupRequiredAlert()
        }
    }
    
    @objc private func decryptSelection() {
        let manager = GlobalHotkeyManager.shared
        if manager.canEnable {
            manager.processSelectedText(encrypt: false)
        } else {
            showSetupRequiredAlert()
        }
    }
    
    private func showSetupRequiredAlert() {
        let alert = NSAlert()
        alert.messageText = "Configuration requise"
        alert.informativeText = """
        Pour utiliser les raccourcis, vous devez :
        1. Configurer une passphrase sécurisée
        2. Autoriser l'accès à l'accessibilité
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Ouvrir Préférences")
        alert.addButton(withTitle: "Plus tard")
        
        if alert.runModal() == .alertFirstButtonReturn {
            openSettings()
        }
    }
    
    private func testCryptoIntegration() {
        print("🧪 Test d'intégration crypto Secretino...")
        
        let testText = "Hello from Secretino!"
        let testPassword = "test123"
        
        // Test de chiffrement
        if let result = swift_encrypt_data(testText, testPassword) {
            defer { free_crypto_result(result) }
            let cryptoResult = result.pointee
            if cryptoResult.success == 1 {
                print("✅ Chiffrement Secretino OK - Taille: \(cryptoResult.length) bytes")
                
                // Encoder en base64
                if let base64 = swift_base64_encode(cryptoResult.data, Int32(cryptoResult.length)) {
                    defer { free(base64) } // ✅ UNE SEULE libération avec defer
                    let base64String = String(cString: base64)
                    print("📝 Base64: \(base64String.prefix(30))...")
                    
                    // Test de déchiffrement
                    if let decodeResult = swift_base64_decode(base64) {
                        defer { free_crypto_result(decodeResult) }
                        let decodedData = decodeResult.pointee
                        if decodedData.success == 1 {
                            if let decryptResult = swift_decrypt_data(decodedData.data, Int32(decodedData.length), testPassword) {
                                defer { free_crypto_result(decryptResult) }
                                let decryptData = decryptResult.pointee
                                if decryptData.success == 1 {
                                    let decryptedText = String(cString: decryptData.data)
                                    print("🔓 Déchiffrement: '\(decryptedText)'")
                                    print("🎉 Secretino crypto backend opérationnel!")
                                } else {
                                    let errorMsg = String(cString: decryptData.error_message)
                                    print("❌ Erreur déchiffrement: \(errorMsg)")
                                }
                            }
                        }
                    }
                    // ❌ SUPPRIMÉ : free(base64) - déjà géré par defer
                }
            } else {
                let errorMsg = String(cString: cryptoResult.error_message)
                print("❌ Erreur chiffrement: \(errorMsg)")
            }
        }
    }
}

// MARK: - NSWindowDelegate
extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow === settingsWindow {
            // Ne pas détruire la fenêtre, juste la cacher
            // Ceci évite le crash lors de la réouverture
        }
    }
}
