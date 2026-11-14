//go:build schooldeskdemo

package main

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"schooldesk/internal/license"
)

func TestDemoStaysOpenWhenTheLicenceFileIsBroken(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "licence.dat")
	if err := os.WriteFile(path, []byte("not a licence"), 0o600); err != nil {
		t.Fatal(err)
	}
	gate := demoGate{fileGate: fileGate{path: path, parts: license.Parts{Board: "demo"}}}
	st, err := gate.Current(time.Now())
	if err != nil || !st.Licensed || st.SchoolName == "" {
		t.Fatalf("status %+v err %v", st, err)
	}
}
