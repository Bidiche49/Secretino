//
//  GlobalHotkeyManager.swift
//  Secretino
//
//  Gestionnaire unifié des raccourcis clavier globaux avec crypto intégré
//

import Cocoa
import Carbon
import SwiftUI

class GlobalHotkeyManager: ObservableObject {
    static let shared = GlobalHotkeyManager()
    
    private var encryptHotkeyRef: EventHotKeyRef?
    private var decryptHotkeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    
    // État publié
    @Published var isEnabled: Bool = false
    @Published var globalPassphrase: String = ""
    
    // Configuration des raccourcis
    struct HotkeyConfig {
        static let encryptKey: UInt32 = UInt32(kVK_ANSI_E)  // ⌘⌥E pour chiffrer
        static let decryptKey: UInt32 = UInt32(kVK_ANSI_D)  // ⌘⌥D pour déchiffrer
        static let modifiers: UInt32 = UInt32(cmdKey + optionKey)  // Cmd+Option
    }
    
    private init() {}
    
    // MARK: - Gestion des raccourcis
    
    func setupHotkeys() {
        guard !isEnabled else { return }
        
        // Créer le gestionnaire d'événements
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (nextHandler, theEvent, userData) -> OSStatus in
                return GlobalHotkeyManager.hotkeyHandler(nextHandler: nextHandler, theEvent: theEvent, userData: userData)
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        
        if status != noErr {
            print("❌ Erreur installation gestionnaire événements: \(status)")
            return
        }
        
        // Enregistrer les raccourcis
        registerHotkey(id: 1, keyCode: HotkeyConfig.encryptKey, modifiers: HotkeyConfig.modifiers, hotkeyRef: &encryptHotkeyRef)
        registerHotkey(id: 2, keyCode: HotkeyConfig.decryptKey, modifiers: HotkeyConfig.modifiers, hotkeyRef: &decryptHotkeyRef)
        
        isEnabled = true
        print("🔥 Raccourcis globaux activés: ⌘⌥E et ⌘⌥D")
    }
    
    func disableHotkeys() {
        guard isEnabled else { return }
        
        if let encryptRef = encryptHotkeyRef {
            UnregisterEventHotKey(encryptRef)
        }
        if let decryptRef = decryptHotkeyRef {
            UnregisterEventHotKey(decryptRef)
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
        
        isEnabled = false
        print("🔕 Raccourcis globaux désactivés")
    }
    
    private func registerHotkey(id: UInt32, keyCode: UInt32, modifiers: UInt32, hotkeyRef: inout EventHotKeyRef?) {
        var hotkeyID = EventHotKeyID(signature: fourCharCode("SECR"), id: id)
        
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )
        
        if status != noErr {
            print("❌ Erreur enregistrement raccourci \(id): \(status)")
        }
    }
    
    private static func hotkeyHandler(nextHandler: EventHandlerCallRef?, theEvent: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
        guard let userData = userData else { return OSStatus(eventNotHandledErr) }
        
        let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
        
        var hotkeyID = EventHotKeyID()
        let status = GetEventParameter(
            theEvent,
            OSType(kEventParamDirectObject),
            OSType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotkeyID
        )
        
        if status == noErr {
            switch hotkeyID.id {
            case 1: // Chiffrer
                print("🔐 Raccourci chiffrement détecté")
                DispatchQueue.main.async {
                    manager.processSelectedText(encrypt: true)
                }
            case 2: // Déchiffrer
                print("🔓 Raccourci déchiffrement détecté")
                DispatchQueue.main.async {
                    manager.processSelectedText(encrypt: false)
                }
            default:
                break
            }
        }
        
        return OSStatus(noErr)
    }
    
    // MARK: - Traitement du texte
    
