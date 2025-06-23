//
//  SelectionCryptoService.swift
//  Secretino
//
//  Service pour chiffrer/déchiffrer le texte sélectionné dans n'importe quelle app
//

import Cocoa

class SelectionCryptoService: ObservableObject {
    @Published var globalPassphrase: String = ""
    @Published var isEncryptingByDefault: Bool = true
    
    // Référence au gestionnaire de raccourcis
    private let hotkeyManager = GlobalHotkeyManager()
    
    init() {
        setupHotkeyCallbacks()
    }
    
    private func setupHotkeyCallbacks() {
        hotkeyManager.onEncryptSelection = { [weak self] in
            self?.encryptSelectedText()
        }
        
        hotkeyManager.onDecryptSelection = { [weak self] in
            self?.decryptSelectedText()
        }
    }
    
    // MARK: - Actions principales
    
    private func encryptSelectedText() {
        print("🔐 Début chiffrement sélection...")
        
        guard !globalPassphrase.isEmpty else {
            showNotification(title: "Passphrase manquante", message: "Configurez votre passphrase dans Secretino")
            return
        }
        
        processSelectedText(encrypt: true)
    }
    
    private func decryptSelectedText() {
        print("🔓 Début déchiffrement sélection...")
        
        guard !globalPassphrase.isEmpty else {
            showNotification(title: "Passphrase manquante", message: "Configurez votre passphrase dans Secretino")
            return
        }
        
        processSelectedText(encrypt: false)
    }
    
    // MARK: - Traitement du texte
    
    private func processSelectedText(encrypt: Bool) {
        // Étape 1: Sauvegarder le presse-papiers actuel
        let originalClipboard = getClipboardContent()
        
        // Étape 2: Copier la sélection (Cmd+C)
        copySelection()
        
        // Étape 3: Attendre un peu que la copie se fasse
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.processClipboardContent(encrypt: encrypt, originalClipboard: originalClipboard)
        }
    }
    
    private func processClipboardContent(encrypt: Bool, originalClipboard: String?) {
        guard let selectedText = getClipboardContent(), !selectedText.isEmpty else {
            showNotification(title: "Erreur", message: "Aucun texte sélectionné")
            restoreClipboard(originalClipboard)
            return
        }
        
        // Traitement crypto
        let result: String
        if encrypt {
            result = performEncryption(text: selectedText)
        } else {
            result = performDecryption(text: selectedText)
        }
        
        if !result.isEmpty {
            // Remplacer dans le presse-papiers
            setClipboardContent(result)
            
            // Coller automatiquement (Cmd+V)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.pasteFromClipboard()
                
                // Restaurer le presse-papiers original après 1 seconde
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.restoreClipboard(originalClipboard)
                }
            }
            
            let action = encrypt ? "chiffré" : "déchiffré"
            showNotification(title: "Secretino", message: "Texte \(action) avec succès!")
        }
    }
    
    // MARK: - Fonctions crypto
    
    private func performEncryption(text: String) -> String {
        if let result = swift_encrypt_data(text, globalPassphrase) {
            let cryptoResult = result.pointee
            if cryptoResult.success == 1 {
                if let base64 = swift_base64_encode(cryptoResult.data, Int32(cryptoResult.length)) {
                    let encodedText = String(cString: base64)
                    free(base64)
                    free_crypto_result(result)
                    return encodedText
                }
            } else {
                let errorMsg = String(cString: cryptoResult.error_message)
                showNotification(title: "Erreur chiffrement", message: errorMsg)
            }
            free_crypto_result(result)
        }
        return ""
    }
    
    private func performDecryption(text: String) -> String {
        if let decodeResult = swift_base64_decode(text) {
            let decodedData = decodeResult.pointee
            if decodedData.success == 1 {
                if let decryptResult = swift_decrypt_data(decodedData.data, Int32(decodedData.length), globalPassphrase) {
                    let decryptData = decryptResult.pointee
                    if decryptData.success == 1 {
                        let decryptedText = String(cString: decryptData.data)
                        free_crypto_result(decryptResult)
                        free_crypto_result(decodeResult)
                        return decryptedText
                    } else {
                        let errorMsg = String(cString: decryptData.error_message)
                        showNotification(title: "Erreur déchiffrement", message: errorMsg)
                    }
                    free_crypto_result(decryptResult)
                }
            } else {
                showNotification(title: "Erreur", message: "Format Base64 invalide")
            }
            free_crypto_result(decodeResult)
        }
        return ""
    }
    
    // MARK: - Utilitaires presse-papiers et clavier
    
    private func getClipboardContent() -> String? {
        return NSPasteboard.general.string(forType: .string)
    }
    
    private func setClipboardContent(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    private func restoreClipboard(_ originalContent: String?) {
        if let original = originalContent {
            setClipboardContent(original)
        }
    }
    
    private func copySelection() {
        // Simuler Cmd+C
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Appuyer sur Cmd+C
        let cmdCDown = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true) // C key
        cmdCDown?.flags = .maskCommand
        let cmdCUp = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false)
        cmdCUp?.flags = .maskCommand
        
        cmdCDown?.post(tap: .cghidEventTap)
        cmdCUp?.post(tap: .cghidEventTap)
    }
    
    private func pasteFromClipboard() {
        // Simuler Cmd+V
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Appuyer sur Cmd+V
        let cmdVDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true) // V key
        cmdVDown?.flags = .maskCommand
        let cmdVUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        cmdVUp?.flags = .maskCommand
        
        cmdVDown?.post(tap: .cghidEventTap)
        cmdVUp?.post(tap: .cghidEventTap)
    }
    
    private func showNotification(title: String, message: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = message
        notification.soundName = NSUserNotificationDefaultSoundName
        
        NSUserNotificationCenter.default.deliver(notification)
    }
}
