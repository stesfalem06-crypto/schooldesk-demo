package httpapi

import (
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	"schooldesk/internal/auth"
	"schooldesk/internal/store"
)

func (a *API) people(w http.ResponseWriter, r *http.Request) {
	list, err := a.Store.ListPeople()
	if list == nil {
		list = []store.Person{}
	}
	a.call(w, err, list)
}

func (a *API) pinLogin(w http.ResponseWriter, r *http.Request) {
	var in struct {
		UserID     string `json:"user_id"`
		PIN        string `json:"pin"`
		DeviceID   string `json:"device_id"`
		DeviceName string `json:"device_name"`
		Platform   string `json:"platform"`
	}
	if !a.read(w, r, &in) {
		return
	}
	ip := clientIP(r)
	if a.limited(ip) {
		a.fail(w, 429, "Wait a few minutes, then try again")
		return
	}
	hash, err := a.Store.PINHash(in.UserID)
	if err != nil || hash == "" || !auth.Check(hash, in.PIN) {
		a.markFail(ip)
		if hash == "" && err == nil {
			a.fail(w, 401, "Ask the admin to set your number")
			return
		}
		a.fail(w, 401, "That number is not right")
		return
	}
	u, err := a.Store.UserByID(in.UserID)
	if err != nil || !u.Active {
		a.fail(w, 401, "That number is not right")
		return
	}
	st, _ := a.Gate.Current(a.now())
	max := st.MaxDevices
	if st.Unlimited {
		max = 0
	}
	if err := a.Store.TouchDevice(in.DeviceID, in.DeviceName, in.Platform, max); err != nil {
		a.fail(w, 403, err.Error())
		return
	}
	token := newToken()
	if err := a.Store.CreateSession(u.ID, token, 16*time.Hour); err != nil {
		a.fail(w, 500, "Sign in could not be saved")
		return
	}
	a.Store.Audit(u.ID, "pin-login", u.DisplayName)
	a.ok(w, map[string]any{"token": token, "user": u, "school_name": st.SchoolName})
}

func (a *API) setPIN(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.must(w, r, "admin"); !ok {
		return
	}
	var in struct {
		PIN string `json:"pin"`
	}
	if !a.read(w, r, &in) {
		return
	}
	hash, err := auth.HashPIN(strings.TrimSpace(in.PIN))
	if err != nil {
		a.fail(w, 400, err.Error())
		return
	}
	a.call(w, a.Store.SetPIN(r.PathValue("id"), hash), map[string]bool{"ok": true})
}

func (a *API) listMessages(w http.ResponseWriter, r *http.Request) {
	u, ok := a.user(w, r)
	if !ok {
		return
	}
	with := r.URL.Query().Get("with")
	if with == "" {
		with = store.StaffRoom
	}
	list, err := a.Store.Messages(u.ID, with, 100)
	if list == nil {
		list = []store.Message{}
	}
	a.call(w, err, list)
}

func (a *API) postMessage(w http.ResponseWriter, r *http.Request) {
	u, ok := a.user(w, r)
	if !ok {
		return
	}
	var in struct {
		To   string `json:"to"`
		Body string `json:"body"`
	}
	if !a.read(w, r, &in) {
		return
	}
	if in.To == "" {
		in.To = store.StaffRoom
	}
	msg, err := a.Store.AddMessage(u.ID, in.To, in.Body)
	a.call(w, err, msg)
}

type signalMsg struct {
	From      string `json:"from"`
	FromName  string `json:"from_name"`
	To        string `json:"to"`
	Type      string `json:"type"`
	SDP       string `json:"sdp,omitempty"`
	Candidate string `json:"candidate,omitempty"`
}

type callHub struct {
	mu    sync.Mutex
	boxes map[string][]signalMsg
}

func (a *API) hub() *callHub {
	a.mu.Lock()
	defer a.mu.Unlock()
	if a.calls == nil {
		a.calls = &callHub{boxes: map[string][]signalMsg{}}
	}
	return a.calls
}