    func processSelectedText(encrypt: Bool) {
        guard !globalPassphrase.isEmpty else {
            showNotification(title: "Secretino", message: "Définissez d'abord une passphrase dans l'app")
            return
        }
        
        // Sauvegarder le presse-papiers actuel
        let pasteboard = NSPasteboard.general
        let originalContents = pasteboard.string(forType: .string)
        
        // Simuler Cmd+C pour copier la sélection
        simulateKeyPress(keyCode: CGKeyCode(kVK_ANSI_C), flags: .maskCommand)
        
        // Attendre que le presse-papiers soit mis à jour
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let selectedText = pasteboard.string(forType: .string),
                  !selectedText.isEmpty,
                  selectedText != originalContents else {
                self.showNotification(title: "Secretino", message: "Aucun texte sélectionné")
                // Restaurer le presse-papiers original
                if let original = originalContents {
                    pasteboard.clearContents()
                    pasteboard.setString(original, forType: .string)
                }
                return
            }
            
            // Traiter le texte
            let processedText = self.performCrypto(text: selectedText, encrypt: encrypt)
            
            if let result = processedText {
                // Mettre le résultat dans le presse-papiers
                pasteboard.clearContents()
                pasteboard.setString(result, forType: .string)
                
                // Simuler Cmd+V pour coller
                self.simulateKeyPress(keyCode: CGKeyCode(kVK_ANSI_V), flags: .maskCommand)
                
                // Notification de succès
                self.showNotification(title: "Secretino", message: encrypt ? "Texte chiffré ✅" : "Texte déchiffré ✅")
                
                // Restaurer le presse-papiers après un délai
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if let original = originalContents {
                        pasteboard.clearContents()
                        pasteboard.setString(original, forType: .string)
                    }
                }
            }
        }
    }
    
    private func performCrypto(text: String, encrypt: Bool) -> String? {
        if encrypt {
            // Chiffrer
            if let result = swift_encrypt_data(text, globalPassphrase) {
                let cryptoResult = result.pointee
                if cryptoResult.success == 1 {
                    if let base64 = swift_base64_encode(cryptoResult.data, Int32(cryptoResult.length)) {
                        let encryptedText = String(cString: base64)
                        free(base64)
                        free_crypto_result(result)
                        return encryptedText
                    }
                } else {
                    let errorMsg = String(cString: cryptoResult.error_message)
                    showNotification(title: "Erreur", message: errorMsg)
                }
                free_crypto_result(result)
            }
        } else {
            // Déchiffrer
            if let decodeResult = swift_base64_decode(text) {
                let decodedData = decodeResult.pointee
                if decodedData.success == 1 {
                    if let decryptResult = swift_decrypt_data(decodedData.data,
                                                             Int32(decodedData.length),
                                                             globalPassphrase) {
                        let decryptData = decryptResult.pointee
                        if decryptData.success == 1 {
                            let decryptedText = String(cString: decryptData.data)
                            free_crypto_result(decryptResult)
                            free_crypto_result(decodeResult)
                            return decryptedText
                        } else {
                            let errorMsg = String(cString: decryptData.error_message)
                            showNotification(title: "Erreur", message: errorMsg)
                        }
                        free_crypto_result(decryptResult)
                    }
                }
                free_crypto_result(decodeResult)
            }
        }
        return nil
    }
    
    // MARK: - Utilitaires
    
    private func simulateKeyPress(keyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .combinedSessionState)
        
        if let keyDown = CGEvent(keyboardEventSource: source,
                                virtualKey: keyCode,
                                keyDown: true),
           let keyUp = CGEvent(keyboardEventSource: source,
                              virtualKey: keyCode,
                              keyDown: false) {
            
            keyDown.flags = flags
            keyUp.flags = flags
            
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }
    }
    
    private func showNotification(title: String, message: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = message
        notification.soundName = nil
        
        NSUserNotificationCenter.default.deliver(notification)
        
        // Auto-dismiss après 2 secondes
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            NSUserNotificationCenter.default.removeDeliveredNotification(notification)
        }
    }
}

// Helper pour fourCharCode
private func fourCharCode(_ string: String) -> FourCharCode {
    assert(string.count == 4)
    var result: FourCharCode = 0
    for char in string.utf8 {
        result = (result << 8) + FourCharCode(char)
    }
    return result
}
