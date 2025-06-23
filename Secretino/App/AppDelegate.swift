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
        // Initialiser OpenSSL
        init_openssl()
        
        // Créer l'icône dans la menu bar
        setupMenuBar()
        
        // Créer le popover pour l'interface
        setupPopover()
        
        // Test rapide de l'intégration crypto
        testCryptoIntegration()
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
        popover.contentViewController = NSHostingController(rootView: SecretinoView())
    }
    
    @objc private func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
            }
        }
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
