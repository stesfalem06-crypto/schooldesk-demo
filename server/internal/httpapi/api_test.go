package httpapi

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"testing"
	"time"

	"schooldesk/internal/auth"
	"schooldesk/internal/license"
	"schooldesk/internal/store"
)

type staticGate struct {
	on     bool
	school string
	max    int
}

func (g staticGate) Current(time.Time) (license.Status, error) {
	return license.Status{Licensed: g.on, SchoolName: g.school, MachineID: "TEST-TEST-TEST-TEST", QRPayload: "SCH1:TEST-TEST-TEST-TEST", MaxDevices: g.max, Unlimited: g.max == 0}, nil
}

func (g staticGate) Activate(string, time.Time) (license.Status, error) {
	return g.Current(time.Now())
}

func TestLockedServerRefusesSignIn(t *testing.T) {
	api := newTestAPI(t, staticGate{on: false})
	body := bytes.NewBufferString(`{"username":"admin","password":"admin1850"}`)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/login", body)
	rec := httptest.NewRecorder()
	api.Handler().ServeHTTP(rec, req)
	if rec.Code != 423 {
		t.Fatalf("status %d body %s", rec.Code, rec.Body.String())
	}
}

func TestTeacherCannotChangeSchoolFee(t *testing.T) {
	api := newTestAPI(t, staticGate{on: true, school: "Hope Academy"})
	token := login(t, api, "samuel", "samuel1850")
	req := httptest.NewRequest(http.MethodPut, "/api/v1/settings", bytes.NewBufferString(`{"academic_year":"2026-2027","semester":1,"yearly_fee":1,"utility_fee":0,"weights":{"classwork":10,"quizzes":10,"tests":10,"assignments":10,"participation":10,"homework":10},"fail_limits":{"elementary":2,"junior":3,"high":3}}`))
	req.Header.Set("Authorization", "Bearer "+token)
	rec := httptest.NewRecorder()
	api.Handler().ServeHTTP(rec, req)
	if rec.Code != 403 {
		t.Fatalf("status %d %s", rec.Code, rec.Body.String())
	}
	admin := login(t, api, "admin", "admin1850")
	me := httptest.NewRequest(http.MethodGet, "/api/v1/auth/me", nil)
	me.Header.Set("Authorization", "Bearer "+admin)
	rec = httptest.NewRecorder()
	api.Handler().ServeHTTP(rec, me)
	if rec.Code != 200 || !bytes.Contains(rec.Body.Bytes(), []byte("Hope Academy")) {
		t.Fatalf("me %d %s", rec.Code, rec.Body.String())
	}
}

func newTestAPI(t *testing.T, gate Gate) *API {
	t.Helper()
	s, err := store.Open(filepath.Join(t.TempDir(), "school.db"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { s.Close() })
	for _, u := range []struct{ name, pass, role string }{
		{"admin", "admin1850", "admin"},
		{"samuel", "samuel1850", "teacher"},
	} {
		hash, err := auth.Hash(u.pass)
		if err != nil {
			t.Fatal(err)
		}
		if _, err := s.CreateUser(u.name, hash, u.role, "", u.name); err != nil {
			t.Fatal(err)
		}
	}
	return &API{Store: s, Gate: gate}
}

func login(t *testing.T, api *API, user, pass string) string {
	t.Helper()
	raw, _ := json.Marshal(map[string]string{"username": user, "password": pass, "device_id": "device-test-0001", "platform": "test"})
	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/login", bytes.NewReader(raw))
	rec := httptest.NewRecorder()
	api.Handler().ServeHTTP(rec, req)
	if rec.Code != 200 {
		t.Fatalf("login %d %s", rec.Code, rec.Body.String())
	}
	var out struct {
		Token string `json:"token"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &out); err != nil || out.Token == "" {
		t.Fatal(err, rec.Body.String())
	}
	return out.Token
}
