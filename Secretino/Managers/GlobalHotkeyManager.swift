//
//  GlobalHotkeyManager.swift
//  Secretino
//
//  Gestionnaire de raccourcis clavier globaux pour cryptage/décryptage rapide
//

import Cocoa
import Carbon
import SwiftUI

class GlobalHotKeyManager: ObservableObject {
    static let shared = GlobalHotKeyManager()
    
    // Raccourcis par défaut
    private let encryptHotkey = (key: kVK_ANSI_E, modifiers: cmdKey | optionKey) // ⌘⌥E
    private let decryptHotkey = (key: kVK_ANSI_D, modifiers: cmdKey | optionKey) // ⌘⌥D
    
    private var encryptEventHotkey: EventHotKeyRef?
    private var decryptEventHotkey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    
    @Published var isEnabled: Bool = false
    @Published var lastError: String = ""
    @Published var currentPassphrase: String = ""
    
    // Singleton
    private init() {}
    
    // MARK: - Setup
    
    func setupHotkeys() {
        guard !isEnabled else { return }
        
        // Créer le gestionnaire d'événements
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let handler: EventHandlerUPP = { (nextHandler, event, userData) -> OSStatus in
            GlobalHotKeyManager.shared.handleHotKeyEvent(event: event!)
            return noErr
        }
        
        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, &eventHandler)
        
        // Enregistrer les raccourcis
        registerHotkey(keyCode: UInt32(encryptHotkey.key),
                      modifiers: UInt32(encryptHotkey.modifiers),
                      id: 1,
                      hotkeyRef: &encryptEventHotkey)
        
        registerHotkey(keyCode: UInt32(decryptHotkey.key),
                      modifiers: UInt32(decryptHotkey.modifiers),
                      id: 2,
                      hotkeyRef: &decryptEventHotkey)
        
        isEnabled = true
        print("🎯 Raccourcis globaux activés: ⌘⌥E (chiffrer), ⌘⌥D (déchiffrer)")
    }
    
    func disableHotkeys() {
        guard isEnabled else { return }
        
        if let hotkey = encryptEventHotkey {
            UnregisterEventHotKey(hotkey)
        }
        
        if let hotkey = decryptEventHotkey {
            UnregisterEventHotKey(hotkey)
        }
        
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
        
        isEnabled = false
        print("🔕 Raccourcis globaux désactivés")
    }
    
    // MARK: - Hotkey Registration
    
    private func registerHotkey(keyCode: UInt32, modifiers: UInt32, id: UInt32, hotkeyRef: inout EventHotKeyRef?) {
        var hotKeyID = EventHotKeyID(signature: OSType(0x5345), id: id) // 'SE' pour Secretino
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotkeyRef)
        
        if status != noErr {
            print("❌ Erreur enregistrement raccourci \(id): \(status)")
        }
    }
    
    // MARK: - Event Handling
    
    private func handleHotKeyEvent(event: EventRef) {
        var hotKeyID = EventHotKeyID()
        GetEventParameter(event,
                         EventParamName(kEventParamDirectObject),
                         EventParamType(typeEventHotKeyID),
                         nil,
                         MemoryLayout<EventHotKeyID>.size,
                         nil,
                         &hotKeyID)
        
        switch hotKeyID.id {
        case 1:
            print("🔒 Raccourci chiffrement activé")
            processSelectedText(encrypt: true)
        case 2:
            print("🔓 Raccourci déchiffrement activé")
            processSelectedText(encrypt: false)
        default:
            break
        }
    }
    
    // MARK: - Text Processing
    
    func processSelectedText(encrypt: Bool) {
        // Vérifier qu'on a une passphrase
        guard !currentPassphrase.isEmpty else {
            showNotification(title: "Secretino",
                           message: "Définissez d'abord une passphrase dans l'app")
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
                self.showNotification(title: "Secretino",
                                    message: "Aucun texte sélectionné")
                // Restaurer le presse-papiers original
                if let original = originalContents {
                    pasteboard.clearContents()
                    pasteboard.setString(original, forType: .string)
                }
                return
            }
            
            // Traiter le texte
            let processedText = self.processText(selectedText, encrypt: encrypt)
            
            if let result = processedText {
                // Mettre le résultat dans le presse-papiers
                pasteboard.clearContents()
                pasteboard.setString(result, forType: .string)
                
                // Simuler Cmd+V pour coller
                self.simulateKeyPress(keyCode: CGKeyCode(kVK_ANSI_V), flags: .maskCommand)
                
                // Notification de succès
                self.showNotification(title: "Secretino",
                                    message: encrypt ? "Texte chiffré ✅" : "Texte déchiffré ✅")
                
                // Restaurer le presse-papiers après un délai
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if let original = originalContents {
                        pasteboard.clearContents()
                        pasteboard.setString(original, forType: .string)
                    }
                }
            } else {
                // Erreur de traitement
                self.showNotification(title: "Secretino",
                                    message: "Erreur: \(self.lastError)")
                // Restaurer le presse-papiers
                if let original = originalContents {
                    pasteboard.clearContents()
                    pasteboard.setString(original, forType: .string)
                }
            }
        }
    }
    
    private func processText(_ text: String, encrypt: Bool) -> String? {
        if encrypt {
            // Chiffrer
            if let result = swift_encrypt_data(text, currentPassphrase) {
                let cryptoResult = result.pointee
                if cryptoResult.success == 1 {
                    if let base64 = swift_base64_encode(cryptoResult.data, Int32(cryptoResult.length)) {
                        let encryptedText = String(cString: base64)
                        free(base64)
                        free_crypto_result(result)
                        return encryptedText
                    }
                } else {
                    lastError = String(cString: cryptoResult.error_message)
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
                                                             currentPassphrase) {
                        let decryptData = decryptResult.pointee
                        if decryptData.success == 1 {
                            let decryptedText = String(cString: decryptData.data)
                            free_crypto_result(decryptResult)
                            free_crypto_result(decodeResult)
                            return decryptedText
                        } else {
                            lastError = String(cString: decryptData.error_message)
                        }
                        free_crypto_result(decryptResult)
                    }
                }
                free_crypto_result(decodeResult)
            }
        }
        return nil
    }
    
    // MARK: - Keyboard Simulation
    
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
    
    // MARK: - Notifications
    
    private func showNotification(title: String, message: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = message
        notification.soundName = nil // Pas de son
        
        NSUserNotificationCenter.default.deliver(notification)
        
        // Auto-dismiss après 2 secondes
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            NSUserNotificationCenter.default.removeDeliveredNotification(notification)
        }
    }
}

// Extension pour les flags Carbon
extension GlobalHotKeyManager {
    // Convertir les modifiers Carbon en CGEventFlags
    private func carbonToCGFlags(_ carbonFlags: UInt32) -> CGEventFlags {
        var flags: CGEventFlags = []
        
        if carbonFlags & UInt32(cmdKey) != 0 {
            flags.insert(.maskCommand)
        }
        if carbonFlags & UInt32(optionKey) != 0 {
            flags.insert(.maskAlternate)
        }
        if carbonFlags & UInt32(shiftKey) != 0 {
            flags.insert(.maskShift)
        }
        if carbonFlags & UInt32(controlKey) != 0 {
            flags.insert(.maskControl)
        }
        
        return flags
    }
}
