// Command updatekey makes an update signing key, or signs an update bundle.
// The private key is read from a file path. This program never writes a key
// into the source tree.
package main

import (
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"schooldesk/internal/update"
)

func main() {
	gen := flag.String("gen", "", "folder where update.priv and update.pub are written")
	keyPath := flag.String("key", "", "path to the private key file")
	dir := flag.String("dir", "", "folder of files to put in the bundle")
	version := flag.String("version", "sms-v1", "version name written in the bundle")
	schema := flag.Int("schema", 2, "schema number the school records move forward to")
	out := flag.String("out", "", "path of the signed .smsu file")
	flag.Parse()

	if *gen != "" {
		if err := generate(*gen); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		return
	}
	if *keyPath == "" || *dir == "" || *out == "" {
		fmt.Fprintln(os.Stderr, "use -gen FOLDER, or -key private.key -dir payload -out update.smsu")
		os.Exit(2)
	}
	if err := sign(*keyPath, *dir, *version, *schema, *out); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func generate(dir string) error {
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return err
	}
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		return err
	}
	if err := os.WriteFile(filepath.Join(dir, "update.priv"), []byte(base64.StdEncoding.EncodeToString(priv)), 0o600); err != nil {
		return err
	}
	if err := os.WriteFile(filepath.Join(dir, "update.pub"), []byte(base64.StdEncoding.EncodeToString(pub)), 0o644); err != nil {
		return err
	}
	fmt.Println("Wrote update.priv and update.pub. Keep update.priv off this computer's backups and out of git.")
	return nil
}

func sign(keyPath, dir, version string, schema int, out string) error {
	raw, err := os.ReadFile(keyPath)
	if err != nil {
		return err
	}
	priv, err := base64.StdEncoding.DecodeString(strings.TrimSpace(string(raw)))
	if err != nil || len(priv) != ed25519.PrivateKeySize {
		return fmt.Errorf("the key file is not a private update key")
	}
	files := map[string][]byte{}
	entries, err := os.ReadDir(dir)
	if err != nil {
		return err
	}
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		body, err := os.ReadFile(filepath.Join(dir, entry.Name()))
		if err != nil {
			return err
		}
		files[entry.Name()] = body
	}
	bundle, err := update.Sign(ed25519.PrivateKey(priv), update.Manifest{
		Product: update.Product, Version: version, Schema: schema,
	}, files)
	if err != nil {
		return err
	}
	return os.WriteFile(out, bundle, 0o644)
}
