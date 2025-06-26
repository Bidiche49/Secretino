//
//  CryptoTester.swift
//  Secretino
//
//  Tests isolés pour les fonctions cryptographiques
//

import Foundation

class CryptoTester: TestRunner {
    let testName = "Crypto"
    
    func runTests() -> [TestResult] {
        print("🧪 === TESTS CRYPTOGRAPHIQUES ===")
        
        var results: [TestResult] = []
        
        // Test 1: Chiffrement de base
        results.append(testBasicEncryption())
        
        // Test 2: Déchiffrement de base
        results.append(testBasicDecryption())
        
        // Test 3: Round-trip complet
        results.append(testRoundTrip())
        
        // Test 4: Gestion des erreurs
        results.append(testErrorHandling())
        
        // Test 5: Différentes tailles de données
        results.append(testDataSizes())
        
        // Test 6: Caractères spéciaux et Unicode
        results.append(testUnicodeData())
        
        // Test 7: Performance
        results.append(testPerformance())
        
        return results
    }
    
    func cleanup() {
        // Aucun nettoyage nécessaire pour les tests crypto
    }
    
    // MARK: - Tests individuels
    
    private func testBasicEncryption() -> TestResult {
        print("1️⃣ Test chiffrement de base...")
        
        let testText = TestConstants.testText
        let testPassword = TestConstants.testPassphrase
        
        guard let result = swift_encrypt_data(testText, testPassword) else {
            return TestResult(.failed, "Échec allocation résultat chiffrement")
        }
        defer { free_crypto_result(result) }
        
        let cryptoResult = result.pointee
        guard cryptoResult.success == 1 else {
            let errorMsg = String(cString: cryptoResult.error_message)
            return TestResult(.failed, "Échec chiffrement", details: errorMsg)
        }
        
        // Vérifier que les données sont bien chiffrées
        let dataLength = Int(cryptoResult.length)
        if dataLength < 64 { // Minimum: salt(32) + iv(12) + tag(16) + quelques bytes
            return TestResult(.failed, "Données chiffrées trop courtes", details: "\(dataLength) bytes")
        }
        
        return TestResult(.passed, "Chiffrement réussi (\(dataLength) bytes)")
    }
    
    private func testBasicDecryption() -> TestResult {
        print("2️⃣ Test déchiffrement de base...")
        
        let testText = "Message de test déchiffrement"
        let testPassword = TestConstants.testPassphrase
        
        // D'abord chiffrer
        guard let encryptResult = swift_encrypt_data(testText, testPassword) else {
            return TestResult(.failed, "Échec chiffrement préalable")
        }
        defer { free_crypto_result(encryptResult) }
        
        let encryptData = encryptResult.pointee
        guard encryptData.success == 1 else {
            return TestResult(.failed, "Échec chiffrement préalable")
        }
        
        // Puis déchiffrer
        guard let decryptResult = swift_decrypt_data(
            encryptData.data,
            Int32(encryptData.length),
            testPassword
        ) else {
            return TestResult(.failed, "Échec allocation résultat déchiffrement")
        }
        defer { free_crypto_result(decryptResult) }
        
        let decryptData = decryptResult.pointee
        guard decryptData.success == 1 else {
            let errorMsg = String(cString: decryptData.error_message)
            return TestResult(.failed, "Échec déchiffrement", details: errorMsg)
        }
        
        let decryptedText = String(cString: decryptData.data)
        if decryptedText == testText {
            return TestResult(.passed, "Déchiffrement réussi")
        } else {
            return TestResult(.failed, "Texte déchiffré incorrect",
                            details: "Attendu: '\(testText)', Obtenu: '\(decryptedText)'")
        }
    }
    
    private func testRoundTrip() -> TestResult {
        print("3️⃣ Test round-trip complet...")
        
        let testMessages = [
            "Message simple",
            "Message avec émojis 🔐🔒✅",
            "Message avec accents éàùç",
            "Message\navec\nligne\nmultiples",
            ""  // Message vide
        ]
        
        for (index, message) in testMessages.enumerated() {
            let result = performRoundTrip(message, TestConstants.testPassphrase)
            if result.status != .passed {
                return TestResult(.failed, "Round-trip échoué pour message \(index + 1)",
                                details: result.message)
            }
        }
        
        return TestResult(.passed, "Round-trip réussi pour \(testMessages.count) messages")
    }
    
    private func testErrorHandling() -> TestResult {
        print("4️⃣ Test gestion d'erreurs...")
        
        var errorTests = 0
        var errorsPassed = 0
        
        // Test 1: Mauvais mot de passe
        errorTests += 1
        if testWrongPassword() {
            errorsPassed += 1
        }
        
        // Test 2: Données corrompues
        errorTests += 1
        if testCorruptedData() {
            errorsPassed += 1
        }
        
        // Test 3: Base64 invalide
        errorTests += 1
        if testInvalidBase64() {
            errorsPassed += 1
        }
        
        if errorsPassed == errorTests {
            return TestResult(.passed, "Gestion d'erreurs correcte (\(errorsPassed)/\(errorTests))")
        } else {
            return TestResult(.failed, "Gestion d'erreurs défaillante (\(errorsPassed)/\(errorTests))")
        }
    }
    
    private func testDataSizes() -> TestResult {
        print("5️⃣ Test différentes tailles de données...")
        
        let testSizes = [1, 10, 100, 1000, 10000] // bytes
        
        for size in testSizes {
            let testData = String(repeating: "A", count: size)
            let result = performRoundTrip(testData, TestConstants.testPassphrase)
            
            if result.status != .passed {
                return TestResult(.failed, "Échec pour taille \(size) bytes", details: result.message)
            }
        }
        
        return TestResult(.passed, "Tests réussis pour tailles: \(testSizes.map { "\($0)B" }.joined(separator: ", "))")
    }
    