func (a *API) postSignal(w http.ResponseWriter, r *http.Request) {
	u, ok := a.user(w, r)
	if !ok {
		return
	}
	var in signalMsg
	if !a.read(w, r, &in) {
		return
	}
	switch in.Type {
	case "ring", "offer", "answer", "ice", "hangup", "reject":
	default:
		a.fail(w, 400, "That call message is not understood")
		return
	}
	if in.To == "" || in.To == u.ID {
		a.fail(w, 400, "Choose one person to call")
		return
	}
	if _, err := a.Store.UserByID(in.To); err != nil {
		a.fail(w, 400, "That person is not on the staff list")
		return
	}
	in.From = u.ID
	in.FromName = u.DisplayName
	h := a.hub()
	h.mu.Lock()
	h.boxes[in.To] = append(h.boxes[in.To], in)
	if len(h.boxes[in.To]) > 80 {
		h.boxes[in.To] = h.boxes[in.To][len(h.boxes[in.To])-80:]
	}
	h.mu.Unlock()
	a.ok(w, map[string]bool{"ok": true})
}

func (a *API) callInbox(w http.ResponseWriter, r *http.Request) {
	u, ok := a.user(w, r)
	if !ok {
		return
	}
	h := a.hub()
	h.mu.Lock()
	list := h.boxes[u.ID]
	delete(h.boxes, u.ID)
	h.mu.Unlock()
	if list == nil {
		list = []signalMsg{}
	}
	a.ok(w, list)
}

func (a *API) attendance(w http.ResponseWriter, r *http.Request) {
	u, ok := a.user(w, r)
	if !ok {
		return
	}
	classID := r.URL.Query().Get("class_id")
	if classID != "" && !a.canSeeClass(u, classID) {
		a.fail(w, 403, "You cannot open that class")
		return
	}
	day := r.URL.Query().Get("date")
	if day == "" {
		day = a.now().Format("2006-01-02")
	}
	list, err := a.Store.AttendanceOn(classID, day)
	if list == nil {
		list = []store.Attendance{}
	}
	a.call(w, err, list)
}

func (a *API) saveAttendance(w http.ResponseWriter, r *http.Request) {
	u, ok := a.user(w, r)
	if !ok {
		return
	}
	var in store.Attendance
	if !a.read(w, r, &in) {
		return
	}
	if !u.SeesSchool() && !a.canHomeroom(u, in.ClassID) {
		a.fail(w, 403, "Only the homeroom teacher records attendance")
		return
	}
	got, kept, err := a.Store.SaveAttendance(u.ID, in)
	if err != nil {
		a.fail(w, 400, err.Error())
		return
	}
	a.ok(w, map[string]any{"attendance": got, "kept_newer": kept})
}

func (a *API) markByNumbers(w http.ResponseWriter, r *http.Request) {
	u, ok := a.user(w, r)
	if !ok {
		return
	}
	var in struct {
		ClassID string `json:"class_id"`
		Date    string `json:"date"`
		Absent  []int  `json:"absent"`
		Source  string `json:"source_id"`
		Updated string `json:"updated_at"`
	}
	if !a.read(w, r, &in) {
		return
	}
	if !u.SeesSchool() && !a.canHomeroom(u, in.ClassID) {
		a.fail(w, 403, "Only the homeroom teacher records attendance")
		return
	}
	students, err := a.Store.ListStudents(in.ClassID)
	if err != nil {
		a.fail(w, 400, err.Error())
		return
	}
	absent := map[int]bool{}
	for _, n := range in.Absent {
		absent[n] = true
	}
	var saved []store.Attendance
	roll := 0
	for _, st := range students {
		roll++
		if st.DroppedOut {
			continue
		}
		status := "present"
		if absent[roll] {
			status = "absent"
		}
		got, _, err := a.Store.SaveAttendance(u.ID, store.Attendance{
			ClassID: st.ClassID, StudentID: st.ID, RollNumber: roll, Day: in.Date,
			Status: status, UpdatedAt: in.Updated, SourceID: in.Source,
		})
		if err != nil {
			a.fail(w, 400, err.Error())
			return
		}
		saved = append(saved, got)
	}
	a.ok(w, saved)
}

func atoiQuery(r *http.Request, key string) int {
	n, _ := strconv.Atoi(r.URL.Query().Get(key))
	return n
}
