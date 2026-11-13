package httpapi

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"net"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/skip2/go-qrcode"

	"schooldesk/internal/auth"
	"schooldesk/internal/license"
	"schooldesk/internal/store"
)

type Gate interface {
	Current(time.Time) (license.Status, error)
	Activate(string, time.Time) (license.Status, error)
}

type API struct {
	Store *store.Store
	Gate  Gate
	Now   func() time.Time

	mu    sync.Mutex
	fails map[string][]time.Time
}

func (a *API) now() time.Time {
	if a.Now != nil {
		return a.Now()
	}
	return time.Now()
}

func (a *API) Handler() http.Handler {
	mux := http.NewServeMux()
	a.routes(mux)
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("Cache-Control", "no-store")
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		if r.URL.Path == "/" {
			w.Header().Set("Content-Type", "text/html; charset=utf-8")
			_, _ = w.Write(lockPage)
			return
		}
		if !openPath(r.URL.Path) {
			st, err := a.Gate.Current(a.now())
			if err != nil || !st.Licensed {
				msg := "This school is locked"
				if st.Message != "" {
					msg = st.Message
				}
				writeJSON(w, 423, map[string]any{"error": msg, "locked": true})
				return
			}
		}
		mux.ServeHTTP(w, r)
	})
}

func openPath(p string) bool {
	switch p {
	case "/api/v1/health", "/api/v1/license", "/api/v1/license/activate", "/api/v1/license/qr.png":
		return true
	default:
		return false
	}
}

func (a *API) routes(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/v1/health", a.health)
	mux.HandleFunc("GET /api/v1/license", a.licenseStatus)
	mux.HandleFunc("POST /api/v1/license/activate", a.activate)
	mux.HandleFunc("GET /api/v1/license/qr.png", a.qr)
	mux.HandleFunc("POST /api/v1/auth/login", a.login)
	mux.HandleFunc("POST /api/v1/auth/logout", a.logout)
	mux.HandleFunc("GET /api/v1/auth/me", a.me)
	mux.HandleFunc("POST /api/v1/auth/password", a.password)
	mux.HandleFunc("GET /api/v1/settings", a.getSettings)
	mux.HandleFunc("PUT /api/v1/settings", a.putSettings)
	mux.HandleFunc("GET /api/v1/dashboard", a.dashboard)
	mux.HandleFunc("GET /api/v1/staff", a.listStaff)
	mux.HandleFunc("POST /api/v1/staff", a.saveStaff)
	mux.HandleFunc("GET /api/v1/staff/stats", a.staffStats)
	mux.HandleFunc("GET /api/v1/classes", a.listClasses)
	mux.HandleFunc("POST /api/v1/classes", a.saveClass)
	mux.HandleFunc("GET /api/v1/subjects", a.listSubjects)
	mux.HandleFunc("POST /api/v1/subjects", a.saveSubject)
	mux.HandleFunc("GET /api/v1/class-subjects", a.listClassSubjects)
	mux.HandleFunc("POST /api/v1/class-subjects", a.addClassSubject)
	mux.HandleFunc("PUT /api/v1/class-subjects/{id}/weights", a.setWeights)
	mux.HandleFunc("GET /api/v1/fields", a.listFields)
	mux.HandleFunc("POST /api/v1/fields", a.addField)
	mux.HandleFunc("GET /api/v1/students", a.listStudents)
	mux.HandleFunc("POST /api/v1/students", a.saveStudent)
	mux.HandleFunc("POST /api/v1/students/{id}/dropout", a.dropout)
	mux.HandleFunc("GET /api/v1/classes/{id}/summary", a.classSummary)
	mux.HandleFunc("GET /api/v1/classes/{id}/results", a.results)
	mux.HandleFunc("GET /api/v1/classes/{id}/marksheet.pdf", a.marksheet)
	mux.HandleFunc("GET /api/v1/assessments", a.listAssessments)
	mux.HandleFunc("POST /api/v1/assessments", a.addAssessment)
	mux.HandleFunc("GET /api/v1/scores", a.listScores)
	mux.HandleFunc("POST /api/v1/scores", a.setScore)
	mux.HandleFunc("POST /api/v1/scores/undo", a.undoScore)
	mux.HandleFunc("GET /api/v1/summary/fees", a.feeSummary)
	mux.HandleFunc("GET /api/v1/summary/results", a.standingSummary)
	mux.HandleFunc("GET /api/v1/fees", a.feeRows)
	mux.HandleFunc("POST /api/v1/fees", a.addPayment)
	mux.HandleFunc("GET /api/v1/finance", a.finance)
	mux.HandleFunc("GET /api/v1/incomes", a.listIncomes)
	mux.HandleFunc("POST /api/v1/incomes", a.addIncome)
	mux.HandleFunc("GET /api/v1/expenses", a.listExpenses)
	mux.HandleFunc("POST /api/v1/expenses", a.addExpense)
	mux.HandleFunc("GET /api/v1/workshops", a.listWorkshops)
	mux.HandleFunc("POST /api/v1/workshops", a.addWorkshop)
	mux.HandleFunc("GET /api/v1/sports", a.listSports)
	mux.HandleFunc("POST /api/v1/sports", a.addSports)
	mux.HandleFunc("GET /api/v1/absences", a.listAbsences)
	mux.HandleFunc("POST /api/v1/absences", a.addAbsence)
	mux.HandleFunc("DELETE /api/v1/absences/{id}", a.deleteAbsence)
	mux.HandleFunc("POST /api/v1/makeups", a.addMakeup)
	mux.HandleFunc("PUT /api/v1/staff/{id}/periods", a.setWeekly)
	mux.HandleFunc("GET /api/v1/staff/{id}/absence", a.absenceReport)
	mux.HandleFunc("GET /api/v1/meetings", a.listMeetings)
	mux.HandleFunc("POST /api/v1/meetings", a.saveMeeting)
	mux.HandleFunc("GET /api/v1/timetable", a.timetable)
	mux.HandleFunc("PUT /api/v1/timetable/bell", a.saveBell)
	mux.HandleFunc("POST /api/v1/timetable/generate", a.generateTimetable)
	mux.HandleFunc("POST /api/v1/timetable/move", a.moveSlot)
	mux.HandleFunc("PUT /api/v1/timetable/blocks", a.setBlocks)
	mux.HandleFunc("GET /api/v1/timetable.pdf", a.timetablePDF)
	mux.HandleFunc("GET /api/v1/devices", a.listDevices)
	mux.HandleFunc("DELETE /api/v1/devices/{id}", a.deleteDevice)
	mux.HandleFunc("POST /api/v1/backup", a.backupNow)
	mux.HandleFunc("GET /api/v1/backups", a.listBackups)
	mux.HandleFunc("POST /api/v1/backups/restore", a.restore)
	mux.HandleFunc("POST /api/v1/semester/close", a.closeSemester)
	mux.HandleFunc("GET /api/v1/reports/semester", a.listSemester)
	mux.HandleFunc("GET /api/v1/reports/semester/{id}", a.getSemester)
	mux.HandleFunc("POST /api/v1/reports/export", a.exportReport)
	mux.HandleFunc("POST /api/v1/sync", a.sync)
	mux.HandleFunc("GET /api/v1/users", a.listUsers)
	mux.HandleFunc("POST /api/v1/users", a.createUser)
	mux.HandleFunc("POST /api/v1/sample/clear", a.clearSample)
}

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(v)
}

