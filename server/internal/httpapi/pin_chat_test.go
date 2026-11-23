package httpapi

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"schooldesk/internal/auth"
	"schooldesk/internal/store"
)

func TestPINSignInAndChatStorage(t *testing.T) {
	api := newTestAPI(t, staticGate{on: true, school: "Hope Academy"})
	adminToken := login(t, api, "admin", "admin1850")
	peopleReq := httptest.NewRequest(http.MethodGet, "/api/v1/auth/people", nil)
	peopleRec := httptest.NewRecorder()
	api.Handler().ServeHTTP(peopleRec, peopleReq)
	if peopleRec.Code != 200 {
		t.Fatalf("people %d %s", peopleRec.Code, peopleRec.Body.String())
	}
	var people []store.Person
	if err := json.Unmarshal(peopleRec.Body.Bytes(), &people); err != nil {
		t.Fatal(err)
	}
	if bytes.Contains(peopleRec.Body.Bytes(), []byte("pin")) {
		t.Fatalf("the name list must not carry a PIN: %s", peopleRec.Body.String())
	}
	var samuel store.Person
	for _, p := range people {
		if p.DisplayName == "samuel" || p.Role == "teacher" {
			samuel = p
		}
	}
	if samuel.ID == "" {
		t.Fatal("teacher missing from the name list")
	}
	body := bytes.NewBufferString(`{"pin":"1853"}`)
	set := httptest.NewRequest(http.MethodPost, "/api/v1/users/"+samuel.ID+"/pin", body)
	set.Header.Set("Authorization", "Bearer "+adminToken)
	setRec := httptest.NewRecorder()
	api.Handler().ServeHTTP(setRec, set)
	if setRec.Code != 200 {
		t.Fatalf("set pin %d %s", setRec.Code, setRec.Body.String())
	}
	raw, _ := json.Marshal(map[string]string{"user_id": samuel.ID, "pin": "1853", "device_id": "phone-0001"})
	pinReq := httptest.NewRequest(http.MethodPost, "/api/v1/auth/pin", bytes.NewReader(raw))
	pinRec := httptest.NewRecorder()
	api.Handler().ServeHTTP(pinRec, pinReq)
	if pinRec.Code != 200 {
		t.Fatalf("pin login %d %s", pinRec.Code, pinRec.Body.String())
	}
	var signed struct {
		Token string     `json:"token"`
		User  store.User `json:"user"`
	}
	if err := json.Unmarshal(pinRec.Body.Bytes(), &signed); err != nil || signed.Token == "" {
		t.Fatal(pinRec.Body.String())
	}
	bad, _ := json.Marshal(map[string]string{"user_id": samuel.ID, "pin": "0000"})
	badReq := httptest.NewRequest(http.MethodPost, "/api/v1/auth/pin", bytes.NewReader(bad))
	badRec := httptest.NewRecorder()
	api.Handler().ServeHTTP(badRec, badReq)
	if badRec.Code == 200 {
		t.Fatal("a wrong PIN was accepted")
	}

	msgBody, _ := json.Marshal(map[string]string{"to": "staff", "body": "Staff meeting at the hall"})
	post := httptest.NewRequest(http.MethodPost, "/api/v1/chat/messages", bytes.NewReader(msgBody))
	post.Header.Set("Authorization", "Bearer "+signed.Token)
	postRec := httptest.NewRecorder()
	api.Handler().ServeHTTP(postRec, post)
	if postRec.Code != 200 {
		t.Fatalf("chat %d %s", postRec.Code, postRec.Body.String())
	}
	list := httptest.NewRequest(http.MethodGet, "/api/v1/chat/messages?with=staff", nil)
	list.Header.Set("Authorization", "Bearer "+adminToken)
	listRec := httptest.NewRecorder()
	api.Handler().ServeHTTP(listRec, list)
	if listRec.Code != 200 || !bytes.Contains(listRec.Body.Bytes(), []byte("Staff meeting at the hall")) {
		t.Fatalf("stored chat %d %s", listRec.Code, listRec.Body.String())
	}

	signal, _ := json.Marshal(map[string]string{"to": signed.User.ID, "type": "ring"})
	sig := httptest.NewRequest(http.MethodPost, "/api/v1/calls/signal", bytes.NewReader(signal))
	sig.Header.Set("Authorization", "Bearer "+adminToken)
	sigRec := httptest.NewRecorder()
	api.Handler().ServeHTTP(sigRec, sig)
	if sigRec.Code != 200 {
		t.Fatalf("signal %d %s", sigRec.Code, sigRec.Body.String())
	}
	inbox := httptest.NewRequest(http.MethodGet, "/api/v1/calls/inbox", nil)
	inbox.Header.Set("Authorization", "Bearer "+signed.Token)
	inboxRec := httptest.NewRecorder()
	api.Handler().ServeHTTP(inboxRec, inbox)
	if inboxRec.Code != 200 || !bytes.Contains(inboxRec.Body.Bytes(), []byte(`"type":"ring"`)) {
		t.Fatalf("inbox %d %s", inboxRec.Code, inboxRec.Body.String())
	}
}

