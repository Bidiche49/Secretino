////
////  SettingsView.swift
////  Secretino
////
////  Vue de configuration pour les raccourcis globaux et la passphrase
////
//
//import SwiftUI
//
//struct SettingsView: View {
//    @StateObject private var hotkeyManager = GlobalHotKeyManager.shared
//    @State private var globalPassphrase: String = ""
//    @State private var confirmPassphrase: String = ""
//    @State private var showPassphraseAlert: Bool = false
//    @State private var alertMessage: String = ""
//    @AppStorage("useGlobalHotkeys") private var useGlobalHotkeys: Bool = false
//    @AppStorage("hasGlobalPassphrase") private var hasGlobalPassphrase: Bool = false
//    
//    var body: some View {
//        VStack(spacing: 20) {
//            // Header
//            VStack(spacing: 8) {
//                Image(systemName: "keyboard.badge.ellipsis")
//                    .font(.system(size: 40))
//                    .foregroundColor(.blue)
//                
//                Text("Raccourcis Globaux")
//                    .font(.title2)
//                    .fontWeight(.bold)
//                
//                Text("Chiffrez/déchiffrez dans n'importe quelle app")
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//            }
//            
//            Divider()
//            
//            // Passphrase globale
//            VStack(alignment: .leading, spacing: 12) {
//                Text("Passphrase Globale")
//                    .font(.headline)
//                
//                if hasGlobalPassphrase {
//                    HStack {
//                        Image(systemName: "checkmark.circle.fill")
//                            .foregroundColor(.green)
//                        Text("Passphrase définie")
//                            .foregroundColor(.secondary)
//                        Spacer()
//                        Button("Modifier") {
//                            hasGlobalPassphrase = false
//                            hotkeyManager.currentPassphrase = ""
//                        }
//                        .buttonStyle(.bordered)
//                    }
//                    .padding()
//                    .background(Color.green.opacity(0.1))
//                    .cornerRadius(8)
//                } else {
//                    VStack(spacing: 8) {
//                        SecureField("Nouvelle passphrase", text: $globalPassphrase)
//                            .textFieldStyle(RoundedBorderTextFieldStyle())
//                        
//                        SecureField("Confirmer passphrase", text: $confirmPassphrase)
//                            .textFieldStyle(RoundedBorderTextFieldStyle())
//                        
//                        Button("Définir passphrase") {
//                            setGlobalPassphrase()
//                        }
//                        .buttonStyle(.borderedProminent)
//                        .disabled(globalPassphrase.isEmpty || confirmPassphrase.isEmpty)
//                    }
//                }
//                
//                Text("⚠️ Cette passphrase sera utilisée pour tous les raccourcis globaux")
//                    .font(.caption)
//                    .foregroundColor(.orange)
//            }
//            
//            Divider()
//            
//            // Activation des raccourcis
//            VStack(alignment: .leading, spacing: 12) {
//                Toggle("Activer les raccourcis globaux", isOn: $useGlobalHotkeys)
//                    .disabled(!hasGlobalPassphrase)
//                    .onChange(of: useGlobalHotkeys) { newValue in
//                        toggleGlobalHotkeys(enabled: newValue)
//                    }
//                
//                if useGlobalHotkeys {
//                    VStack(alignment: .leading, spacing: 8) {
//                        Label("⌘⌥E : Chiffrer la sélection", systemImage: "lock.fill")
//                            .font(.system(.body, design: .monospaced))
//                        Label("⌘⌥D : Déchiffrer la sélection", systemImage: "lock.open.fill")
//                            .font(.system(.body, design: .monospaced))
//                    }
//                    .padding()
//                    .background(Color.blue.opacity(0.1))
//                    .cornerRadius(8)
//                }
//                
//                Text("Les raccourcis fonctionnent dans toutes les applications")
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//            }
//            
//            Divider()
//            
//            // Instructions
//            VStack(alignment: .leading, spacing: 8) {
//                Text("Comment utiliser :")
//                    .font(.headline)
//                
//                VStack(alignment: .leading, spacing: 4) {
//                    Text("1. Sélectionnez du texte dans n'importe quelle app")
//                    Text("2. Appuyez sur ⌘⌥E pour chiffrer")
//                    Text("3. Appuyez sur ⌘⌥D pour déchiffrer")
//                    Text("4. Le texte est automatiquement remplacé")
//                }
//                .font(.caption)
//                .foregroundColor(.secondary)
//            }
//            
//            // Permissions (toujours visible)
//            VStack(spacing: 8) {
//                if hasAccessibilityPermission() {
//                    HStack {
//                        Image(systemName: "checkmark.circle.fill")
//                            .foregroundColor(.green)
//                        Text("Permissions accordées")
//                            .font(.caption)
//                            .foregroundColor(.secondary)
//                    }
//                    .padding()
//                    .frame(maxWidth: .infinity)
//                    .background(Color.green.opacity(0.1))
//                    .cornerRadius(8)
//                } else {
//                    VStack(spacing: 8) {
//                        Label("Permissions requises", systemImage: "exclamationmark.triangle.fill")
//                            .foregroundColor(.orange)
//
//                        Text("Secretino nécessite l'accès à l'accessibilité pour les raccourcis globaux")
//                            .font(.caption)
//                            .multilineTextAlignment(.center)
//                            .lineLimit(nil)
//                            .fixedSize(horizontal: false, vertical: true)
//                            .frame(maxWidth: 300)
//
//                        Button("Ouvrir Préférences Système") {
//                            openAccessibilityPreferences()
//                        }
//                        .buttonStyle(.bordered)
//                    }
//                    .padding()
//                    .frame(maxWidth: 400)
//                    .background(Color.orange.opacity(0.1))
//                    .cornerRadius(8)
//                }
//
//            }
//            
//            Spacer(minLength: 20)
//        }
//        .padding()
//        .frame(width: 400, height: 720)
//        .alert("Passphrase", isPresented: $showPassphraseAlert) {
//            Button("OK") { }
//        } message: {
//            Text(alertMessage)
//        }
//        .onAppear {
//            // Charger l'état initial
//            if hasGlobalPassphrase && useGlobalHotkeys {
//                hotkeyManager.setupHotkeys()
//            }
//        }
//    }
//    
//    private func setGlobalPassphrase() {
//        guard !globalPassphrase.isEmpty else { return }
//        
//        if globalPassphrase != confirmPassphrase {
//            alertMessage = "Les passphrases ne correspondent pas"
//            showPassphraseAlert = true
//            return
//        }
//        
//        if globalPassphrase.count < 8 {
//            alertMessage = "La passphrase doit contenir au moins 8 caractères"
//            showPassphraseAlert = true
//            return
//        }
//        
//        // Stocker la passphrase dans le gestionnaire
//        hotkeyManager.currentPassphrase = globalPassphrase
//        hasGlobalPassphrase = true
//        
//        // Effacer les champs
//        globalPassphrase = ""
//        confirmPassphrase = ""
//        
//        alertMessage = "Passphrase définie avec succès"
//        showPassphraseAlert = true
//    }
//    
//    private func toggleGlobalHotkeys(enabled: Bool) {
//        if enabled {
//            hotkeyManager.setupHotkeys()
//        } else {
//            hotkeyManager.disableHotkeys()
//        }
//    }
//    
//    private func hasAccessibilityPermission() -> Bool {
//        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
//        return AXIsProcessTrustedWithOptions(options)
//    }
//    
//    private func openAccessibilityPreferences() {
//        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
//    }
//}
//
//// Preview
//struct SettingsView_Previews: PreviewProvider {
//    static var previews: some View {
//        SettingsView()
//    }
//}






