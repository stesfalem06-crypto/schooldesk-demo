package httpapi

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"testing"

	"schooldesk/internal/license"
	"schooldesk/internal/seed"
	"schooldesk/internal/store"
)

func TestRolesStayInTheirWork(t *testing.T) {
	s, err := store.Open(filepath.Join(t.TempDir(), "school.db"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { s.Close() })
	if err := seed.Preview(s); err != nil {
		t.Fatal(err)
	}
	api := &API{Store: s, Gate: staticGate{on: true, school: "Hope Academy"}}
	admin := login(t, api, "admin", "admin1850")
	meron := login(t, api, "meron", "meron1850")
	samuel := login(t, api, "samuel", "samuel1850")
	students, err := s.ListStudents("")
	if err != nil || len(students) == 0 {
		t.Fatal(err)
	}
	var grade8 string
	for _, st := range students {
		if st.FullName == "Bereket Hailu" {
			grade8 = st.ID
		}
	}
	if code := call(api, http.MethodPost, "/api/v1/students/"+grade8+"/dropout", admin, `{"dropped":true,"reason":"","date":"2026-11-13"}`); code != 403 {
		t.Fatalf("admin dropout %d", code)
	}
	if code := call(api, http.MethodPost, "/api/v1/fees", meron, `{"student_id":"`+grade8+`","amount":10,"paid_on":"2026-11-13"}`); code != 403 {
		t.Fatalf("subject teacher fee %d", code)
	}
	if code := call(api, http.MethodPost, "/api/v1/fees", samuel, `{"student_id":"`+grade8+`","amount":10,"paid_on":"2026-11-13"}`); code != 200 {
		t.Fatalf("homeroom fee %d", code)
	}
	classes, err := s.ListClasses()
	if err != nil {
		t.Fatal(err)
	}
	var samuelID string
	for _, c := range classes {
		if c.Name == "Grade 8A" {
			samuelID = c.HomeroomStaffID
		}
	}
	if _, err := s.SaveClass(store.Class{Name: "Grade 9A", Level: "high", Grade: 9, AcademicYear: "2026-2027", HomeroomStaffID: samuelID}); err == nil {
		t.Fatal("a teacher was given a second class")
	}
	slots, err := s.Timetable()
	if err != nil || len(slots) == 0 {
		t.Fatalf("demo timetable %d %v", len(slots), err)
	}
	if code := call(api, http.MethodGet, "/api/v1/summary/fees", admin, ""); code != 200 {
		t.Fatalf("fees %d", code)
	}
	if code := call(api, http.MethodGet, "/api/v1/summary/results", admin, ""); code != 200 {
		t.Fatalf("results %d", code)
	}
	req := httptest.NewRequest(http.MethodGet, "/api/v1/class-subjects", nil)
	req.Header.Set("Authorization", "Bearer "+samuel)
	rec := httptest.NewRecorder()
	api.Handler().ServeHTTP(rec, req)
	if rec.Code != 200 {
		t.Fatal(rec.Body.String())
	}
	var subjects []store.ClassSubject
	if err := json.Unmarshal(rec.Body.Bytes(), &subjects); err != nil {
		t.Fatal(err)
	}
	var sawOwn, sawOther bool
	for _, cs := range subjects {
		if cs.ClassName == "Grade 8A" && cs.TeacherStaffID != samuelID {
			sawOther = true
			if cs.CanEdit {
				t.Fatal("homeroom can edit another teacher's marks")
			}
		}
		if cs.CanEdit {
			sawOwn = true
		}
	}
	if !sawOwn || !sawOther {
		t.Fatalf("samuel subjects own=%v other=%v count=%d", sawOwn, sawOther, len(subjects))
	}
	_ = license.Status{}
}

func call(api *API, method, path, token, body string) int {
	var buf *bytes.Reader
	if body == "" {
		buf = bytes.NewReader(nil)
	} else {
		buf = bytes.NewReader([]byte(body))
	}
	req := httptest.NewRequest(method, path, buf)
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	rec := httptest.NewRecorder()
	api.Handler().ServeHTTP(rec, req)
	return rec.Code
}
