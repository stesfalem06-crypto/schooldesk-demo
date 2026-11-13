package auth

import (
	"crypto/rand"
	"crypto/subtle"
	"encoding/base64"
	"errors"
	"fmt"
	"strconv"
	"strings"

	"golang.org/x/crypto/argon2"
)

const (
	memory   = 16 * 1024
	timeCost = 1
	threads  = 1
	keyLen   = 32
)

var ErrPassword = errors.New("use 6 to 72 characters")

// Hash stores a password with argon2id.
func Hash(password string) (string, error) {
	if len(password) < 6 || len(password) > 72 {
		return "", ErrPassword
	}
	salt := make([]byte, 16)
	if _, err := rand.Read(salt); err != nil {
		return "", err
	}
	sum := argon2.IDKey([]byte(password), salt, timeCost, memory, threads, keyLen)
	return fmt.Sprintf("$argon2id$v=19$m=%d,t=%d,p=%d$%s$%s",
		memory, timeCost, threads, b64(salt), b64(sum)), nil
}

// Check reports whether password matches a stored hash.
func Check(encoded, password string) bool {
	parts := strings.Split(encoded, "$")
	if len(parts) != 6 || parts[1] != "argon2id" {
		return false
	}
	var m, t uint32
	var p uint8
	for _, item := range strings.Split(parts[3], ",") {
		kv := strings.SplitN(item, "=", 2)
		if len(kv) != 2 {
			return false
		}
		n, err := strconv.Atoi(kv[1])
		if err != nil || n < 1 {
			return false
		}
		switch kv[0] {
		case "m":
			m = uint32(n)
		case "t":
			t = uint32(n)
		case "p":
			p = uint8(n)
		default:
			return false
		}
	}
	salt, err := b64dec(parts[4])
	if err != nil {
		return false
	}
	want, err := b64dec(parts[5])
	if err != nil || m == 0 || t == 0 || p == 0 {
		return false
	}
	got := argon2.IDKey([]byte(password), salt, t, m, p, uint32(len(want)))
	return subtle.ConstantTimeCompare(got, want) == 1
}

func b64(b []byte) string { return base64.RawStdEncoding.EncodeToString(b) }

func b64dec(s string) ([]byte, error) { return base64.RawStdEncoding.DecodeString(s) }
