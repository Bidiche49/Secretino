//
//  GlobalHotkeyManager.swift
//  Secretino
//
//  Gestionnaire des raccourcis clavier globaux pour chiffrer/déchiffrer le texte sélectionné
//

import Cocoa
import Carbon

class GlobalHotkeyManager: ObservableObject {
    private var encryptHotkeyRef: EventHotKeyRef?
    private var decryptHotkeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    
    // Callbacks pour les actions crypto
    var onEncryptSelection: (() -> Void)?
    var onDecryptSelection: (() -> Void)?
    
    // Configuration des raccourcis (modifiable)
    struct HotkeyConfig {
        static let encryptKey: UInt32 = UInt32(kVK_ANSI_E)  // Cmd+Shift+E pour chiffrer
        static let decryptKey: UInt32 = UInt32(kVK_ANSI_D)  // Cmd+Shift+D pour déchiffrer
        static let modifiers: UInt32 = UInt32(cmdKey + shiftKey)  // Cmd+Shift
    }
    
    init() {
        setupGlobalHotkeys()
    }
    
    deinit {
        removeGlobalHotkeys()
    }
    
    private func setupGlobalHotkeys() {
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
        
        print("🔥 Raccourcis globaux configurés:")
        print("   ⌘+⇧+E : Chiffrer la sélection")
        print("   ⌘+⇧+D : Déchiffrer la sélection")
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
        } else {
            print("✅ Raccourci \(id) enregistré")
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
                    manager.onEncryptSelection?()
                }
            case 2: // Déchiffrer
                print("🔓 Raccourci déchiffrement détecté")
                DispatchQueue.main.async {
                    manager.onDecryptSelection?()
                }
            default:
                break
            }
        }
        
        return OSStatus(noErr)
    }
    
    private func removeGlobalHotkeys() {
        if let encryptRef = encryptHotkeyRef {
            UnregisterEventHotKey(encryptRef)
        }
        if let decryptRef = decryptHotkeyRef {
            UnregisterEventHotKey(decryptRef)
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
        
        print("🧹 Raccourcis globaux supprimés")
    }
}

// Extension pour fourCharCode
private func fourCharCode(_ string: String) -> FourCharCode {
    assert(string.count == 4)
    var result: FourCharCode = 0
    for char in string.utf8 {
        result = (result << 8) + FourCharCode(char)
    }
    return result
}
