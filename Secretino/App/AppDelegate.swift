//
//  AppDelegate.swift
//  Secretino
//
//  Gestionnaire de l'application menu bar
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    
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
        
        // Test rapide de l'intégration crypto (optionnel en debug)
        #if DEBUG
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
        // Nettoyer OpenSSL à la fermeture
        cleanup_openssl()
    }
    
    private func setupMenuBar() {
        // Créer l'item dans la status bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            // Icône temporaire (on créera une vraie icône plus tard)
            button.title = "🔐"
            button.action = #selector(togglePopover)
            button.target = self
        }
    }
    
    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 500)
        popover.behavior = .transient
        // Assure-toi que le nom correspond à ta vue actuelle
        popover.contentViewController = NSHostingController(rootView: SecretinoView())
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
                
                // Activer la fenêtre pour s'assurer qu'elle apparaît
                NSApp.activate(ignoringOtherApps: true)
            }
        } else {
            print("❌ Erreur: button non trouvé")
        }
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
