//
//  SecretinoView.swift
//  Secretino
//
//  Interface principale de Secretino
//

import SwiftUI

struct SecretinoView: View {
    @State private var inputText: String = ""
    @State private var outputText: String = ""
    @State private var passphrase: String = ""
    @State private var isEncrypting: Bool = true
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
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
            
            // Mode selection
            Picker("Mode", selection: $isEncrypting) {
                Text("🔒 Chiffrer").tag(true)
                Text("🔓 Déchiffrer").tag(false)
            }
            .pickerStyle(SegmentedPickerStyle())
            
            // Passphrase
            VStack(alignment: .leading) {
                Text("Passphrase")
                    .font(.headline)
                
                SecureField("Entrez votre passphrase", text: $passphrase)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            // Input text
            VStack(alignment: .leading) {
                Text(isEncrypting ? "Texte à chiffrer" : "Texte chiffré (Base64)")
                    .font(.headline)
                
                TextEditor(text: $inputText)
                    .frame(height: 100)
                    .border(Color.gray.opacity(0.3), width: 1)
                    .cornerRadius(5)
            }
            
            // Action buttons
            HStack {
                Button(action: {
                    copyFromClipboard()
                }) {
                    Label("Coller", systemImage: "doc.on.clipboard")
                }
                
                Spacer()
                
                Button(action: {
                    processText()
                }) {
                    Label(isEncrypting ? "Chiffrer" : "Déchiffrer",
                          systemImage: isEncrypting ? "lock.fill" : "lock.open.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(inputText.isEmpty || passphrase.isEmpty)
                
                Spacer()
                
                Button(action: {
                    copyToClipboard()
                }) {
                    Label("Copier", systemImage: "doc.on.doc")
                }
                .disabled(outputText.isEmpty)
            }
            
            // Output text
            if !outputText.isEmpty {
                VStack(alignment: .leading) {
                    Text("Résultat")
                        .font(.headline)
                    
                    ScrollView {
                        Text(outputText)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(5)
                    }
                    .frame(height: 80)
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 360, height: 500)
        .alert("Secretino", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func copyFromClipboard() {
        let pasteboard = NSPasteboard.general
        inputText = pasteboard.string(forType: .string) ?? ""
    }
    
    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(outputText, forType: .string)
        
        showAlert(message: "Résultat copié dans le presse-papiers!")
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
                    showAlert(message: "Texte chiffré avec succès!")
                } else {
                    showAlert(message: "Erreur lors de l'encodage Base64")
                }
            } else {
                let errorMsg = String(cString: cryptoResult.error_message)
                showAlert(message: "Erreur de chiffrement: \(errorMsg)")
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
                        showAlert(message: "Texte déchiffré avec succès!")
                    } else {
                        let errorMsg = String(cString: decryptData.error_message)
                        showAlert(message: "Erreur de déchiffrement: \(errorMsg)")
                    }
                    free_crypto_result(decryptResult)
                } else {
                    showAlert(message: "Erreur lors du déchiffrement")
                }
            } else {
                let errorMsg = String(cString: decodedData.error_message)
                showAlert(message: "Erreur de décodage Base64: \(errorMsg)")
            }
            free_crypto_result(decodeResult)
        }
    }
    
    private func showAlert(message: String) {
        alertMessage = message
        showAlert = true
    }
}

#Preview {
    SecretinoView()
}
