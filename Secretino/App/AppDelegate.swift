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
        // Initialiser OpenSSL
        init_openssl()
        
        // Créer l'icône dans la menu bar
        setupMenuBar()
        
        // Créer le popover pour l'interface
        setupPopover()
        
        // Créer le menu contextuel
        setupMenu()
        
        // Vérifier les permissions au premier lancement
        PermissionsHelper.shared.checkInitialPermissions()
        
        // Test rapide de l'intégration crypto
        testCryptoIntegration()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Désactiver les raccourcis globaux
        GlobalHotkeyManager.shared.disableHotkeys()
        
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
        GlobalHotkeyManager.shared.processSelectedText(encrypt: true)
    }
    
    @objc private func decryptSelection() {
        GlobalHotkeyManager.shared.processSelectedText(encrypt: false)
    }
    
    private func testCryptoIntegration() {
        print("🧪 Test d'intégration crypto Secretino...")
        
        let testText = "Hello from Secretino!"
        let testPassword = "test123"
        
        // Test de chiffrement
        if let result = swift_encrypt_data(testText, testPassword) {
            let cryptoResult = result.pointee
            if cryptoResult.success == 1 {
                print("✅ Chiffrement Secretino OK - Taille: \(cryptoResult.length) bytes")
                
                // Encoder en base64
                if let base64 = swift_base64_encode(cryptoResult.data, Int32(cryptoResult.length)) {
                    let base64String = String(cString: base64)
                    print("📝 Base64: \(base64String.prefix(30))...")
                    
                    // Test de déchiffrement
                    if let decodeResult = swift_base64_decode(base64) {
                        let decodedData = decodeResult.pointee
                        if decodedData.success == 1 {
                            if let decryptResult = swift_decrypt_data(decodedData.data, Int32(decodedData.length), testPassword) {
                                let decryptData = decryptResult.pointee
                                if decryptData.success == 1 {
                                    let decryptedText = String(cString: decryptData.data)
                                    print("🔓 Déchiffrement: '\(decryptedText)'")
                                    print("🎉 Secretino crypto backend opérationnel!")
                                } else {
                                    let errorMsg = String(cString: decryptData.error_message)
                                    print("❌ Erreur déchiffrement: \(errorMsg)")
                                }
                                free_crypto_result(decryptResult)
                            }
                        }
                        free_crypto_result(decodeResult)
                    }
                    free(base64)
                }
            } else {
                let errorMsg = String(cString: cryptoResult.error_message)
                print("❌ Erreur chiffrement: \(errorMsg)")
            }
            free_crypto_result(result)
        }
    }
}
