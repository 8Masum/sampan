import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:sampan/core/protocol/wire_protocol.dart';

/// Generated zero-cloud Ed25519 cryptographic identity (Section 5.1).
class GeneratedKeyIdentity {
  const GeneratedKeyIdentity({
    required this.publicKeyHex,
    required this.privateSeedHex,
    required this.fingerprintUri,
  });

  final String publicKeyHex;
  final String privateSeedHex;
  final String fingerprintUri;

  /// Truncated 14-byte (28 hex character) ephemeral key for 28-byte BLE
  /// advertisements (Section 6.1).
  String get truncated14ByteHex => publicKeyHex.length >= 28
      ? publicKeyHex.substring(0, 28)
      : publicKeyHex.padRight(28, '0');
}

/// Zero-server Ed25519 identity, ChaCha20-Poly1305 E2EE, and Hashcash PoW
/// service for Sampan (Section 3 & Section 5.1).
class IdentityCryptoService {
  IdentityCryptoService()
      : _ed25519 = Ed25519(),
        _chacha20 = Chacha20.poly1305Aead(),
        _sha256 = Sha256();

  final Ed25519 _ed25519;
  final Chacha20 _chacha20;
  final Sha256 _sha256;

  /// Generates a fresh Ed25519 keypair in `< 10ms` with zero server
  /// dependency (Section 5.1).
  Future<GeneratedKeyIdentity> generateIdentity() async {
    final SimpleKeyPair keyPair = await _ed25519.newKeyPair();
    final SimplePublicKey pubKey = await keyPair.extractPublicKey();
    final List<int> seedBytes = await keyPair.extractPrivateKeyBytes();

    final String pubHex = SampanWireProtocol.bytesToHex(pubKey.bytes);
    final String seedHex = SampanWireProtocol.bytesToHex(seedBytes);

    return GeneratedKeyIdentity(
      publicKeyHex: pubHex,
      privateSeedHex: seedHex,
      fingerprintUri: formatPublicFingerprint(pubHex),
    );
  }

  /// Formats a 64-character hex Ed25519 public key into the canonical
  /// display URI `sampan:ed25519:7a8b...3f9c` (Section 5.1).
  static String formatPublicFingerprint(String publicKeyHex) {
    final String clean = publicKeyHex
        .replaceFirst(RegExp('^sampan:ed25519:', caseSensitive: false), '')
        .trim()
        .toLowerCase();
    if (clean.length < 12) {
      return 'sampan:ed25519:$clean';
    }
    final String prefix = clean.substring(0, 8);
    final String suffix = clean.substring(clean.length - 4);
    return 'sampan:ed25519:$prefix...$suffix';
  }

  /// Signs a message payload using the user's Ed25519 private seed.
  Future<String> signPayload({
    required String privateSeedHex,
    required String message,
  }) async {
    final Uint8List seedBytes = _hexToBytes(privateSeedHex);
    final SimpleKeyPair keyPair = await _ed25519.newKeyPairFromSeed(seedBytes);
    final Signature signature = await _ed25519.sign(
      utf8.encode(message),
      keyPair: keyPair,
    );
    return SampanWireProtocol.bytesToHex(signature.bytes);
  }

  /// Verifies an Ed25519 signature against a peer's public key hex.
  Future<bool> verifySignature({
    required String publicKeyHex,
    required String message,
    required String signatureHex,
  }) async {
    try {
      final Uint8List pubBytes = _hexToBytes(publicKeyHex);
      final Uint8List sigBytes = _hexToBytes(signatureHex);
      if (pubBytes.length != 32 || sigBytes.length != 64) {
        return false;
      }
      final SimplePublicKey publicKey = SimplePublicKey(
        pubBytes,
        type: KeyPairType.ed25519,
      );
      final Signature signature = Signature(
        sigBytes,
        publicKey: publicKey,
      );
      return await _ed25519.verify(
        utf8.encode(message),
        signature: signature,
      );
    } on Object {
      return false;
    }
  }

  /// Encrypts a UTF-8 chat payload using ChaCha20-Poly1305 AEAD derived from
  /// the caravan channel key or shared peer secret (Section 3 & 4.2).
  Future<Uint8List> encryptChatPayload({
    required String plaintext,
    required String channelContextKey,
  }) async {
    final Hash keyHash = await _sha256.hash(utf8.encode(channelContextKey));
    final SecretKey secretKey = SecretKey(keyHash.bytes);
    final List<int> nonce = _chacha20.newNonce();
    final SecretBox box = await _chacha20.encrypt(
      utf8.encode(plaintext),
      secretKey: secretKey,
      nonce: nonce,
    );
    return box.concatenation();
  }

  /// Decrypts a ChaCha20-Poly1305 concatenated ciphertext (`nonce + cipher + mac`).
  Future<String> decryptChatPayload({
    required Uint8List concatenatedBytes,
    required String channelContextKey,
  }) async {
    final Hash keyHash = await _sha256.hash(utf8.encode(channelContextKey));
    final SecretKey secretKey = SecretKey(keyHash.bytes);
    final SecretBox box = SecretBox.fromConcatenation(
      concatenatedBytes,
      nonceLength: _chacha20.nonceLength,
      macLength: _chacha20.macAlgorithm.macLength,
    );
    final List<int> clearBytes = await _chacha20.decrypt(
      box,
      secretKey: secretKey,
    );
    return utf8.decode(clearBytes);
  }

  /// Computes a lightweight Hashcash Proof-of-Work nonce (requiring [leadingZeroBits]
  /// leading zero bits in SHA-256) to prevent radio spam (Section 7 Phase 2).
  Future<int> computeHashcashNonce({
    required String senderKeyHex,
    required String content,
    int leadingZeroBits = 8,
    int maxIterations = 50000,
  }) async {
    for (int nonce = 0; nonce < maxIterations; nonce++) {
      final Hash digest =
          await _sha256.hash(utf8.encode('$senderKeyHex:$nonce:$content'));
      if (_hasLeadingZeroBits(digest.bytes, leadingZeroBits)) {
        return nonce;
      }
    }
    return 0;
  }

  static bool _hasLeadingZeroBits(List<int> bytes, int bits) {
    int remaining = bits;
    for (final int byte in bytes) {
      if (remaining <= 0) return true;
      if (remaining >= 8) {
        if (byte != 0) return false;
        remaining -= 8;
      } else {
        final int mask = (0xFF << (8 - remaining)) & 0xFF;
        return (byte & mask) == 0;
      }
    }
    return true;
  }

  static Uint8List _hexToBytes(String hex) {
    final String cleaned = hex.replaceAll(RegExp('[^0-9a-fA-F]'), '');
    final int pairCount = cleaned.length ~/ 2;
    final Uint8List out = Uint8List(pairCount);
    for (int i = 0; i < pairCount; i++) {
      out[i] = int.parse(cleaned.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }
}