    private func testUnicodeData() -> TestResult {
        print("6️⃣ Test données Unicode...")
        
        let unicodeTests = [
            "Français: éàùç",
            "Emoji: 🔐🚀✅❌🎉",
            "Japonais: こんにちは世界",
            "Arabe: مرحبا بالعالم",
            "Russe: Привет мир",
            "Symboles: ©®™€£¥"
        ]
        
        for (index, test) in unicodeTests.enumerated() {
            let result = performRoundTrip(test, TestConstants.testPassphrase)
            if result.status != .passed {
                return TestResult(.failed, "Échec Unicode test \(index + 1)", details: result.message)
            }
        }
        
        return TestResult(.passed, "Tests Unicode réussis (\(unicodeTests.count) jeux de caractères)")
    }
    
    private func testPerformance() -> TestResult {
        print("7️⃣ Test performance...")
        
        let testData = String(repeating: "Performance test data. ", count: 100) // ~2KB
        let iterations = 10
        
        let (_, duration) = TestUtils.measureTime {
            for _ in 0..<iterations {
                _ = performRoundTrip(testData, TestConstants.testPassphrase)
            }
        }
        
        let avgTime = duration / Double(iterations) * 1000 // en ms
        
        if avgTime < 100 { // Moins de 100ms par opération
            return TestResult(.passed, "Performance OK (avg: \(String(format: "%.1f", avgTime))ms)")
        } else {
            return TestResult(.warning, "Performance lente (avg: \(String(format: "%.1f", avgTime))ms)")
        }
    }
    
    // MARK: - Méthodes utilitaires
    
    private func performRoundTrip(_ text: String, _ password: String) -> TestResult {
        // Chiffrement
        guard let encryptResult = swift_encrypt_data(text, password) else {
            return TestResult(.failed, "Échec allocation chiffrement")
        }
        defer { free_crypto_result(encryptResult) }
        
        let encryptData = encryptResult.pointee
        guard encryptData.success == 1 else {
            let errorMsg = String(cString: encryptData.error_message)
            return TestResult(.failed, "Échec chiffrement: \(errorMsg)")
        }
        
        // Base64 encoding
        guard let base64 = swift_base64_encode(encryptData.data, Int32(encryptData.length)) else {
            return TestResult(.failed, "Échec encodage Base64")
        }
        defer { free(base64) }
        
        // Base64 decoding
        guard let decodeResult = swift_base64_decode(base64) else {
            return TestResult(.failed, "Échec décodage Base64")
        }
        defer { free_crypto_result(decodeResult) }
        
        let decodedData = decodeResult.pointee
        guard decodedData.success == 1 else {
            return TestResult(.failed, "Échec décodage Base64 interne")
        }
        
        // Déchiffrement
        guard let decryptResult = swift_decrypt_data(
            decodedData.data,
            Int32(decodedData.length),
            password
        ) else {
            return TestResult(.failed, "Échec allocation déchiffrement")
        }
        defer { free_crypto_result(decryptResult) }
        
        let decryptData = decryptResult.pointee
        guard decryptData.success == 1 else {
            let errorMsg = String(cString: decryptData.error_message)
            return TestResult(.failed, "Échec déchiffrement: \(errorMsg)")
        }
        
        let decryptedText = String(cString: decryptData.data)
        
        if decryptedText == text {
            return TestResult(.passed, "Round-trip réussi")
        } else {
            return TestResult(.failed, "Texte différent après round-trip")
        }
    }
    
    private func testWrongPassword() -> Bool {
        guard let encryptResult = swift_encrypt_data("test", "password1") else { return false }
        defer { free_crypto_result(encryptResult) }
        
        let encryptData = encryptResult.pointee
        guard encryptData.success == 1 else { return false }
        
        guard let decryptResult = swift_decrypt_data(
            encryptData.data,
            Int32(encryptData.length),
            "password2" // Mauvais mot de passe
        ) else { return false }
        defer { free_crypto_result(decryptResult) }
        
        let decryptData = decryptResult.pointee
        return decryptData.success == 0 // Doit échouer
    }
    
    private func testCorruptedData() -> Bool {
        guard let encryptResult = swift_encrypt_data("test", "password") else { return false }
        defer { free_crypto_result(encryptResult) }
        
        let encryptData = encryptResult.pointee
        guard encryptData.success == 1 else { return false }
        
        // Corrompre les données
        var corruptedData = Data(bytes: encryptData.data, count: Int(encryptData.length))
        if corruptedData.count > 10 {
            corruptedData[10] = corruptedData[10] ^ 0xFF // Flip des bits
        }
        
        let result = corruptedData.withUnsafeBytes { bytes in
            swift_decrypt_data(
                bytes.bindMemory(to: UInt8.self).baseAddress!,
                Int32(corruptedData.count),
                "password"
            )
        }
        
        guard let decryptResult = result else { return false }
        defer { free_crypto_result(decryptResult) }
        
        let decryptData = decryptResult.pointee
        return decryptData.success == 0 // Doit échouer
    }
    
    private func testInvalidBase64() -> Bool {
        let invalidBase64 = "Ceci n'est pas du Base64 valide!"
        
        guard let decodeResult = swift_base64_decode(invalidBase64) else { return false }
        defer { free_crypto_result(decodeResult) }
        
        let decodedData = decodeResult.pointee
        return decodedData.success == 0 // Doit échouer
    }
}
