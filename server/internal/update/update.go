// Package update checks a signed school update, keeps the school records,
// and swaps only the program. The private key never lives in this repository.
package update

import (
	"archive/zip"
	"bytes"
	"crypto/ed25519"
	"crypto/sha256"
	"database/sql"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"time"

	_ "modernc.org/sqlite"
)

// PublicKeyBase64 is the raw ed25519 public key, set at build time with -X.
// An empty value means this build will not accept an update bundle.
var PublicKeyBase64 = ""

const Product = "shamm-school"

type FileInfo struct {
	Name   string `json:"name"`
	SHA256 string `json:"sha256"`
}

type Manifest struct {
	Product string     `json:"product"`
	Version string     `json:"version"`
	Schema  int        `json:"schema"`
	Files   []FileInfo `json:"files"`
}

type ApplyConfig struct {
	PublicKey  ed25519.PublicKey
	DataDir    string
	BinaryPath string
	// Probe runs after the new program is in place. A failure puts the previous program back.
	// School records stay as they are.
	Probe func(binary string) error
}

func EmbeddedKey() (ed25519.PublicKey, error) {
	if strings.TrimSpace(PublicKeyBase64) == "" {
		return nil, errors.New("this program has no update key")
	}
	raw, err := base64.StdEncoding.DecodeString(strings.TrimSpace(PublicKeyBase64))
	if err != nil || len(raw) != ed25519.PublicKeySize {
		return nil, errors.New("the update key is not valid")
	}
	return ed25519.PublicKey(raw), nil
}

func Sign(priv ed25519.PrivateKey, manifest Manifest, files map[string][]byte) ([]byte, error) {
	if manifest.Product == "" {
		manifest.Product = Product
	}
	if manifest.Schema < 1 {
		return nil, errors.New("the schema number is missing")
	}
	manifest.Files = nil
	names := make([]string, 0, len(files))
	for name := range files {
		names = append(names, name)
	}
	sortStrings(names)
	for _, name := range names {
		sum := sha256.Sum256(files[name])
		manifest.Files = append(manifest.Files, FileInfo{Name: name, SHA256: hex.EncodeToString(sum[:])})
	}
	raw, err := json.Marshal(manifest)
	if err != nil {
		return nil, err
	}
	sig := ed25519.Sign(priv, raw)
	buf := &bytes.Buffer{}
	zw := zip.NewWriter(buf)
	if err := writeZip(zw, "manifest.json", raw); err != nil {
		return nil, err
	}
	if err := writeZip(zw, "signature", sig); err != nil {
		return nil, err
	}
	for _, name := range names {
		if err := writeZip(zw, "files/"+name, files[name]); err != nil {
			return nil, err
		}
	}
	if err := zw.Close(); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func writeZip(zw *zip.Writer, name string, body []byte) error {
	w, err := zw.Create(name)
	if err != nil {
		return err
	}
	_, err = w.Write(body)
	return err
}

func Open(pub ed25519.PublicKey, bundle []byte) (Manifest, map[string][]byte, error) {
	zr, err := zip.NewReader(bytes.NewReader(bundle), int64(len(bundle)))
	if err != nil {
		return Manifest{}, nil, errors.New("that is not an update file")
	}
	files := map[string][]byte{}
	for _, f := range zr.File {
		rc, err := f.Open()
		if err != nil {
			return Manifest{}, nil, err
		}
		body, err := io.ReadAll(io.LimitReader(rc, 256<<20))
		rc.Close()
		if err != nil {
			return Manifest{}, nil, err
		}
		files[f.Name] = body
	}
	raw := files["manifest.json"]
	sig := files["signature"]
	if len(raw) == 0 || len(sig) != ed25519.SignatureSize {
		return Manifest{}, nil, errors.New("the update file is missing its signature")
	}
	if !ed25519.Verify(pub, raw, sig) {
		return Manifest{}, nil, errors.New("the update signature does not match")
	}
	var manifest Manifest
	if err := json.Unmarshal(raw, &manifest); err != nil {
		return Manifest{}, nil, errors.New("the update list could not be read")
	}
	if manifest.Product != Product {
		return Manifest{}, nil, errors.New("this update is for a different program")
	}
	payload := map[string][]byte{}
	for _, info := range manifest.Files {
		body := files["files/"+info.Name]
		sum := sha256.Sum256(body)
		if hex.EncodeToString(sum[:]) != info.SHA256 {
			return Manifest{}, nil, fmt.Errorf("the file %s was changed", info.Name)
		}
		payload[info.Name] = body
	}
	return manifest, payload, nil
}

func ServerFileName() string {
	name := "server-" + runtime.GOOS + "-" + runtime.GOARCH
	if runtime.GOOS == "windows" {
		name += ".exe"
	}
	return name
}

// Apply checks the signature, copies the school records to a timestamped
// backup, moves the schema forward only, then swaps the program.
// A failed start puts the previous program back. Records are not restored
// backwards and are not deleted.
func Apply(bundle []byte, cfg ApplyConfig) (Manifest, error) {
	if len(cfg.PublicKey) != ed25519.PublicKeySize {
		return Manifest{}, errors.New("this program has no update key")
	}
	manifest, files, err := Open(cfg.PublicKey, bundle)
	if err != nil {
		return Manifest{}, err
	}
	if err := os.MkdirAll(cfg.DataDir, 0o700); err != nil {
		return Manifest{}, err
	}
	dbPath := filepath.Join(cfg.DataDir, "school.db")
	current, err := schemaVersion(dbPath)
	if err != nil {
		return Manifest{}, err
	}
	if manifest.Schema < current {
		return Manifest{}, fmt.Errorf("this update is older than the school records (%d)", current)
	}
	stamp := time.Now().UTC().Format("20060102-150405")
	backup := filepath.Join(cfg.DataDir, "backups", "pre-update-"+stamp)
	if err := os.MkdirAll(backup, 0o700); err != nil {
		return Manifest{}, err
	}
	for _, name := range []string{"school.db", "school.db-wal", "school.db-shm", "licence.dat", "week.json"} {
		src := filepath.Join(cfg.DataDir, name)
		if _, err := os.Stat(src); err == nil {
			if err := copyFile(src, filepath.Join(backup, name)); err != nil {
				return Manifest{}, err
			}
		}
	}
	if err := migrateForward(dbPath, current, manifest.Schema); err != nil {
		return Manifest{}, err
	}
	nextName := ServerFileName()
	nextBody, ok := files[nextName]
	if !ok || len(nextBody) == 0 {
		return Manifest{}, fmt.Errorf("the update has no program for this computer (%s)", nextName)
	}
	if cfg.BinaryPath != "" {
		if err := swapBinary(cfg.BinaryPath, nextBody, cfg.Probe); err != nil {
			return Manifest{}, err
		}
	}
	clientDir := filepath.Join(cfg.DataDir, "clients")
	if err := os.MkdirAll(clientDir, 0o755); err != nil {
		return Manifest{}, err
	}
	for _, name := range []string{"client.apk", "client-windows.exe", "client-windows.zip"} {
		if body, ok := files[name]; ok {
			if err := os.WriteFile(filepath.Join(clientDir, name), body, 0o644); err != nil {
				return Manifest{}, err
			}
		}
	}
	if err := os.WriteFile(filepath.Join(cfg.DataDir, "client-version.txt"), []byte(manifest.Version), 0o644); err != nil {
		return Manifest{}, err
	}
	return manifest, nil
}

func swapBinary(path string, body []byte, probe func(string) error) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	prev := path + ".prev"
	if _, err := os.Stat(path); err == nil {
		if err := copyFile(path, prev); err != nil {
			return err
		}
	} else if err := os.WriteFile(prev, []byte("previous"), 0o755); err != nil {
		return err
	}
	tmp := path + ".new"
	if err := os.WriteFile(tmp, body, 0o755); err != nil {
		return err
	}
	if err := os.Rename(tmp, path); err != nil {
		return err
	}
	if probe != nil {
		if err := probe(path); err != nil {
			if restoreErr := copyFile(prev, path); restoreErr != nil {
				return fmt.Errorf("the new program failed (%v) and the old one could not be put back (%v)", err, restoreErr)
			}
			return fmt.Errorf("the new program did not start, so the previous one was put back: %w", err)
		}
	}
	return nil
}

