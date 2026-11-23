package update

import (
	"crypto/ed25519"
	"encoding/base64"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestPublicKeyMatchesFile(t *testing.T) {
	raw, err := os.ReadFile("../../../packaging/sms-update.pub")
	if err != nil {
		t.Fatal(err)
	}
	fileKey := strings.TrimSpace(string(raw))
	if fileKey != strings.TrimSpace(PublicKeyBase64) {
		t.Fatal("packaging/sms-update.pub does not match the key built into the server")
	}
	decoded, err := base64.StdEncoding.DecodeString(fileKey)
	if err != nil {
		t.Fatal(err)
	}
	if len(decoded) != ed25519.PublicKeySize {
		t.Fatalf("public key is %d bytes", len(decoded))
	}
}

func TestRepoHasNoPrivateKey(t *testing.T) {
	root := filepath.Clean("../../../")
	err := filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() {
			name := info.Name()
			if name == ".git" || name == "dist" {
				return filepath.SkipDir
			}
			return nil
		}
		lower := strings.ToLower(info.Name())
		if strings.HasSuffix(lower, ".priv") || lower == "update.priv" {
			t.Errorf("private key file in the repo: %s", path)
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
}
