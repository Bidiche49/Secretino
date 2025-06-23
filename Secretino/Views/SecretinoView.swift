//
//  SecretinoView.swift
//  Secretino
//
//  Interface principale de Secretino avec raccourcis clavier
//

import SwiftUI

struct SecretinoView: View {
    @State private var inputText: String = ""
    @State private var outputText: String = ""
    @State private var passphrase: String = ""
    @State private var isEncrypting: Bool = true
    @State private var overlayMessage: String = ""
    @State private var showOverlay: Bool = false
    @State private var statusMessage: String = ""
    @State private var showStatus: Bool = false
    @FocusState private var isTextFieldFocused: Bool
    
    // Référence au service de cryptage global (OPTIONNEL)
    let selectionCryptoService: SelectionCryptoService?
    
    // Constructeur avec paramètre OPTIONNEL
    init(selectionCryptoService: SelectionCryptoService? = nil) {
        self.selectionCryptoService = selectionCryptoService
    }
    
    // Types d'overlay pour les erreurs uniquement
    enum OverlayType {
        case error
        
        var color: Color {
            return .red
        }
        
        var icon: String {
            return "xmark.circle.fill"
        }
    }
    
    var body: some View {
        ZStack {
            // Interface principale avec scroll conditionnel mais layout fixe
            ScrollView {
                contentView
            }
            .frame(width: 360, height: 500)
            .scrollDisabled(outputText.isEmpty) // Désactive le scroll quand pas de résultat
            .blur(radius: showOverlay ? 2 : 0)
            .animation(.easeInOut(duration: 0.2), value: showOverlay)
            
            // Overlay de premier plan (inchangé)
            if showOverlay {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissOverlay()
                    }
                
                VStack(spacing: 16) {
                    Image(systemName: OverlayType.error.icon)
                        .font(.system(size: 50, weight: .medium))
                        .foregroundColor(OverlayType.error.color)
                    
                    Text(overlayMessage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .frame(width: 280, height: 160)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                )
                .scaleEffect(showOverlay ? 1.0 : 0.8)
                .opacity(showOverlay ? 1.0 : 0.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showOverlay)
            }
        }
    }
    