//
//  SettingsView.swift
//  Secretino
//
//  Vue de configuration pour les raccourcis globaux et la passphrase
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var hotkeyManager = GlobalHotKeyManager.shared
    @State private var globalPassphrase: String = ""
    @State private var confirmPassphrase: String = ""
    @State private var showPassphraseAlert: Bool = false
    @State private var alertMessage: String = ""
    @AppStorage("useGlobalHotkeys") private var useGlobalHotkeys: Bool = false
    @AppStorage("hasGlobalPassphrase") private var hasGlobalPassphrase: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "keyboard.badge.ellipsis")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                
                Text("Raccourcis Globaux")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Chiffrez/déchiffrez dans n'importe quelle app")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Passphrase globale
            VStack(alignment: .leading, spacing: 12) {
                Text("Passphrase Globale")
                    .font(.headline)
                
                if hasGlobalPassphrase {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Passphrase définie")
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Modifier") {
                            hasGlobalPassphrase = false
                            hotkeyManager.currentPassphrase = ""
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                } else {
                    VStack(spacing: 8) {
                        SecureField("Nouvelle passphrase", text: $globalPassphrase)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        SecureField("Confirmer passphrase", text: $confirmPassphrase)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button("Définir passphrase") {
                            setGlobalPassphrase()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(globalPassphrase.isEmpty || confirmPassphrase.isEmpty)
                    }
                }
                
                Text("⚠️ Cette passphrase sera utilisée pour tous les raccourcis globaux")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            Divider()
            
            // Activation des raccourcis
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Activer les raccourcis globaux", isOn: $useGlobalHotkeys)
                    .disabled(!hasGlobalPassphrase)
                    .onChange(of: useGlobalHotkeys) { newValue in
                        toggleGlobalHotkeys(enabled: newValue)
                    }
                
                if useGlobalHotkeys {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("⌘⌥E : Chiffrer la sélection", systemImage: "lock.fill")
                            .font(.system(.body, design: .monospaced))
                        Label("⌘⌥D : Déchiffrer la sélection", systemImage: "lock.open.fill")
                            .font(.system(.body, design: .monospaced))
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Text("Les raccourcis fonctionnent dans toutes les applications")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Instructions
            VStack(alignment: .leading, spacing: 8) {
                Text("Comment utiliser :")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("1. Sélectionnez du texte dans n'importe quelle app")
                    Text("2. Appuyez sur ⌘⌥E pour chiffrer")
                    Text("3. Appuyez sur ⌘⌥D pour déchiffrer")
                    Text("4. Le texte est automatiquement remplacé")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            // Permissions (toujours visible)
            VStack(spacing: 8) {
                if checkAccessibilityPermissionWithoutPrompt() {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Permissions accordées")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                } else {
                    VStack(spacing: 8) {
                        Label("Permissions requises", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        
                        Text("Secretino nécessite l'accès à l'accessibilité pour les raccourcis globaux")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                        
                        HStack(spacing: 12) {
                            Button("Demander l'accès") {
                                // Force la demande avec prompt
                                PermissionsHelper.shared.triggerAccessibilityRequest()
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button("Instructions") {
                                PermissionsHelper.shared.showPermissionInstructions()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            Spacer(minLength: 20)
        }
        .padding()
        .frame(width: 400, height: 720)
        .alert("Passphrase", isPresented: $showPassphraseAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            // Charger l'état initial
            if hasGlobalPassphrase && useGlobalHotkeys {
                hotkeyManager.setupHotkeys()
            }
        }
    }
    
    private func setGlobalPassphrase() {
        guard !globalPassphrase.isEmpty else { return }
        
        if globalPassphrase != confirmPassphrase {
            alertMessage = "Les passphrases ne correspondent pas"
            showPassphraseAlert = true
            return
        }
        
        if globalPassphrase.count < 8 {
            alertMessage = "La passphrase doit contenir au moins 8 caractères"
            showPassphraseAlert = true
            return
        }
        
        // Stocker la passphrase dans le gestionnaire
        hotkeyManager.currentPassphrase = globalPassphrase
        hasGlobalPassphrase = true
        
        // Effacer les champs
        globalPassphrase = ""
        confirmPassphrase = ""
        
        alertMessage = "Passphrase définie avec succès"
        showPassphraseAlert = true
    }
    
    private func toggleGlobalHotkeys(enabled: Bool) {
        if enabled {
            hotkeyManager.setupHotkeys()
        } else {
            hotkeyManager.disableHotkeys()
        }
    }
    
    private func hasAccessibilityPermission() -> Bool {
        // Forcer la demande de permission au premier check
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options)
    }
    
    private func checkAccessibilityPermissionWithoutPrompt() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options)
    }
    
    private func openAccessibilityPreferences() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}

// Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
