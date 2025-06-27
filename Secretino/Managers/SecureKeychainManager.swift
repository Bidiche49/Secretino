//
//  SecureKeychainManager.swift
//  Secretino
//
//  Gestionnaire sécurisé pour le stockage des passphrases avec Keychain
//

import Foundation
import Security
import CryptoKit
import LocalAuthentication

class SecureKeychainManager {
    static let shared = SecureKeychainManager()
    
    private enum KeychainError: Error {
        case itemNotFound
        case duplicateItem
        case invalidData
        case biometryNotAvailable
        case userCancel
        case authenticationFailed
        case unexpectedError(OSStatus)
    }
    
    private enum KeychainKeys {
        static let service = "com.nztd.Secretino"
        static let globalPassphraseKey = "globalPassphrase"
        static let passphraseHashKey = "passphraseHash"
    }
    
    private init() {}
    
    // MARK: - Secure Passphrase Storage
    
    /// Stocke la passphrase de manière sécurisée avec protection biométrique
    func storeGlobalPassphrase(_ passphrase: String) throws {
        // Générer un hash pour vérification sans stocker la passphrase en clair
        let passphraseData = passphrase.data(using: .utf8)!
        let hash = SHA256.hash(data: passphraseData)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        
        // Supprimer l'ancienne entrée si elle existe
        try? deleteGlobalPassphrase()
        
        // Vérifier si l'app est en mode debug/development
        #if DEBUG
        print("⚠️ Mode Debug - Stockage sans biométrie pour le développement")
        // En mode debug, stocker sans biométrie pour faciliter les tests
        let passphraseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KeychainKeys.service,
            kSecAttrAccount as String: KeychainKeys.globalPassphraseKey,
            kSecValueData as String: passphraseData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        #else
        // En production, utiliser la biométrie
        // Créer l'access control avec biométrie obligatoire
        var error: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.biometryCurrentSet],
            &error
        ) else {
            if let error = error?.takeRetainedValue() {
                print("❌ Erreur création access control: \(error)")
            }
            throw KeychainError.biometryNotAvailable
        }
        
        let passphraseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KeychainKeys.service,
            kSecAttrAccount as String: KeychainKeys.globalPassphraseKey,
            kSecValueData as String: passphraseData,
            kSecAttrAccessControl as String: accessControl
        ]
        #endif
        
        let passphraseStatus = SecItemAdd(passphraseQuery as CFDictionary, nil)
        
        if passphraseStatus == errSecDuplicateItem {
            // Si l'élément existe déjà, le supprimer et réessayer
            try? deleteGlobalPassphrase()
            let retryStatus = SecItemAdd(passphraseQuery as CFDictionary, nil)
            if retryStatus != errSecSuccess {
                print("❌ Erreur Keychain retry: \(retryStatus)")
                throw KeychainError.unexpectedError(retryStatus)
            }
        } else if passphraseStatus != errSecSuccess {
            print("❌ Erreur Keychain: \(passphraseStatus)")
            // Afficher plus d'informations sur l'erreur
            if passphraseStatus == -34018 {
                print("❌ Erreur -34018: Vérifiez les entitlements et le profil de provisioning")
                print("   - Bundle ID: \(Bundle.main.bundleIdentifier ?? "inconnu")")
                print("   - Keychain access groups: \(getKeychainAccessGroups())")
            }
            throw KeychainError.unexpectedError(passphraseStatus)
        }
        
        // Stocker le hash séparément (sans biométrie) pour vérification rapide
        let hashQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KeychainKeys.service,
            kSecAttrAccount as String: KeychainKeys.passphraseHashKey,
            kSecValueData as String: hashString.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let hashStatus = SecItemAdd(hashQuery as CFDictionary, nil)
        if hashStatus != errSecSuccess && hashStatus != errSecDuplicateItem {
            // Si le hash échoue, nettoyer la passphrase aussi
            try? deleteGlobalPassphrase()
            throw KeychainError.unexpectedError(hashStatus)
        }
        
        print("✅ Passphrase stockée de manière sécurisée avec protection biométrique")
    }
    
    /// Récupère la passphrase avec authentification biométrique
    func loadGlobalPassphrase() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KeychainKeys.service,
            kSecAttrAccount as String: KeychainKeys.globalPassphraseKey,
            kSecReturnData as String: true,
            kSecUseOperationPrompt as String: "Authentifiez-vous pour accéder à votre passphrase Secretino"
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        switch status {
        case errSecSuccess:
            guard let data = dataTypeRef as? Data,
                  let passphrase = String(data: data, encoding: .utf8) else {
                throw KeychainError.invalidData
            }
            return passphrase
            
        case errSecItemNotFound:
            throw KeychainError.itemNotFound
            
        case -128: // errSecUserCancel
            throw KeychainError.userCancel
            
        case errSecAuthFailed:
            throw KeychainError.authenticationFailed
            
        default:
            print("❌ Erreur Keychain load: \(status)")
            throw KeychainError.unexpectedError(status)
        }
    }
    
    /// Vérifie si une passphrase est stockée (sans déclencher la biométrie)
    func hasGlobalPassphrase() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KeychainKeys.service,
            kSecAttrAccount as String: KeychainKeys.passphraseHashKey,
            kSecReturnData as String: false
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Supprime la passphrase stockée
    func deleteGlobalPassphrase() throws {
        // Supprimer la passphrase
        let passphraseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KeychainKeys.service,
            kSecAttrAccount as String: KeychainKeys.globalPassphraseKey
        ]
        
        let passphraseStatus = SecItemDelete(passphraseQuery as CFDictionary)
        
        // Supprimer le hash
        let hashQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KeychainKeys.service,
            kSecAttrAccount as String: KeychainKeys.passphraseHashKey
        ]
        
        _ = SecItemDelete(hashQuery as CFDictionary)
        
        // Nettoyer aussi les anciennes préférences UserDefaults si elles existent
        UserDefaults.standard.removeObject(forKey: "secretino_has_passphrase")
        UserDefaults.standard.removeObject(forKey: "secretino_temp_passphrase")
        
        if passphraseStatus != errSecSuccess && passphraseStatus != errSecItemNotFound {
            throw KeychainError.unexpectedError(passphraseStatus)
        }
        
        print("✅ Passphrase supprimée de manière sécurisée")
    }
    
    /// Vérifie si la biométrie est disponible
    func isBiometryAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    /// Nettoie toutes les données sensibles de l'app (pour désinstallation)
    func cleanupAllSecureData() {
        try? deleteGlobalPassphrase()
        
        // Nettoyer toutes les préférences
        let keys = [
            "secretino_has_passphrase",
            "secretino_temp_passphrase",
            "useGlobalHotkeys",
            "secretino_last_version",
            "hasRequestedAccessibility",
            "hasShownWelcome"
        ]
        
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        UserDefaults.standard.synchronize()
        print("🧹 Nettoyage complet des données sécurisées")
    }
    
    // MARK: - Debug Helpers
    
    /// Obtient les groupes d'accès Keychain pour debug
    private func getKeychainAccessGroups() -> [String] {
        #if DEBUG
        // En debug, afficher les groupes d'accès
        if let groups = Bundle.main.object(forInfoDictionaryKey: "keychain-access-groups") as? [String] {
            return groups
        }
        #endif
        return []
    }
}

// MARK: - Error Handling Extensions
extension SecureKeychainManager {
    func handleKeychainError(_ error: Error) -> String {
        guard let keychainError = error as? KeychainError else {
            return "Erreur inconnue: \(error.localizedDescription)"
        }
        
        switch keychainError {
        case .itemNotFound:
            return "Aucune passphrase configurée"
        case .duplicateItem:
            return "Passphrase déjà configurée"
        case .invalidData:
            return "Données corrompues"
        case .biometryNotAvailable:
            return "Touch ID/Face ID non disponible"
        case .userCancel:
            return "Authentification annulée"
        case .authenticationFailed:
            return "Échec de l'authentification"
        case .unexpectedError(let status):
            switch status {
            case -34018:
                return "Erreur de configuration. Vérifiez les entitlements de l'app dans Xcode."
            case -25308:
                return "Erreur d'autorisation. Redémarrez l'app."
            default:
                return "Erreur Keychain: \(status)"
            }
        }
    }
}