    // Contenu principal avec hauteur stable
    private var contentView: some View {
        VStack(spacing: 20) {
            // Header (position fixe)
            VStack {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                
                Text("Secretino")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Cryptage militaire AES-256-GCM")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top)
            
            Divider()
            
            // Mode selection (position fixe) avec synchronisation
            Picker("Mode", selection: $isEncrypting) {
                Text("🔒 Chiffrer").tag(true)
                Text("🔓 Déchiffrer").tag(false)
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: isEncrypting) { newValue in
                // Synchroniser le mode par défaut pour les raccourcis globaux (si disponible)
                selectionCryptoService?.isEncryptingByDefault = newValue
            }
            
            // Passphrase (position fixe) avec synchronisation
            VStack(alignment: .leading) {
                Text("Passphrase")
                    .font(.headline)
                
                SecureField("Entrez votre passphrase", text: $passphrase)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: passphrase) { newValue in
                        // Synchroniser avec le service global (si disponible)
                        selectionCryptoService?.globalPassphrase = newValue
                    }
                    .onAppear {
                        // Initialiser depuis le service global (si disponible)
                        if let service = selectionCryptoService {
                            passphrase = service.globalPassphrase
                            isEncrypting = service.isEncryptingByDefault
                        }
                    }
            }
            
            // Input text avec design amélioré
            VStack(alignment: .leading) {
                Text(isEncrypting ? "Texte à chiffrer" : "Texte chiffré (Base64)")
                    .font(.headline)
                
                ZStack(alignment: .topTrailing) {
                    TextEditor(text: $inputText)
                        .focused($isTextFieldFocused)
                        .padding(8) // Marge interne pour le texte
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isTextFieldFocused ? Color.blue.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .frame(height: 100)
                    
                    // Bouton clear (petite croix)
                    if !inputText.isEmpty {
                        Button(action: {
                            clearInputText()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                                .background(Color(NSColor.textBackgroundColor))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.top, 8)
                        .padding(.trailing, 8)
                    }
                }
            }
            
            // Action buttons avec nouvelle disposition
            VStack(spacing: 12) {
                // Ligne principale : Coller+Action et Copier
                HStack {
                    Button(action: {
                        pasteAndProcess()
                    }) {
                        HStack {
                            Image(systemName: "doc.on.clipboard")
                            Text("Coller & \(isEncrypting ? "Chiffrer" : "Déchiffrer")")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(passphrase.isEmpty)
                    .keyboardShortcut("v", modifiers: .command)
                    
                    Button(action: {
                        copyToClipboard()
                    }) {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("Copier")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(outputText.isEmpty)
                    .keyboardShortcut("c", modifiers: .command)
                }
                
                // Ligne secondaire : Action manuel et Clear
                HStack {
                    Button(action: {
                        processText()
                    }) {
                        HStack {
                            Image(systemName: isEncrypting ? "lock.fill" : "lock.open.fill")
                            Text(isEncrypting ? "Chiffrer" : "Déchiffrer")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(inputText.isEmpty || passphrase.isEmpty)
                    
                    Button(action: {
                        clearResult()
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Effacer")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(outputText.isEmpty)
                }
            }
            
            // Espace réservé pour le message de statut (hauteur fixe)
            VStack {
                if showStatus {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundColor(.green)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.3), value: showStatus)
                } else {
                    Text(" ") // Espace réservé invisible
                        .font(.caption)
                }
            }
            .frame(height: 20) // Hauteur fixe réservée
            
            // Raccourcis globaux info (seulement si service disponible)
            if !passphrase.isEmpty && selectionCryptoService != nil {
                VStack(spacing: 6) {
                    Text("Raccourcis globaux actifs:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 12) {
                        VStack(spacing: 2) {
                            Text("⌘⇧E")
                                .font(.caption2)
                                .fontFamily(.monospaced)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.green.opacity(0.15))
                                .foregroundColor(.green)
                                .cornerRadius(4)
                            
                            Text("Chiffrer")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "globe")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        VStack(spacing: 2) {
                            Text("⌘⇧D")
                                .font(.caption2)
                                .fontFamily(.monospaced)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.orange.opacity(0.15))
                                .foregroundColor(.orange)
                                .cornerRadius(4)
                            
                            Text("Déchiffrer")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            
            // Espace réservé pour Output text (hauteur dynamique mais stable)
            VStack(alignment: .leading) {
                if !outputText.isEmpty {
                    HStack {
                        Text("Résultat")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: {
                            clearResult()
                        }) {
                            Image(systemName: "xmark.circle")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    Text(outputText)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .fixedSize(horizontal: false, vertical: true) // Permet expansion verticale
                }
            }
            .frame(minHeight: 0) // Permet de commencer à hauteur 0
            .animation(.easeInOut(duration: 0.3), value: outputText.isEmpty)
            
            // Spacer pour maintenir la hauteur minimale
            Spacer(minLength: !outputText.isEmpty ? 20 : 100) // Plus grand spacer quand pas de résultat
        }
        .padding()
    }
    
    private func copyFromClipboard() {
        let pasteboard = NSPasteboard.general
        if let clipboardText = pasteboard.string(forType: .string), !clipboardText.isEmpty {
            inputText = clipboardText
            showStatusMessage("Texte collé")
        } else {
            showErrorOverlay("Presse-papiers vide")
        }
    }
    
    private func pasteAndProcess() {
        let pasteboard = NSPasteboard.general
        if let clipboardText = pasteboard.string(forType: .string), !clipboardText.isEmpty {
            inputText = clipboardText
            
            // Vérifier si passphrase est remplie
            if passphrase.isEmpty {
                showErrorOverlay("Passphrase requise")
                return
            }
            
            // Traitement automatique
            if isEncrypting {
                encryptText()
            } else {
                decryptText()
            }
        } else {
            showErrorOverlay("Presse-papiers vide")
        }
    }
    
    private func copyToClipboard() {
        guard !outputText.isEmpty else {
            showErrorOverlay("Aucun résultat à copier")
            return
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(outputText, forType: .string)
        
        showStatusMessage("Copié dans le presse-papiers")
    }
    
    private func clearInputText() {
        withAnimation(.easeInOut(duration: 0.2)) {
            inputText = ""
        }
    }
    
    private func clearResult() {
        withAnimation(.easeInOut(duration: 0.3)) {
            outputText = ""
        }
        showStatusMessage("Résultat effacé")
    }
    
    private func processText() {
        guard !inputText.isEmpty && !passphrase.isEmpty else { return }
        
        if isEncrypting {
            encryptText()
        } else {
            decryptText()
        }
    }
    
    private func encryptText() {
        if let result = swift_encrypt_data(inputText, passphrase) {
            let cryptoResult = result.pointee
            if cryptoResult.success == 1 {
                if let base64 = swift_base64_encode(cryptoResult.data, Int32(cryptoResult.length)) {
                    outputText = String(cString: base64)
                    free(base64)
                    showStatusMessage("Texte chiffré avec succès")
                } else {
                    showErrorOverlay("Erreur encodage Base64")
                }
            } else {
                let errorMsg = String(cString: cryptoResult.error_message)
                showErrorOverlay("Erreur: \(errorMsg)")
            }
            free_crypto_result(result)
        }
    }
    
    private func decryptText() {
        if let decodeResult = swift_base64_decode(inputText) {
            let decodedData = decodeResult.pointee
            if decodedData.success == 1 {
                if let decryptResult = swift_decrypt_data(decodedData.data, Int32(decodedData.length), passphrase) {
                    let decryptData = decryptResult.pointee
                    if decryptData.success == 1 {
                        outputText = String(cString: decryptData.data)
                        showStatusMessage("Texte déchiffré avec succès")
                    } else {
                        let errorMsg = String(cString: decryptData.error_message)
                        showErrorOverlay("Déchiffrement échoué: \(errorMsg)")
                    }
                    free_crypto_result(decryptResult)
                } else {
                    showErrorOverlay("Erreur lors du déchiffrement")
                }
            } else {
                let errorMsg = String(cString: decodedData.error_message)
                showErrorOverlay("Base64 invalide: \(errorMsg)")
            }
            free_crypto_result(decodeResult)
        }
    }
    
    // Fonction pour afficher un petit texte de statut (succès)
    private func showStatusMessage(_ message: String) {
        statusMessage = message
        
        withAnimation(.easeInOut(duration: 0.2)) {
            showStatus = true
        }
        
        // Auto-dismiss après 1 seconde
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showStatus = false
            }
        }
    }
    
    // Fonction pour afficher l'overlay d'erreur (erreurs uniquement)
    private func showErrorOverlay(_ message: String) {
        overlayMessage = message
        
        withAnimation {
            showOverlay = true
        }
        
        // Auto-dismiss après 1 seconde
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            dismissOverlay()
        }
    }
    
    private func dismissOverlay() {
        withAnimation {
            showOverlay = false
        }
    }
}

#Preview {
    // Preview sans service
    SecretinoView()
}
