import Foundation
import CryptoKit
import CommonCrypto

struct VaultEnvelope: Codable {
    var format = "waraqa"
    var version = 1
    var encrypted: Bool
    var data: Notebook?
    var kdf: String?
    var iterations: Int?
    var salt: String?
    var iv: String?
    var payload: String?
    static func clear(_ notebook: Notebook) -> VaultEnvelope { VaultEnvelope(encrypted:false,data:notebook) }
    func validated() throws -> VaultEnvelope {
        guard format == "waraqa", version == 1 else { throw WaraqaError.invalidBackup }
        if encrypted {
            guard iterations == VaultCrypto.iterations, kdf == "PBKDF2-SHA256",
                  let salt, Data(base64Encoded:salt)?.count == 16,
                  let iv, Data(base64Encoded:iv)?.count == 12,
                  let payload, payload.count <= 16_000_000, let bytes = Data(base64Encoded:payload), bytes.count >= 16 else { throw WaraqaError.unsupportedEncryption }
        } else { guard let data else { throw WaraqaError.invalidBackup }; _ = try data.validated() }
        return self
    }
}
enum VaultCrypto {
    static let iterations = 600_000
    static func newSalt() -> Data { Data(AES.GCM.Nonce()) + Data((0..<4).map { _ in UInt8.random(in:0...255) }) }
    static func derive(password: String, salt: Data) throws -> SymmetricKey {
        guard salt.count == 16 else { throw WaraqaError.unsupportedEncryption }
        let password = Array(password.utf8)
        var result = [UInt8](repeating:0,count:32)
        let status = password.withUnsafeBytes { p in salt.withUnsafeBytes { s in
            CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2),p.bindMemory(to:Int8.self).baseAddress,password.count,s.bindMemory(to:UInt8.self).baseAddress,salt.count,CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),UInt32(iterations),&result,32)
        }}
        guard status == kCCSuccess else { throw WaraqaError.unsupportedEncryption }
        return SymmetricKey(data:Data(result))
    }
    static func seal(_ notebook: Notebook, key: SymmetricKey, salt: Data) throws -> VaultEnvelope {
        let clear = try JSONEncoder().encode(notebook.validated())
        let box = try AES.GCM.seal(clear,using:key)
        return VaultEnvelope(encrypted:true,kdf:"PBKDF2-SHA256",iterations:iterations,salt:salt.base64EncodedString(),iv:Data(box.nonce).base64EncodedString(),payload:(box.ciphertext + box.tag).base64EncodedString())
    }
    static func open(_ envelope: VaultEnvelope, key: SymmetricKey) throws -> Notebook {
        _ = try envelope.validated()
        guard let iv = envelope.iv.flatMap({ Data(base64Encoded:$0) }), let bytes = envelope.payload.flatMap({ Data(base64Encoded:$0) }) else { throw WaraqaError.invalidBackup }
        do {
            let nonce = try AES.GCM.Nonce(data:iv)
            let box = try AES.GCM.SealedBox(nonce:nonce,ciphertext:bytes.dropLast(16),tag:bytes.suffix(16))
            return try JSONDecoder().decode(Notebook.self,from:AES.GCM.open(box,using:key)).validated()
        } catch { throw WaraqaError.wrongPassword }
    }
}