func TestAttendanceKeepsTheNewerWrite(t *testing.T) {
	api := newTestAPI(t, staticGate{on: true, school: "Hope Academy"})
	staff, err := api.Store.SaveStaff(store.Staff{FullName: "Hanna Gebre", Sex: "F", StaffType: "teaching"})
	if err != nil {
		t.Fatal(err)
	}
	class, err := api.Store.SaveClass(store.Class{Name: "1-1", Level: "elementary", Grade: 1, AcademicYear: "2026-2027", HomeroomStaffID: staff.ID})
	if err != nil {
		t.Fatal(err)
	}
	student, err := api.Store.SaveStudent(store.Student{FullName: "Biniam Haile", Sex: "M", ClassID: class.ID})
	if err != nil {
		t.Fatal(err)
	}
	admin := login(t, api, "admin", "admin1850")
	send := func(status, when string) *httptest.ResponseRecorder {
		t.Helper()
		raw, _ := json.Marshal(map[string]any{
			"class_id": class.ID, "student_id": student.ID, "roll_number": 1,
			"date": "2026-11-23", "status": status, "updated_at": when, "source_id": "phone-a",
		})
		req := httptest.NewRequest(http.MethodPost, "/api/v1/attendance", bytes.NewReader(raw))
		req.Header.Set("Authorization", "Bearer "+admin)
		rec := httptest.NewRecorder()
		api.Handler().ServeHTTP(rec, req)
		return rec
	}
	if rec := send("absent", "2026-11-23T10:00:00Z"); rec.Code != 200 {
		t.Fatal(rec.Body.String())
	}
	if rec := send("present", "2026-11-23T09:00:00Z"); rec.Code != 200 || !bytes.Contains(rec.Body.Bytes(), []byte(`"kept_newer":true`)) {
		t.Fatalf("older write should be kept aside: %s", rec.Body.String())
	}
	rows, err := api.Store.AttendanceOn(class.ID, "2026-11-23")
	if err != nil || len(rows) != 1 || rows[0].Status != "absent" {
		t.Fatalf("attendance %+v %v", rows, err)
	}
	_ = auth.ErrPIN
}

func TestStatusPageShowsAddressAndFooter(t *testing.T) {
	api := newTestAPI(t, staticGate{on: false, school: "Hope Academy"})
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	req.Host = "192.168.1.20:8741"
	rec := httptest.NewRecorder()
	api.Handler().ServeHTTP(rec, req)
	if rec.Code != 200 {
		t.Fatal(rec.Code)
	}
	body := rec.Body.String()
	for _, part := range []string{"Shamm School Management Systems", "192.168.1.20:8741", "9 Multimedia and IT solutions · SHAMM TESFALEM · 07162947", "/api/v1/join.png"} {
		if !bytes.Contains([]byte(body), []byte(part)) {
			t.Fatalf("status page missing %s", part)
		}
	}
}
