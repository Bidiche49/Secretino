//
//  KeychainTester.swift
//  Secretino
//
//  Utilitaire pour tester l'accessibilité et les fonctions du Keychain
//

import Foundation
import Security
import LocalAuthentication
import LocalAuthentication

class KeychainTester: TestRunner {
    static let shared = KeychainTester()
    
    let testName = "Keychain"
    
    private init() {}
    
    func runTests() -> [TestResult] {
        print("🧪 === TESTS KEYCHAIN ===")
        
        var results: [TestResult] = []
        
        // Test 1: Accès basique
        results.append(testBasicKeychainAccess())
        
        // Test 2: Biométrie
        results.append(testBiometryAvailability())
        
        // Test 3: Contrôle d'accès
        results.append(testAccessControlKeychain())
        
        // Test 4: Permissions
        results.append(testKeychainPermissions())
        
        // Test 5: Secretino spécifique
        results.append(testSecretinoKeychain())
        
        return results
    }
    
    func cleanup() {
        // Nettoyer les données de test
        try? SecureKeychainManager.shared.deleteGlobalPassphrase()
    }
    
    /// Test d'accès basique au Keychain
    private func testBasicKeychainAccess() -> TestResult {
        print("1️⃣ Test d'accès basique au Keychain...")
        
        let testKey = "test_basic_key"
        let testValue = "test_basic_value"
        
        // Créer une entrée simple
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.nztd.Secretino.test",
            kSecAttrAccount as String: testKey,
            kSecValueData as String: testValue.data(using: .utf8)!
        ]
        
        // Supprimer l'ancienne si elle existe
        SecItemDelete(query as CFDictionary)
        
        // Ajouter
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        if addStatus != errSecSuccess {
            return TestResult(.failed, "Échec écriture Keychain: \(addStatus)")
        }
        
        // Lire
        let readQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.nztd.Secretino.test",
            kSecAttrAccount as String: testKey,
            kSecReturnData as String: true
        ]
        
        var dataTypeRef: AnyObject?
        let readStatus = SecItemCopyMatching(readQuery as CFDictionary, &dataTypeRef)
        
        // Nettoyer
        SecItemDelete(query as CFDictionary)
        
        if readStatus == errSecSuccess,
           let data = dataTypeRef as? Data,
           let retrievedValue = String(data: data, encoding: .utf8),
           retrievedValue == testValue {
            return TestResult(.passed, "Accès Keychain basique")
        } else {
            return TestResult(.failed, "Échec lecture Keychain: \(readStatus)")
        }
    }
    
    /// Test de disponibilité de la biométrie
    private func testBiometryAvailability() -> TestResult {
        print("2️⃣ Test de disponibilité biométrique...")
        
        let context = LAContext()
        var error: NSError?
        
        let canUseBiometry = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        
        if canUseBiometry {
            let biometryType: String
            switch context.biometryType {
            case .faceID: biometryType = "Face ID"
            case .touchID: biometryType = "Touch ID"
            case .opticID: biometryType = "Optic ID"
            case .none: biometryType = "Aucun"
            @unknown default: biometryType = "Inconnu"
            }
            return TestResult(.passed, "Biométrie disponible (\(biometryType))")
        } else {
            let errorMsg = error?.localizedDescription ?? "Erreur inconnue"
            return TestResult(.warning, "Biométrie non disponible", details: errorMsg)
        }
    }
    
    /// Test avec contrôle d'accès biométrique
    private func testAccessControlKeychain() -> TestResult {
        print("3️⃣ Test Keychain avec contrôle d'accès...")
        
        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.biometryCurrentSet],
            nil
        ) else {
            return TestResult(.failed, "Impossible de créer le contrôle d'accès")
        }
        
        let testKey = "test_biometry_key"
        let testValue = "test_biometry_value"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.nztd.Secretino.test.biometry",
            kSecAttrAccount as String: testKey,
            kSecValueData as String: testValue.data(using: .utf8)!,
            kSecAttrAccessControl as String: accessControl
        ]
        
        // Supprimer l'ancienne si elle existe
        SecItemDelete(query as CFDictionary)
        
        // Ajouter avec protection biométrique
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        
        // Nettoyer
        SecItemDelete(query as CFDictionary)
        
        if addStatus == errSecSuccess {
            return TestResult(.passed, "Contrôle d'accès biométrique créé")
        } else {
            return TestResult(.failed, "Échec création entrée biométrique: \(addStatus)")
        }
    }
    
    /// Test des permissions et erreurs communes
    private func testKeychainPermissions() -> TestResult {
        print("4️⃣ Test des permissions et erreurs...")
        
        // Test d'accès à un item inexistant
        let nonExistentQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.nztd.Secretino.nonexistent",
            kSecAttrAccount as String: "nonexistent",
            kSecReturnData as String: true
        ]
        
        var dataTypeRef: AnyObject?
        let notFoundStatus = SecItemCopyMatching(nonExistentQuery as CFDictionary, &dataTypeRef)
        
        if notFoundStatus == errSecItemNotFound {
            return TestResult(.passed, "Gestion correcte des items inexistants")
        } else {
            return TestResult(.warning, "Status inattendu pour item inexistant: \(notFoundStatus)")
        }
    }
    
    /// Test spécifique pour Secretino
    func testSecretinoKeychain() -> TestResult {
        print("5️⃣ Test spécifique du Keychain Secretino...")
        
        do {
            // Test de stockage
            try SecureKeychainManager.shared.storeGlobalPassphrase("test_passphrase_secretino")
            
            // Test de vérification
            let hasPassphrase = SecureKeychainManager.shared.hasGlobalPassphrase()
            if !hasPassphrase {
                return TestResult(.failed, "Vérification hasGlobalPassphrase échouée")
            }
            
            // Test de suppression
            try SecureKeychainManager.shared.deleteGlobalPassphrase()
            
            // Vérifier que c'est bien supprimé
            let hasPassphraseAfter = SecureKeychainManager.shared.hasGlobalPassphrase()
            if hasPassphraseAfter {
                return TestResult(.failed, "Passphrase existe encore après suppression")
            }
            
            return TestResult(.passed, "Cycle complet Keychain Secretino")
            
        } catch {
            return TestResult(.failed, "Erreur test Secretino: \(error)")
        }
    }
    
    // MARK: - Méthodes publiques legacy (pour compatibilité)
    
    /// Test complet du Keychain (méthode legacy)
    func runFullKeychainTest() {
        let results = runTests()
        
        print("\n🔐 === RÉSUMÉ TESTS KEYCHAIN ===")
        for result in results {
            TestUtils.printTestResult(result)
        }
        
        let passedCount = results.filter { $0.status == .passed }.count
        print("Score: \(passedCount)/\(results.count)")
        print("===============================\n")
    }
    
    /// Affiche des informations de debug sur le Keychain
    func debugKeychainInfo() {
        print("\n📊 Informations de debug Keychain:")
        print("   Bundle ID: \(Bundle.main.bundleIdentifier ?? "N/A")")
        print("   Keychain Service: com.nztd.Secretino")
        
        // Test simple de disponibilité du Keychain
        let testQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.nztd.Secretino.debug",
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(testQuery as CFDictionary, &result)
        
        print("   Status recherche Keychain: \(status)")
        if status == errSecItemNotFound {
            print("   ✅ Keychain accessible (aucun item trouvé = normal)")
        } else if status == errSecSuccess {
            print("   ✅ Keychain accessible (items trouvés)")
        } else {
            print("   ⚠️ Status inattendu: \(status)")
        }
    }
}
