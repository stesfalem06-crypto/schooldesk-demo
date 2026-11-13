package license

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestLicenceFileOpensWithAnyTwoParts(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "licence.dat")
	parts := Parts{Board: "board-a", CPU: "cpu-b", Disk: "disk-c"}
	claims := Claims{SchoolName: "Hope Academy", IssueDay: 1047, ExpiryDay: 1411, MaxDevices: 40}
	now := time.Date(2026, 11, 13, 8, 0, 0, 0, time.UTC)
	if err := Seal(path, parts, claims, now); err != nil {
		t.Fatal(err)
	}
	original, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	try := func(p Parts) error {
		if err := os.WriteFile(path, original, 0o600); err != nil {
			t.Fatal(err)
		}
		_, _, err := Open(path, p, now.Add(time.Hour))
		return err
	}
	if err := try(parts); err != nil {
		t.Fatal(err)
	}
	if err := try(Parts{Board: "board-a", CPU: "cpu-b", Disk: "new-disk"}); err != nil {
		t.Fatal(err)
	}
	if err := try(Parts{Board: "board-a", CPU: "new-cpu", Disk: "disk-c"}); err != nil {
		t.Fatal(err)
	}
	if err := try(Parts{Board: "new-board", CPU: "cpu-b", Disk: "disk-c"}); err != nil {
		t.Fatal(err)
	}
	if err := try(Parts{Board: "board-a", CPU: "no", Disk: "no"}); err == nil {
		t.Fatal("one matching part opened the file")
	}
	if err := try(Parts{Board: "x", CPU: "y", Disk: "z"}); err == nil {
		t.Fatal("a copied file opened on another machine")
	}
}

func TestClockSetBackWhenExpiryIsSet(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "licence.dat")
	parts := Parts{Board: "b", CPU: "c", Disk: "d"}
	future := time.Date(2030, 1, 1, 0, 0, 0, 0, time.UTC)
	if err := Seal(path, parts, Claims{SchoolName: "A", IssueDay: 1, ExpiryDay: 5000, MaxDevices: 2}, future); err != nil {
		t.Fatal(err)
	}
	if _, _, err := Open(path, parts, future.Add(-48*time.Hour)); err == nil {
		t.Fatal("clock set back was accepted")
	}
	// No expiry: a backwards clock does not lock the file.
	path2 := filepath.Join(dir, "forever.dat")
	if err := Seal(path2, parts, Claims{SchoolName: "A", IssueDay: 1, ExpiryDay: 0, MaxDevices: 0}, future); err != nil {
		t.Fatal(err)
	}
	claims, _, err := Open(path2, parts, future.Add(-48*time.Hour))
	if err != nil {
		t.Fatal(err)
	}
	if !claims.NeverExpires() || !claims.UnlimitedDevices() {
		t.Fatalf("%+v", claims)
	}
}