func (a *API) ok(w http.ResponseWriter, v any) { writeJSON(w, 200, v) }

func (a *API) fail(w http.ResponseWriter, code int, msg string) {
	writeJSON(w, code, map[string]string{"error": msg})
}

func (a *API) read(w http.ResponseWriter, r *http.Request, dst any) bool {
	r.Body = http.MaxBytesReader(w, r.Body, 1<<20)
	if err := json.NewDecoder(r.Body).Decode(dst); err != nil {
		a.fail(w, 400, "That was not understood")
		return false
	}
	return true
}

func (a *API) user(w http.ResponseWriter, r *http.Request) (store.User, bool) {
	h := r.Header.Get("Authorization")
	token := strings.TrimPrefix(h, "Bearer ")
	if token == "" || token == h {
		a.fail(w, 401, "Sign in first")
		return store.User{}, false
	}
	u, err := a.Store.UserByToken(token)
	if err != nil || !u.Active {
		a.fail(w, 401, "Sign in again")
		return store.User{}, false
	}
	return u, true
}

func (a *API) must(w http.ResponseWriter, r *http.Request, roles ...string) (store.User, bool) {
	u, ok := a.user(w, r)
	if !ok {
		return u, false
	}
	for _, role := range roles {
		if u.Role == role {
			return u, true
		}
	}
	a.fail(w, 403, "You cannot do that")
	return u, false
}

func (a *API) call(w http.ResponseWriter, err error, ok any) {
	if err != nil {
		a.fail(w, 400, err.Error())
		return
	}
	a.ok(w, ok)
}

func clientIP(r *http.Request) string {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}

func (a *API) limited(ip string) bool {
	a.mu.Lock()
	defer a.mu.Unlock()
	if a.fails == nil {
		a.fails = map[string][]time.Time{}
	}
	cut := time.Now().Add(-10 * time.Minute)
	var kept []time.Time
	for _, t := range a.fails[ip] {
		if t.After(cut) {
			kept = append(kept, t)
		}
	}
	a.fails[ip] = kept
	return len(kept) >= 8
}

