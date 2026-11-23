package httpapi

import (
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"crypto/ed25519"
	"encoding/base64"

	"schooldesk/internal/brand"
	"schooldesk/internal/update"
)

func (a *API) uploadUpdate(w http.ResponseWriter, r *http.Request) {
	if !isLocal(r) {
		a.fail(w, 403, "Plug the file in on the school computer")
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, 256<<20)
	var body []byte
	var err error
	if strings.HasPrefix(r.Header.Get("Content-Type"), "multipart/") {
		if err = r.ParseMultipartForm(256 << 20); err != nil {
			a.fail(w, 400, "That file could not be read")
			return
		}
		file, _, err := r.FormFile("file")
		if err != nil {
			a.fail(w, 400, "Choose the update file")
			return
		}
		defer file.Close()
		body, err = io.ReadAll(file)
		if err != nil {
			a.fail(w, 400, "That file could not be read")
			return
		}
	} else {
		body, err = io.ReadAll(r.Body)
		if err != nil || len(body) == 0 {
			a.fail(w, 400, "Choose the update file")
			return
		}
	}
	key, err := a.updateKey()
	if err != nil {
		a.fail(w, 400, err.Error())
		return
	}
	manifest, err := update.Apply(body, update.ApplyConfig{
		PublicKey:  key,
		DataDir:    a.dataDir(),
		BinaryPath: a.Binary,
		Probe: func(path string) error {
			// A program that is not executable still has to be the file we just wrote.
			info, err := os.Stat(path)
			if err != nil || info.Size() == 0 {
				return err
			}
			return nil
		},
	})
	if err != nil {
		a.fail(w, 400, err.Error())
		return
	}
	if a.OnRestart != nil {
		a.ok(w, map[string]any{"ok": true, "version": manifest.Version, "message": "Updated. The school computer will open the new program."})
		go a.OnRestart()
		return
	}
	a.ok(w, map[string]any{"ok": true, "version": manifest.Version, "message": "Updated. The school records were kept."})
}

func (a *API) rollbackUpdate(w http.ResponseWriter, r *http.Request) {
	if !isLocal(r) {
		a.fail(w, 403, "Do this on the school computer")
		return
	}
	if a.Binary == "" {
		a.fail(w, 400, "There is no previous program to put back")
		return
	}
	if err := update.Rollback(a.Binary); err != nil {
		a.fail(w, 400, err.Error())
		return
	}
	a.ok(w, map[string]any{"ok": true, "message": "The previous program is back. The school records were not changed."})
	if a.OnRestart != nil {
		go a.OnRestart()
	}
}

func (a *API) clientInfo(w http.ResponseWriter, r *http.Request) {
	version := brand.Version
	path := filepath.Join(a.dataDir(), "client-version.txt")
	if raw, err := os.ReadFile(path); err == nil && strings.TrimSpace(string(raw)) != "" {
		version = strings.TrimSpace(string(raw))
	}
	a.ok(w, map[string]any{
		"product": brand.Product,
		"version": version,
		"android": "/api/v1/client/file/client.apk",
		"windows": "/api/v1/client/file/client-windows.exe",
	})
}

func (a *API) clientFile(w http.ResponseWriter, r *http.Request) {
	name := r.PathValue("name")
	switch name {
	case "client.apk", "client-windows.exe", "client-windows.zip":
	default:
		a.fail(w, 404, "That file is not here")
		return
	}
	path := filepath.Join(a.dataDir(), "clients", name)
	http.ServeFile(w, r, path)
}

func (a *API) dataDir() string {
	if a.DataDir != "" {
		return a.DataDir
	}
	if a.Store != nil {
		return filepath.Dir(a.Store.Path())
	}
	return "data"
}

func (a *API) updateKey() (ed25519.PublicKey, error) {
	if raw, err := os.ReadFile(filepath.Join(a.dataDir(), "update.pub")); err == nil {
		decoded, err := base64.StdEncoding.DecodeString(strings.TrimSpace(string(raw)))
		if err == nil && len(decoded) == ed25519.PublicKeySize {
			return ed25519.PublicKey(decoded), nil
		}
	}
	return update.EmbeddedKey()
}