// Rollback puts the previous program back. It does not touch school records.
func Rollback(binaryPath string) error {
	prev := binaryPath + ".prev"
	if _, err := os.Stat(prev); err != nil {
		return errors.New("there is no previous program to put back")
	}
	return copyFile(prev, binaryPath)
}

func copyFile(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}
	out, err := os.OpenFile(dst, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0o644)
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, in); err != nil {
		out.Close()
		return err
	}
	return out.Close()
}

func schemaVersion(dbPath string) (int, error) {
	if _, err := os.Stat(dbPath); err != nil {
		return 1, nil
	}
	db, err := sql.Open("sqlite", "file:"+dbPath+"?_pragma=busy_timeout(5000)")
	if err != nil {
		return 0, err
	}
	defer db.Close()
	var v string
	err = db.QueryRow(`SELECT value FROM settings WHERE key = 'schema_version'`).Scan(&v)
	if err != nil {
		return 1, nil
	}
	var n int
	fmt.Sscanf(v, "%d", &n)
	if n < 1 {
		n = 1
	}
	return n, nil
}

func migrateForward(dbPath string, current, target int) error {
	if target <= current {
		return nil
	}
	if _, err := os.Stat(dbPath); err != nil {
		return nil
	}
	db, err := sql.Open("sqlite", "file:"+dbPath+"?_pragma=busy_timeout(5000)")
	if err != nil {
		return err
	}
	defer db.Close()
	tx, err := db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if current < 2 && target >= 2 {
		if _, err := tx.Exec(`CREATE TABLE IF NOT EXISTS update_log (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			at TEXT NOT NULL,
			from_version INTEGER NOT NULL,
			to_version INTEGER NOT NULL,
			note TEXT NOT NULL
		)`); err != nil {
			return err
		}
		if _, err := tx.Exec(`INSERT INTO update_log (at, from_version, to_version, note) VALUES (?,?,?,?)`,
			time.Now().UTC().Format(time.RFC3339), current, target, "schema moved forward"); err != nil {
			return err
		}
	}
	if _, err := tx.Exec(`INSERT INTO settings (key, value) VALUES ('schema_version', ?)
		ON CONFLICT(key) DO UPDATE SET value = excluded.value`, fmt.Sprintf("%d", target)); err != nil {
		return err
	}
	return tx.Commit()
}

func sortStrings(in []string) {
	for i := 1; i < len(in); i++ {
		j := i
		for j > 0 && in[j] < in[j-1] {
			in[j], in[j-1] = in[j-1], in[j]
			j--
		}
	}
}