func (a *API) markFail(ip string) {
	a.mu.Lock()
	defer a.mu.Unlock()
	if a.fails == nil {
		a.fails = map[string][]time.Time{}
	}
	a.fails[ip] = append(a.fails[ip], time.Now())
}

func newToken() string {
	b := make([]byte, 32)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

type licenseView struct {
	Licensed   bool   `json:"licensed"`
	SchoolName string `json:"school_name"`
	MachineID  string `json:"machine_id"`
	QRPayload  string `json:"qr_payload"`
	Expires    string `json:"expires,omitempty"`
	MaxDevices int    `json:"max_devices"`
	NeverEnds  bool   `json:"never_ends"`
	Unlimited  bool   `json:"unlimited"`
	Message    string `json:"message,omitempty"`
	Expired    bool   `json:"expired"`
	Clock      bool   `json:"clock_problem"`
}

func viewLicense(st license.Status) licenseView {
	v := licenseView{
		Licensed: st.Licensed, SchoolName: st.SchoolName, MachineID: st.MachineID, QRPayload: st.QRPayload,
		MaxDevices: st.MaxDevices, NeverEnds: st.NeverEnds, Unlimited: st.Unlimited, Message: st.Message,
		Expired: st.Expired, Clock: st.ClockProblem,
	}
	if st.Expires != nil {
		v.Expires = st.Expires.Format("2006-01-02")
	}
	return v
}

func (a *API) health(w http.ResponseWriter, r *http.Request) {
	st, _ := a.Gate.Current(a.now())
	a.ok(w, map[string]any{"ok": true, "product": "SchoolDesk", "licensed": st.Licensed, "school_name": st.SchoolName})
}

func (a *API) licenseStatus(w http.ResponseWriter, r *http.Request) {
	st, err := a.Gate.Current(a.now())
	if err != nil {
		a.fail(w, 500, "The school computer could not be checked")
		return
	}
	a.ok(w, viewLicense(st))
}

func (a *API) activate(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Code string `json:"code"`
	}
	if !a.read(w, r, &in) {
		return
	}
	st, err := a.Gate.Activate(in.Code, a.now())
	if err != nil {
		msg := err.Error()
		if st.Message != "" {
			msg = st.Message
		}
		a.fail(w, 400, msg)
		return
	}
	a.ok(w, viewLicense(st))
}

func (a *API) qr(w http.ResponseWriter, r *http.Request) {
	st, err := a.Gate.Current(a.now())
	if err != nil {
		a.fail(w, 500, "The school computer could not be checked")
		return
	}
	png, err := qrcode.Encode(st.QRPayload, qrcode.Medium, 360)
	if err != nil {
		a.fail(w, 500, "The code picture could not be made")
		return
	}
	w.Header().Set("Content-Type", "image/png")
	_, _ = w.Write(png)
}

func (a *API) login(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Username   string `json:"username"`
		Password   string `json:"password"`
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
	u, hash, err := a.Store.UserByUsername(in.Username)
	if err != nil || !u.Active || !auth.Check(hash, in.Password) {
		a.markFail(ip)
		a.fail(w, 401, "The name or the password is wrong")
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
	a.Store.Audit(u.ID, "login", u.Username)
	a.ok(w, map[string]any{"token": token, "user": u, "school_name": st.SchoolName})
}

func (a *API) logout(w http.ResponseWriter, r *http.Request) {
	h := r.Header.Get("Authorization")
	token := strings.TrimPrefix(h, "Bearer ")
	_ = a.Store.DeleteSession(token)
	a.ok(w, map[string]bool{"ok": true})
}

func (a *API) me(w http.ResponseWriter, r *http.Request) {
	u, ok := a.user(w, r)
	if !ok {
		return
	}
	st, _ := a.Gate.Current(a.now())
	a.ok(w, map[string]any{"user": u, "school_name": st.SchoolName})
}

func (a *API) password(w http.ResponseWriter, r *http.Request) {
	u, ok := a.user(w, r)
	if !ok {
		return
	}
	var in struct {
		Current string `json:"current"`
		Next    string `json:"next"`
	}
	if !a.read(w, r, &in) {
		return
	}
	_, hash, err := a.Store.UserByUsername(u.Username)
	if err != nil || !auth.Check(hash, in.Current) {
		a.fail(w, 400, "The current password is wrong")
		return
	}
	next, err := auth.Hash(in.Next)
	if err != nil {
		a.fail(w, 400, err.Error())
		return
	}
	a.call(w, a.Store.ChangePassword(u.ID, next), map[string]bool{"ok": true})
}

func (a *API) deviceMax() int {
	st, err := a.Gate.Current(a.now())
	if err != nil || !st.Licensed || st.Unlimited {
		return 0
	}
	return st.MaxDevices
}

func (a *API) schoolName() string {
	st, _ := a.Gate.Current(a.now())
	if st.SchoolName != "" {
		return st.SchoolName
	}
	return "School"
}
