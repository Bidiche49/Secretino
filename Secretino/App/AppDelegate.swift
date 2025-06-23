//
//  AppDelegate.swift
//  Secretino
//
//  Gestionnaire de l'application menu bar avec raccourcis globaux
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var settingsWindow: NSWindow?
    private var menu: NSMenu!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 Démarrage de Secretino...")
        
        // Initialiser OpenSSL de manière sécurisée
        do {
            try initializeOpenSSL()
            print("✅ OpenSSL initialisé avec succès")
        } catch {
            print("❌ Erreur d'initialisation OpenSSL: \(error)")
            return
        }
        
        // Créer l'icône dans la menu bar
        setupMenuBar()
        
        // Créer le popover pour l'interface
        setupPopover()
        
<<<<<<< HEAD
        // Test rapide de l'intégration crypto (optionnel en debug)
        #if DEBUG
=======
        // Créer le menu contextuel
        setupMenu()
        
        // Vérifier les permissions au premier lancement
        PermissionsHelper.shared.checkInitialPermissions()
        
        // Test rapide de l'intégration crypto
>>>>>>> force-push-master2
        testCryptoIntegration()
        #endif
    }
    
    private func initializeOpenSSL() throws {
        init_openssl()
        
        // Tester si OpenSSL fonctionne
        var salt = [UInt8](repeating: 0, count: 32)
        let result = RAND_bytes(&salt, 32)
        if result != 1 {
            throw NSError(domain: "SecretinoError", code: 1, userInfo: [NSLocalizedDescriptionKey: "OpenSSL RAND_bytes failed"])
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Désactiver les raccourcis globaux
        GlobalHotKeyManager.shared.disableHotkeys()
        
        // Nettoyer OpenSSL à la fermeture
        cleanup_openssl()
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
        // Assure-toi que le nom correspond à ta vue actuelle
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
        
        let encryptItem = NSMenuItem(title: "Chiffrer sélection", action: #selector(encryptSelection), keyEquivalent: "e")
        encryptItem.keyEquivalentModifierMask = [.command, .option]
        hotkeySubmenu.addItem(encryptItem)
        
        let decryptItem = NSMenuItem(title: "Déchiffrer sélection", action: #selector(decryptSelection), keyEquivalent: "d")
        decryptItem.keyEquivalentModifierMask = [.command, .option]
        hotkeySubmenu.addItem(decryptItem)
        
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
    
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp {
            // Clic droit : afficher le menu
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            // Clic gauche : afficher le popover
            togglePopover()
        }
    }
    
    @objc private func togglePopover() {
        print("🖱️ Clic sur l'icône Secretino détecté")
        
        if let button = statusItem.button {
            if popover.isShown {
                print("🔄 Fermeture du popover")
                popover.performClose(nil)
            } else {
                print("🔄 Ouverture du popover")
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
                
<<<<<<< HEAD
                // Activer la fenêtre pour s'assurer qu'elle apparaît
                NSApp.activate(ignoringOtherApps: true)
=======
                // S'assurer que la fenêtre du popover devient key
                if let popoverWindow = popover.contentViewController?.view.window {
                    popoverWindow.makeKey()
                }
>>>>>>> force-push-master2
            }
        } else {
            print("❌ Erreur: button non trouvé")
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
        if settingsWindow == nil {
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 720),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.title = "Préférences Secretino"
            settingsWindow?.center()
            settingsWindow?.contentView = NSHostingView(rootView: SettingsView())
            settingsWindow?.minSize = NSSize(width: 400, height: 720)
            settingsWindow?.maxSize = NSSize(width: 600, height: 800)
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Secretino"
        alert.informativeText = """
        Version 1.0
        
        Cryptage militaire AES-256-GCM
        pour macOS
        
        🔐 Chiffrement ultra-sécurisé
        ⚡ Raccourcis globaux
        🛡️ Protection maximale
        
        © 2025 Secretino
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc private func encryptSelection() {
        GlobalHotKeyManager.shared.processSelectedText(encrypt: true)
    }
    
    @objc private func decryptSelection() {
        GlobalHotKeyManager.shared.processSelectedText(encrypt: false)
    }
    
    private func testCryptoIntegration() {
        print("🧪 Test d'intégration crypto Secretino...")
        
        let testText = "Hello from Secretino!"
        let testPassword = "test123"
        
        // Test simple avec gestion d'erreur
        guard let result = swift_encrypt_data(testText, testPassword) else {
            print("❌ Impossible de créer le résultat de chiffrement")
            return
        }
        
        defer { free_crypto_result(result) }
        
        let cryptoResult = result.pointee
        
        if cryptoResult.success == 1 {
            print("✅ Chiffrement Secretino OK - Taille: \(cryptoResult.length) bytes")
            print("🎉 Backend crypto opérationnel!")
        } else {
            if let errorMsg = cryptoResult.error_message {
                let errorString = String(cString: errorMsg)
                print("❌ Erreur chiffrement: \(errorString)")
            } else {
                print("❌ Erreur chiffrement inconnue")
            }
        }
    }
}
