package license

import (
	"crypto/ed25519"
	"crypto/sha256"
	"crypto/subtle"
)

// The production public key is stored XOR-masked. The mask is a SHA-256
// digest, and the unmasked key is checked against a SHA-256 fingerprint
// before it is used.

var maskedKeyLeft = [16]byte{
	26, 163, 61, 118, 125, 157, 65, 193, 36, 150, 61, 169, 145, 235, 202, 123,
}

var maskedKeyRight = [16]byte{
	91, 19, 111, 29, 192, 190, 173, 99, 156, 182, 59, 240, 223, 15, 131, 21,
}

var keyFingerprint = [32]byte{
	3, 19, 27, 142, 185, 174, 47, 7, 173, 93, 38, 123, 215, 15, 183, 162,
	223, 11, 152, 200, 74, 199, 195, 84, 140, 111, 130, 13, 0, 15, 163, 184,
}

func keyMask() [32]byte {
	h := sha256.New()
	h.Write([]byte{0x53, 0x43, 0x48, 0x31}) // SCH1
	h.Write([]byte("-MASK-v1-"))
	h.Write([]byte{0x39, 0x4d, 0x4d}) // 9MM
	var out [32]byte
	copy(out[:], h.Sum(nil))
	return out
}

// PublicKeyCheck confirms the embedded key has not been altered.
func PublicKeyCheck() error {
	_, err := publicKey()
	return err
}

func publicKey() (ed25519.PublicKey, error) {
	mask := keyMask()
	raw := make([]byte, ed25519.PublicKeySize)
	for i := 0; i < 16; i++ {
		raw[i] = maskedKeyLeft[i] ^ mask[i]
		raw[16+i] = maskedKeyRight[i] ^ mask[16+i]
	}
	sum := sha256.Sum256(raw)
	if subtle.ConstantTimeCompare(sum[:], keyFingerprint[:]) != 1 {
		return nil, errIntegrity
	}
	return ed25519.PublicKey(raw), nil
}
