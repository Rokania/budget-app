import Foundation
import Security

// MARK: - Enable Banking Client

actor EnableBankingClient {
    static let shared = EnableBankingClient()

    private let baseURL = URL(string: "https://api.enablebanking.com")!
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()
    private let encoder = JSONEncoder()

    // MARK: - Configuration

    private var applicationId: String {
        KeychainHelper.read(key: "eb_app_id") ?? ""
    }

    /// PEM-encoded RSA private key for JWT signing
    private var privateKeyPEM: String {
        KeychainHelper.read(key: "eb_private_key") ?? ""
    }

    var isConfigured: Bool {
        !applicationId.isEmpty && !privateKeyPEM.isEmpty
    }

    func configure(applicationId: String, privateKeyPEM: String) {
        KeychainHelper.save(key: "eb_app_id", value: applicationId)
        KeychainHelper.save(key: "eb_private_key", value: privateKeyPEM)
    }

    // MARK: - JWT Generation

    private func generateJWT() throws -> String {
        let header: [String: String] = [
            "typ": "JWT",
            "alg": "RS256",
            "kid": applicationId,
        ]

        let now = Date()
        let body: [String: Any] = [
            "iss": "enablebanking.com",
            "aud": "api.enablebanking.com",
            "iat": Int(now.timeIntervalSince1970),
            "exp": Int(now.timeIntervalSince1970) + 3600,
        ]

        let headerData = try JSONSerialization.data(withJSONObject: header)
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        let headerB64 = headerData.base64URLEncoded()
        let bodyB64 = bodyData.base64URLEncoded()

        let signingInput = "\(headerB64).\(bodyB64)"
        let signature = try signRS256(data: Data(signingInput.utf8))

        return "\(signingInput).\(signature.base64URLEncoded())"
    }

    private func signRS256(data: Data) throws -> Data {
        let pemString = privateKeyPEM
            .replacingOccurrences(of: "-----BEGIN RSA PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "-----END RSA PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "-----BEGIN PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "-----END PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespaces)

        guard let keyData = Data(base64Encoded: pemString) else {
            throw EnableBankingError.invalidKey
        }

        // Try PKCS#8 first (BEGIN PRIVATE KEY), then fall back to PKCS#1 (BEGIN RSA PRIVATE KEY)
        let rsaKeyData = Self.stripPKCS8Header(keyData) ?? keyData

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecAttrKeySizeInBits as String: 2048,
        ]

        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(rsaKeyData as CFData, attributes as CFDictionary, &error) else {
            // Retry with original data in case stripping was wrong
            guard let key2 = SecKeyCreateWithData(keyData as CFData, attributes as CFDictionary, &error) else {
                throw EnableBankingError.invalidKey
            }
            guard let signature = SecKeyCreateSignature(
                key2, .rsaSignatureMessagePKCS1v15SHA256, data as CFData, &error
            ) as Data? else {
                throw EnableBankingError.signingFailed
            }
            return signature
        }

        guard let signature = SecKeyCreateSignature(
            key,
            .rsaSignatureMessagePKCS1v15SHA256,
            data as CFData,
            &error
        ) as Data? else {
            throw EnableBankingError.signingFailed
        }

        return signature
    }

    /// Strips the PKCS#8 header to get raw PKCS#1 RSA key data.
    /// PKCS#8 wraps the RSA key in a SEQUENCE { AlgorithmIdentifier, OCTET STRING { PKCS#1 key } }.
    private static func stripPKCS8Header(_ keyData: Data) -> Data? {
        // PKCS#8 header for RSA: 30 82 xx xx 30 0d 06 09 2a 86 48 86 f7 0d 01 01 01 05 00 03 82 xx xx 00
        // We look for the OID 1.2.840.113549.1.1.1 (RSA) in the header
        let rsaOID: [UInt8] = [0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01]
        let bytes = [UInt8](keyData)

        guard bytes.count > 26 else { return nil }

        // Find the RSA OID in the first 24 bytes
        var oidIndex: Int?
        for i in 0..<min(24, bytes.count - rsaOID.count) {
            if Array(bytes[i..<i+rsaOID.count]) == rsaOID {
                oidIndex = i
                break
            }
        }
        guard let oi = oidIndex else { return nil }

        // After OID: NULL (05 00), then BIT STRING (03 82 xx xx 00) or OCTET STRING (04 82 xx xx)
        var idx = oi + rsaOID.count
        // Skip NULL parameter if present
        if idx + 1 < bytes.count && bytes[idx] == 0x05 && bytes[idx+1] == 0x00 {
            idx += 2
        }
        // Expect BIT STRING (0x03) or OCTET STRING (0x04)
        guard idx < bytes.count && (bytes[idx] == 0x03 || bytes[idx] == 0x04) else { return nil }
        let isBitString = bytes[idx] == 0x03
        idx += 1
        // Parse length
        if bytes[idx] & 0x80 != 0 {
            let lenBytes = Int(bytes[idx] & 0x7f)
            idx += 1 + lenBytes
        } else {
            idx += 1
        }
        // BIT STRING has an extra 0x00 byte for unused bits
        if isBitString && idx < bytes.count && bytes[idx] == 0x00 {
            idx += 1
        }
        guard idx < bytes.count else { return nil }
        return Data(bytes[idx...])
    }

    // MARK: - Institutions

    func listInstitutions(country: String = "FR") async throws -> [EBInstitution] {
        let response: EBInstitutionsResponse = try await get(path: "/aspsps?country=\(country)")
        return response.aspsps
    }

    // MARK: - Authorization

    func startAuthorization(
        institutionName: String,
        country: String = "FR",
        redirectURL: String = "https://localhost/callback"
    ) async throws -> EBStartAuthResponse {
        let validUntil = ISO8601DateFormatter().string(from: Date().addingTimeInterval(90 * 24 * 3600))

        let request = EBStartAuthRequest(
            access: EBAccessScope(
                valid_until: validUntil,
                balances: true,
                transactions: true
            ),
            aspsp: EBASPSPSelection(name: institutionName, country: country),
            state: UUID().uuidString,
            redirect_url: redirectURL,
            psu_type: "personal"
        )

        return try await post(path: "/auth", body: request)
    }

    // MARK: - Sessions

    func createSession(code: String) async throws -> EBSession {
        let request = EBCreateSessionRequest(code: code)
        return try await post(path: "/sessions", body: request)
    }

    func getSession(id: String) async throws -> EBSession {
        try await get(path: "/sessions/\(id)")
    }

    // MARK: - Account Data

    func getAccountDetails(accountUID: String) async throws -> EBAccountDetails {
        try await get(path: "/accounts/\(accountUID)/details")
    }

    func getAccountBalances(accountUID: String) async throws -> EBBalancesResponse {
        try await get(path: "/accounts/\(accountUID)/balances")
    }

    func getAccountTransactions(accountUID: String) async throws -> EBTransactionsResponse {
        try await get(path: "/accounts/\(accountUID)/transactions")
    }

    // MARK: - HTTP

    private func get<T: Decodable>(path: String) async throws -> T {
        let jwt = try generateJWT()
        guard let url = URL(string: baseURL.absoluteString + path) else {
            throw EnableBankingError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    private func post<T: Decodable, B: Encodable>(path: String, body: B) async throws -> T {
        let jwt = try generateJWT()
        guard let url = URL(string: baseURL.absoluteString + path) else {
            throw EnableBankingError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        request.httpBody = try encoder.encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    private func validateResponse(_ response: URLResponse, data: Data? = nil) throws {
        guard let http = response as? HTTPURLResponse else {
            throw EnableBankingError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            throw EnableBankingError.httpError(http.statusCode, body)
        }
    }
}

// MARK: - Errors

enum EnableBankingError: LocalizedError {
    case notConfigured
    case invalidKey
    case signingFailed
    case invalidResponse
    case httpError(Int, String)
    case noAccounts

    var errorDescription: String? {
        switch self {
        case .notConfigured: "Cles Enable Banking non configurees"
        case .invalidKey: "Cle privee RSA invalide"
        case .signingFailed: "Erreur de signature JWT"
        case .invalidResponse: "Reponse invalide du serveur"
        case .httpError(let code, let body):
            if body.isEmpty {
                "Erreur HTTP \(code)"
            } else {
                "Erreur HTTP \(code): \(body.prefix(200))"
            }
        case .noAccounts: "Aucun compte trouve"
        }
    }
}

// MARK: - Base64URL

extension Data {
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Keychain Helper

enum KeychainHelper {
    static func save(key: String, value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.budget.app",
        ]
        SecItemDelete(query as CFDictionary)
        var addQuery = query
        addQuery[kSecValueData as String] = data
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    static func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.budget.app",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.budget.app",
        ]
        SecItemDelete(query as CFDictionary)
    }
}
