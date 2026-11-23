package update

import (
	"crypto/ed25519"
	"os"
	"path/filepath"
	"testing"

	"schooldesk/internal/store"
)

func TestUpdateKeepsSchoolData(t *testing.T) {
	dir := t.TempDir()
	dbPath := filepath.Join(dir, "school.db")
	s, err := store.Open(dbPath)
	if err != nil {
		t.Fatal(err)
	}
	_, student, err := keepPupil(s, "1-1", "elementary", 1, "Abel Tesfamariam", "M")
	if err != nil {
		t.Fatal(err)
	}
	if err := s.Close(); err != nil {
		t.Fatal(err)
	}

	pub, priv, err := ed25519.GenerateKey(nil)
	if err != nil {
		t.Fatal(err)
	}
	binary := filepath.Join(dir, "schooldesk-server")
	if err := os.WriteFile(binary, []byte("old-program"), 0o755); err != nil {
		t.Fatal(err)
	}
	bundle, err := Sign(priv, Manifest{Product: Product, Version: "sms-v1", Schema: 2}, map[string][]byte{
		ServerFileName():     []byte("new-program"),
		"client.apk":         []byte("apk-bytes"),
		"client-windows.exe": []byte("setup-bytes"),
	})
	if err != nil {
		t.Fatal(err)
	}
	manifest, err := Apply(bundle, ApplyConfig{PublicKey: pub, DataDir: dir, BinaryPath: binary})
	if err != nil {
		t.Fatal(err)
	}
	if manifest.Version != "sms-v1" {
		t.Fatalf("version %s", manifest.Version)
	}
	got, err := os.ReadFile(binary)
	if err != nil || string(got) != "new-program" {
		t.Fatalf("binary %q %v", got, err)
	}
	apk, err := os.ReadFile(filepath.Join(dir, "clients", "client.apk"))
	if err != nil || string(apk) != "apk-bytes" {
		t.Fatalf("apk %q %v", apk, err)
	}
	reopen, err := store.Open(dbPath)
	if err != nil {
		t.Fatal(err)
	}
	defer reopen.Close()
	students, err := reopen.ListStudents("")
	if err != nil {
		t.Fatal(err)
	}
	if len(students) != 1 || students[0].ID != student.ID || students[0].FullName != "Abel Tesfamariam" {
		t.Fatalf("students after update: %+v", students)
	}
	version, err := reopen.SchemaVersion()
	if err != nil || version != 2 {
		t.Fatalf("schema %d %v", version, err)
	}
	var notes int
	if err := reopenDBCount(dbPath, &notes); err != nil || notes != 1 {
		t.Fatalf("update log %d %v", notes, err)
	}
	backups, err := filepath.Glob(filepath.Join(dir, "backups", "pre-update-*", "school.db"))
	if err != nil || len(backups) != 1 {
		t.Fatalf("backup copies %v %v", backups, err)
	}
}

func TestBadUpdateDoesNotTouchData(t *testing.T) {
	dir := t.TempDir()
	dbPath := filepath.Join(dir, "school.db")
	s, err := store.Open(dbPath)
	if err != nil {
		t.Fatal(err)
	}
	if _, _, err := keepPupil(s, "8-1", "junior", 8, "Selam Ghebremedhin", "F"); err != nil {
		t.Fatal(err)
	}
	s.Close()
	pub, priv, _ := ed25519.GenerateKey(nil)
	binary := filepath.Join(dir, "server")
	os.WriteFile(binary, []byte("keep-me"), 0o755)
	bundle, err := Sign(priv, Manifest{Version: "sms-v9", Schema: 2}, map[string][]byte{ServerFileName(): []byte("bad")})
	if err != nil {
		t.Fatal(err)
	}
	bundle[len(bundle)/2] ^= 0x5a
	if _, err := Apply(bundle, ApplyConfig{PublicKey: pub, DataDir: dir, BinaryPath: binary}); err == nil {
		t.Fatal("a broken signature was accepted")
	}
	body, _ := os.ReadFile(binary)
	if string(body) != "keep-me" {
		t.Fatalf("binary changed to %q", body)
	}
	reopen, err := store.Open(dbPath)
	if err != nil {
		t.Fatal(err)
	}
	defer reopen.Close()
	students, err := reopen.ListStudents("")
	if err != nil || len(students) != 1 || students[0].FullName != "Selam Ghebremedhin" {
		t.Fatalf("students %+v %v", students, err)
	}
}

func TestFailedStartRollsBackProgramOnly(t *testing.T) {
	dir := t.TempDir()
	dbPath := filepath.Join(dir, "school.db")
	s, _ := store.Open(dbPath)
	if _, _, err := keepPupil(s, "5-2", "elementary", 5, "Yonas Habte", "M"); err != nil {
		t.Fatal(err)
	}
	s.Close()
	pub, priv, _ := ed25519.GenerateKey(nil)
	binary := filepath.Join(dir, "server")
	os.WriteFile(binary, []byte("stable"), 0o755)
	bundle, err := Sign(priv, Manifest{Version: "sms-v2", Schema: 2}, map[string][]byte{ServerFileName(): []byte("broken")})
	if err != nil {
		t.Fatal(err)
	}
	_, err = Apply(bundle, ApplyConfig{
		PublicKey: pub, DataDir: dir, BinaryPath: binary,
		Probe: func(string) error { return os.ErrInvalid },
	})
	if err == nil {
		t.Fatal("expected the start check to fail")
	}
	body, _ := os.ReadFile(binary)
	if string(body) != "stable" {
		t.Fatalf("program was not put back: %q", body)
	}
	reopen, err := store.Open(dbPath)
	if err != nil {
		t.Fatal(err)
	}
	defer reopen.Close()
	students, err := reopen.ListStudents("")
	if err != nil || len(students) != 1 || students[0].FullName != "Yonas Habte" {
		t.Fatalf("data changed %+v %v", students, err)
	}
	if v, _ := reopen.SchemaVersion(); v != 2 {
		t.Fatalf("schema should stay forward at 2, got %d", v)
	}
}

func keepPupil(s *store.Store, className, level string, grade int, name, sex string) (store.Class, store.Student, error) {
	staff, err := s.SaveStaff(store.Staff{FullName: "Hanna Gebre", Sex: "F", StaffType: "teaching"})
	if err != nil {
		return store.Class{}, store.Student{}, err
	}
	class, err := s.SaveClass(store.Class{Name: className, Level: level, Grade: grade, AcademicYear: "2026-2027", HomeroomStaffID: staff.ID})
	if err != nil {
		return store.Class{}, store.Student{}, err
	}
	student, err := s.SaveStudent(store.Student{FullName: name, Sex: sex, MotherName: "Sara", ClassID: class.ID})
	return class, student, err
}

func reopenDBCount(path string, notes *int) error {
	s, err := store.Open(path)
	if err != nil {
		return err
	}
	defer s.Close()
	return s.DBCount(`SELECT COUNT(*) FROM update_log`, notes)
}
