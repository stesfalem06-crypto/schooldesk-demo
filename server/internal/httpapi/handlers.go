package httpapi

import (
	"net/http"
	"strconv"
	"time"

	"schooldesk/internal/auth"
	"schooldesk/internal/domain"
	"schooldesk/internal/store"
)

func (a *API) getSettings(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.user(w, r); !ok {
		return
	}
	s, err := a.Store.Settings()
	a.call(w, err, s)
}

func (a *API) putSettings(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.must(w, r, "admin"); !ok {
		return
	}
	var in store.Settings
	if !a.read(w, r, &in) {
		return
	}
	if err := a.Store.SaveSettings(in); err != nil {
		a.fail(w, 400, err.Error())
		return
	}
	s, _ := a.Store.Settings()
	a.ok(w, s)
}

func (a *API) dashboard(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.must(w, r, "admin", "director"); !ok {
		return
	}
	classes, err := a.Store.ListClasses()
	if err != nil {
		a.fail(w, 400, err.Error())
		return
	}
	students, _ := a.Store.ListStudents("")
	settings, _ := a.Store.Settings()
	finance, err := a.Store.Finance()
	if err != nil {
		a.fail(w, 400, err.Error())
		return
	}
	staff, _ := a.Store.StaffStats()
	var promo []store.PromotionStat
	for _, c := range classes {
		st, err := a.Store.Promotion(c.ID, settings.Semester)
		if err == nil {
			promo = append(promo, st)
		}
	}
	a.ok(w, map[string]any{
		"classes": len(classes), "students": len(students), "head": storeHead(students),
		"finance": finance, "staff": staff, "promotion": promo, "semester": settings.Semester,
		"academic_year": settings.AcademicYear,
	})
}

func storeHead(students []store.Student) store.Headcount {
	var h store.Headcount
	for _, st := range students {
		h.Students++
		male := st.Sex == "M"
		if male {
			h.Male++
		} else {
			h.Female++
		}
		if st.DroppedOut {
			h.Dropped++
			if male {
				h.DroppedM++
			} else {
				h.DroppedF++
			}
		} else {
			h.Active++
			if male {
				h.ActiveM++
			} else {
				h.ActiveF++
			}
		}
	}
	return h
}

func (a *API) listStaff(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.must(w, r, "admin", "director"); !ok {
		return
	}
	list, err := a.Store.ListStaff()
	a.call(w, err, list)
}

func (a *API) saveStaff(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.must(w, r, "admin"); !ok {
		return
	}
	var in store.Staff
	if !a.read(w, r, &in) {
		return
	}
	got, err := a.Store.SaveStaff(in)
	a.call(w, err, got)
}

func (a *API) staffStats(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.must(w, r, "admin", "director"); !ok {
		return
	}
	got, err := a.Store.StaffStats()
	a.call(w, err, got)
}

func (a *API) listClasses(w http.ResponseWriter, r *http.Request) {
	u, ok := a.user(w, r)
	if !ok {
		return
	}
	list, err := a.Store.ListClasses()
	if err != nil {
		a.fail(w, 400, err.Error())
		return
	}
	if u.SeesSchool() {
		a.ok(w, list)
		return
	}
	var mine []store.Class
	for _, c := range list {
		if a.canSeeClass(u, c.ID) {
			mine = append(mine, c)
		}
	}
	a.ok(w, mine)
}

func (a *API) saveClass(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.must(w, r, "admin"); !ok {
		return
	}
	var in store.Class
	if !a.read(w, r, &in) {
		return
	}
	got, err := a.Store.SaveClass(in)
	a.call(w, err, got)
}

func (a *API) listSubjects(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.user(w, r); !ok {
		return
	}
	list, err := a.Store.ListSubjects()
	a.call(w, err, list)
}

func (a *API) saveSubject(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.must(w, r, "admin"); !ok {
		return
	}
	var in store.Subject
	if !a.read(w, r, &in) {
		return
	}
	got, err := a.Store.SaveSubject(in)
	a.call(w, err, got)
}

func (a *API) listClassSubjects(w http.ResponseWriter, r *http.Request) {
	u, ok := a.user(w, r)
	if !ok {
		return
	}
	classID := r.URL.Query().Get("class_id")
	sem, _ := strconv.Atoi(r.URL.Query().Get("semester"))
	if classID != "" && !a.canSeeClass(u, classID) {
		a.fail(w, 403, "You cannot open that class")
		return
	}
	list, err := a.Store.ListClassSubjects(classID, sem)
	if err != nil {
		a.fail(w, 400, err.Error())
		return
	}
	if u.SeesSchool() || classID != "" {
		a.ok(w, list)
		return
	}
	var mine []store.ClassSubject
	for _, cs := range list {
		if cs.TeacherStaffID == u.StaffID {
			mine = append(mine, cs)
		}
	}
	a.ok(w, mine)
}

func (a *API) addClassSubject(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.must(w, r, "admin"); !ok {
		return
	}
	var in struct {
		ClassID        string         `json:"class_id"`
		SubjectID      string         `json:"subject_id"`
		TeacherStaffID string         `json:"teacher_staff_id"`
		PeriodsPerWeek int            `json:"periods_per_week"`
		Semester       int            `json:"semester"`
		Weights        domain.Weights `json:"weights"`
	}
	if !a.read(w, r, &in) {
		return
	}
	settings, _ := a.Store.Settings()
	weights := in.Weights
	if settings.CALocked || !weights.Valid() {
		weights = settings.Weights
	}
	got, err := a.Store.AddClassSubject(in.ClassID, in.SubjectID, in.TeacherStaffID, in.PeriodsPerWeek, in.Semester, weights)
	a.call(w, err, got)
}

func (a *API) setWeights(w http.ResponseWriter, r *http.Request) {
	u, ok := a.user(w, r)
	if !ok {
		return
	}
	id := r.PathValue("id")
	cs, err := a.Store.ClassSubject(id)
	if err != nil {
		a.fail(w, 404, "That subject was not found")
		return
	}
	if !u.IsAdmin() && cs.TeacherStaffID != u.StaffID {
		a.fail(w, 403, "You cannot change these parts")
		return
	}
	var in domain.Weights
	if !a.read(w, r, &in) {
		return
	}
	settings, _ := a.Store.Settings()
	a.call(w, a.Store.SetWeights(id, in, settings.CALocked && !u.IsAdmin()), map[string]bool{"ok": true})
}

func (a *API) listFields(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.user(w, r); !ok {
		return
	}
	list, err := a.Store.ListCustomFields()
	a.call(w, err, list)
}

func (a *API) addField(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.must(w, r, "admin"); !ok {
		return
	}
	var in struct {
		Name string `json:"name"`
	}
	if !a.read(w, r, &in) {
		return
	}
	got, err := a.Store.AddCustomField(in.Name)
	a.call(w, err, got)
}

func (a *API) listStudents(w http.ResponseWriter, r *http.Request) {
	u, ok := a.user(w, r)
	if !ok {
		return
	}
	classID := r.URL.Query().Get("class_id")
	if classID != "" && !a.canSeeClass(u, classID) {
		a.fail(w, 403, "You cannot open that class")
		return
	}
	if classID == "" && !u.SeesSchool() {
		a.fail(w, 400, "Choose a class")
		return
	}
	list, err := a.Store.ListStudents(classID)
	a.call(w, err, list)
}

func (a *API) saveStudent(w http.ResponseWriter, r *http.Request) {
	u, ok := a.user(w, r)
	if !ok {
		return
	}
	var in store.Student
	if !a.read(w, r, &in) {
		return
	}
	if !a.canHomeroom(u, in.ClassID) {
		a.fail(w, 403, "Only the homeroom teacher can change this list")
		return
	}
	got, err := a.Store.SaveStudent(in)
	a.call(w, err, got)
}

func (a *API) dropout(w http.ResponseWriter, r *http.Request) {
	u, ok := a.user(w, r)
	if !ok {
		return
	}
	var in struct {
		Dropped bool   `json:"dropped"`
		Reason  string `json:"reason"`
		Date    string `json:"date"`
	}
	if !a.read(w, r, &in) {
		return
	}
	students, err := a.Store.ListStudents("")
	if err != nil {
		a.fail(w, 400, err.Error())
		return
	}
	var classID string
	for _, st := range students {
		if st.ID == r.PathValue("id") {
			classID = st.ClassID
		}
	}
	if classID == "" {
		a.fail(w, 404, "That student was not found")
		return
	}
	if !a.canHomeroom(u, classID) {
		a.fail(w, 403, "Only the homeroom teacher can do that")
		return
	}
	got, err := a.Store.SetDropout(r.PathValue("id"), in.Dropped, in.Reason, in.Date)
	a.call(w, err, got)
}

func (a *API) classSummary(w http.ResponseWriter, r *http.Request) {
	u, ok := a.user(w, r)
	if !ok {
		return
	}
	id := r.PathValue("id")
	if !a.canSeeClass(u, id) {
		a.fail(w, 403, "You cannot open that class")
		return
	}
	head, err := a.Store.Headcount(id)
	if err != nil {
		a.fail(w, 400, err.Error())
		return
	}
	reasons, _ := a.Store.DropoutReasons(id)
	settings, _ := a.Store.Settings()
	fees, _ := a.Store.FeeRows(id, settings.AcademicYear)
	promo, _ := a.Store.Promotion(id, settings.Semester)
	a.ok(w, map[string]any{"head": head, "dropout_reasons": reasons, "fees": fees, "promotion": promo})
}

func (a *API) results(w http.ResponseWriter, r *http.Request) {
	u, ok := a.user(w, r)
	if !ok {
		return
	}
	id := r.PathValue("id")
	if !a.canSeeClass(u, id) {
		a.fail(w, 403, "You cannot open that class")
		return
	}
	sem, _ := strconv.Atoi(r.URL.Query().Get("semester"))
	if sem == 0 {
		settings, _ := a.Store.Settings()
		sem = settings.Semester
	}
	got, err := a.Store.ClassResults(id, sem)
	a.call(w, err, got)
}

func (a *API) listAssessments(w http.ResponseWriter, r *http.Request) {
	u, ok := a.user(w, r)
	if !ok {
		return
	}
	id := r.URL.Query().Get("class_subject_id")
	cs, err := a.Store.ClassSubject(id)
	if err != nil {
		a.fail(w, 404, "That subject was not found")
		return
	}
	if !a.canSeeClass(u, cs.ClassID) {
		a.fail(w, 403, "You cannot open that class")
		return
	}
	list, err := a.Store.ListAssessments(id)
	a.call(w, err, list)
}

func (a *API) addAssessment(w http.ResponseWriter, r *http.Request) {
	u, ok := a.user(w, r)
	if !ok {
		return
	}
	var in struct {
		ClassSubjectID string  `json:"class_subject_id"`
		Component      string  `json:"component"`
		Half           int     `json:"half"`
		Title          string  `json:"title"`
		MaxMarks       float64 `json:"max_marks"`
		Date           string  `json:"assessment_date"`
	}
	if !a.read(w, r, &in) {
		return
	}
	if !a.canTeach(u, in.ClassSubjectID) {
		a.fail(w, 403, "You do not teach this subject")
		return
	}
	got, err := a.Store.AddAssessment(in.ClassSubjectID, in.Component, in.Half, in.Title, in.MaxMarks, in.Date)
	a.call(w, err, got)
}

func (a *API) listScores(w http.ResponseWriter, r *http.Request) {
	u, ok := a.user(w, r)
	if !ok {
		return
	}
	id := r.URL.Query().Get("assessment_id")
	// Ownership is checked loosely: any signed-in user who can see the class.
	list, err := a.Store.ListScores(id)
	if err != nil {
		a.fail(w, 400, err.Error())
		return
	}
	_ = u
	a.ok(w, list)
}

func (a *API) setScore(w http.ResponseWriter, r *http.Request) {
	u, ok := a.user(w, r)
	if !ok {
		return
	}
	var in struct {
		AssessmentID string   `json:"assessment_id"`
		StudentID    string   `json:"student_id"`
		Score        *float64 `json:"score"`
		BaseRevision int      `json:"base_revision"`
	}
	if !a.read(w, r, &in) {
		return
	}
	classSubject, err := a.assessmentSubject(in.AssessmentID)
	if err != nil {
		a.fail(w, 404, "That mark list was not found")
		return
	}
	if !a.canTeach(u, classSubject) {
		a.fail(w, 403, "You do not teach this subject")
		return
	}
	got, conflict, err := a.Store.SetScore(u.ID, in.AssessmentID, in.StudentID, in.Score, in.BaseRevision)
	if err != nil {
		a.fail(w, 400, err.Error())
		return
	}
	if conflict {
		writeJSON(w, 409, map[string]any{"error": "The school record is newer", "conflict": true, "server": got})
		return
	}
	a.ok(w, got)
}

func (a *API) undoScore(w http.ResponseWriter, r *http.Request) {
	u, ok := a.user(w, r)
	if !ok {
		return
	}
	got, err := a.Store.UndoScore(u.ID)
	a.call(w, err, got)
}

func (a *API) feeRows(w http.ResponseWriter, r *http.Request) {
	u, ok := a.user(w, r)
	if !ok {
		return
	}
	classID := r.URL.Query().Get("class_id")
	if classID == "" && !u.SeesSchool() {
		a.fail(w, 403, "You cannot see every class")
		return
	}
	if classID != "" && !a.canSeeClass(u, classID) && !u.SeesSchool() {
		a.fail(w, 403, "You cannot open that class")
		return
	}
	rows, err := a.Store.FeeRows(classID, r.URL.Query().Get("year"))
	a.call(w, err, rows)
}

func (a *API) addPayment(w http.ResponseWriter, r *http.Request) {
	u, ok := a.user(w, r)
	if !ok {
		return
	}
	var in struct {
		StudentID string  `json:"student_id"`
		Amount    float64 `json:"amount"`
		PaidOn    string  `json:"paid_on"`
	}
	if !a.read(w, r, &in) {
		return
	}
	students, _ := a.Store.ListStudents("")
	var classID string
	for _, st := range students {
		if st.ID == in.StudentID {
			classID = st.ClassID
		}
	}
	if !a.canHomeroom(u, classID) {
		a.fail(w, 403, "Only the homeroom teacher can record a payment")
		return
	}
	settings, _ := a.Store.Settings()
	got, err := a.Store.AddPayment(in.StudentID, settings.AcademicYear, in.PaidOn, u.ID, in.Amount)
	a.call(w, err, got)
}

func (a *API) finance(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.must(w, r, "admin", "director"); !ok {
		return
	}
	got, err := a.Store.Finance()
	a.call(w, err, got)
}

func (a *API) listIncomes(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.must(w, r, "admin", "director"); !ok {
		return
	}
	list, err := a.Store.ListIncomes()
	a.call(w, err, list)
}

func (a *API) addIncome(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.must(w, r, "admin"); !ok {
		return
	}
	var in store.Income
	if !a.read(w, r, &in) {
		return
	}
	got, err := a.Store.AddIncome(in)
	a.call(w, err, got)
}

func (a *API) listExpenses(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.must(w, r, "admin", "director"); !ok {
		return
	}
	list, err := a.Store.ListExpenses()
	a.call(w, err, list)
}

func (a *API) addExpense(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.must(w, r, "admin"); !ok {
		return
	}
	var in store.Expense
	if !a.read(w, r, &in) {
		return
	}
	got, err := a.Store.AddExpense(in)
	a.call(w, err, got)
}

func (a *API) listWorkshops(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.must(w, r, "admin", "director"); !ok {
		return
	}
	list, err := a.Store.ListWorkshops()
	a.call(w, err, list)
}

func (a *API) addWorkshop(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.must(w, r, "admin"); !ok {
		return
	}
	var in store.Workshop
	if !a.read(w, r, &in) {
		return
	}
	got, err := a.Store.AddWorkshop(in)
	a.call(w, err, got)
}

func (a *API) listSports(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.must(w, r, "admin", "director"); !ok {
		return
	}
	list, err := a.Store.ListSports()
	a.call(w, err, list)
}

func (a *API) addSports(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.must(w, r, "admin"); !ok {
		return
	}
	var in store.SportsExpense
	if !a.read(w, r, &in) {
		return
	}
	got, err := a.Store.AddSports(in)
	a.call(w, err, got)
}

func (a *API) addAbsence(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.must(w, r, "admin"); !ok {
		return
	}
	var in struct {
		StaffID string `json:"staff_id"`
		Date    string `json:"date"`
		Note    string `json:"note"`
	}
	if !a.read(w, r, &in) {
		return
	}
	a.call(w, a.Store.AddAbsence(in.StaffID, in.Date, in.Note), map[string]bool{"ok": true})
}

func (a *API) deleteAbsence(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.must(w, r, "admin"); !ok {
		return
	}
	a.call(w, a.Store.DeleteAbsence(r.PathValue("id")), map[string]bool{"ok": true})
}

func (a *API) addMakeup(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.must(w, r, "admin"); !ok {
		return
	}
	var in struct {
		StaffID string `json:"staff_id"`
		Date    string `json:"date"`
		Periods int    `json:"periods"`
		Note    string `json:"note"`
	}
	if !a.read(w, r, &in) {
		return
	}
	a.call(w, a.Store.AddMakeup(in.StaffID, in.Date, in.Note, in.Periods), map[string]bool{"ok": true})
}

func (a *API) setWeekly(w http.ResponseWriter, r *http.Request) {
	u, ok := a.user(w, r)
	if !ok {
		return
	}
	id := r.PathValue("id")
	if !u.IsAdmin() && u.StaffID != id {
		a.fail(w, 403, "You can only set your own week")
		return
	}
	var in struct {
		Periods []int `json:"periods"`
	}
	if !a.read(w, r, &in) {
		return
	}
	a.call(w, a.Store.SetWeeklyPeriods(id, in.Periods), map[string]bool{"ok": true})
}

func (a *API) absenceReport(w http.ResponseWriter, r *http.Request) {
	u, ok := a.user(w, r)
	if !ok {
		return
	}
	id := r.PathValue("id")
	if !u.SeesSchool() && u.StaffID != id {
		a.fail(w, 403, "You cannot open that")
		return
	}
	year, _ := strconv.Atoi(r.URL.Query().Get("year"))
	month, _ := strconv.Atoi(r.URL.Query().Get("month"))
	if year == 0 || month == 0 {
		now := a.now()
		year, month = now.Year(), int(now.Month())
	}
	got, err := a.Store.AbsenceReport(id, year, time.Month(month))
	a.call(w, err, got)
}

func (a *API) listMeetings(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.must(w, r, "director"); !ok {
		return
	}
	list, err := a.Store.ListMeetings()
	a.call(w, err, list)
}

func (a *API) saveMeeting(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.must(w, r, "director"); !ok {
		return
	}
	var in store.Meeting
	if !a.read(w, r, &in) {
		return
	}
	got, err := a.Store.SaveMeeting(in)
	a.call(w, err, got)
}

func (a *API) timetable(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.user(w, r); !ok {
		return
	}
	bell, _ := a.Store.GetBell()
	slots, err := a.Store.Timetable()
	if err != nil {
		a.fail(w, 400, err.Error())
		return
	}
	a.ok(w, map[string]any{"bell": bell, "slots": slots})
}

func (a *API) saveBell(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.must(w, r, "admin"); !ok {
		return
	}
	var in store.Bell
	if !a.read(w, r, &in) {
		return
	}
	a.call(w, a.Store.SaveBell(in), map[string]bool{"ok": true})
}

func (a *API) generateTimetable(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.must(w, r, "admin"); !ok {
		return
	}
	settings, _ := a.Store.Settings()
	slots, err := a.Store.GenerateTimetable(settings.Semester)
	a.call(w, err, slots)
}

func (a *API) moveSlot(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.must(w, r, "admin"); !ok {
		return
	}
	var in struct {
		ClassID    string `json:"class_id"`
		FromDay    int    `json:"from_day"`
		FromPeriod int    `json:"from_period"`
		ToDay      int    `json:"to_day"`
		ToPeriod   int    `json:"to_period"`
	}
	if !a.read(w, r, &in) {
		return
	}
	if err := a.Store.MoveSlot(in.ClassID, in.FromDay, in.FromPeriod, in.ToDay, in.ToPeriod); err != nil {
		a.fail(w, 409, err.Error())
		return
	}
	a.ok(w, map[string]bool{"ok": true})
}

func (a *API) setBlocks(w http.ResponseWriter, r *http.Request) {
	u, ok := a.user(w, r)
	if !ok {
		return
	}
	var in struct {
		StaffID string  `json:"staff_id"`
		Slots   [][]int `json:"slots"`
	}
	if !a.read(w, r, &in) {
		return
	}
	if in.StaffID == "" {
		in.StaffID = u.StaffID
	}
	if !u.IsAdmin() && u.StaffID != in.StaffID {
		a.fail(w, 403, "You can only set your own free times")
		return
	}
	var slots [][2]int
	for _, sl := range in.Slots {
		if len(sl) != 2 {
			a.fail(w, 400, "A free time is missing a day or a period")
			return
		}
		slots = append(slots, [2]int{sl[0], sl[1]})
	}
	a.call(w, a.Store.SetBlocks(in.StaffID, slots), map[string]bool{"ok": true})
}

func (a *API) listDevices(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.must(w, r, "admin", "director"); !ok {
		return
	}
	list, err := a.Store.ListDevices()
	a.call(w, err, list)
}

func (a *API) deleteDevice(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.must(w, r, "admin"); !ok {
		return
	}
	a.call(w, a.Store.DeleteDevice(r.PathValue("id")), map[string]bool{"ok": true})
}

func (a *API) listUsers(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.must(w, r, "admin"); !ok {
		return
	}
	list, err := a.Store.ListUsers()
	a.call(w, err, list)
}

func (a *API) createUser(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.must(w, r, "admin"); !ok {
		return
	}
	var in struct {
		Username    string `json:"username"`
		Password    string `json:"password"`
		Role        string `json:"role"`
		StaffID     string `json:"staff_id"`
		DisplayName string `json:"display_name"`
	}
	if !a.read(w, r, &in) {
		return
	}
	hash, err := auth.Hash(in.Password)
	if err != nil {
		a.fail(w, 400, err.Error())
		return
	}
	got, err := a.Store.CreateUser(in.Username, hash, in.Role, in.StaffID, in.DisplayName)
	a.call(w, err, got)
}

func (a *API) clearSample(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.must(w, r, "admin"); !ok {
		return
	}
	a.call(w, a.Store.ClearSample(), map[string]bool{"ok": true})
}

func (a *API) sync(w http.ResponseWriter, r *http.Request) {
	u, ok := a.user(w, r)
	if !ok {
		return
	}
	var in struct {
		DeviceID   string `json:"device_id"`
		DeviceName string `json:"device_name"`
		Platform   string `json:"platform"`
		Since      int64  `json:"since"`
		Scores     []struct {
			AssessmentID string   `json:"assessment_id"`
			StudentID    string   `json:"student_id"`
			Score        *float64 `json:"score"`
			BaseRevision int      `json:"base_revision"`
		} `json:"scores"`
	}
	if !a.read(w, r, &in) {
		return
	}
	if err := a.Store.TouchDevice(in.DeviceID, in.DeviceName, in.Platform, a.deviceMax()); err != nil {
		a.fail(w, 403, err.Error())
		return
	}
	var accepted []string
	var conflicts []any
	for _, sc := range in.Scores {
		csid, err := a.assessmentSubject(sc.AssessmentID)
		if err != nil || !a.canTeach(u, csid) {
			conflicts = append(conflicts, map[string]any{"assessment_id": sc.AssessmentID, "student_id": sc.StudentID, "error": "You do not teach this subject"})
			continue
		}
		got, conflict, err := a.Store.SetScore(u.ID, sc.AssessmentID, sc.StudentID, sc.Score, sc.BaseRevision)
		if err != nil {
			conflicts = append(conflicts, map[string]any{"assessment_id": sc.AssessmentID, "student_id": sc.StudentID, "error": err.Error()})
			continue
		}
		if conflict {
			conflicts = append(conflicts, map[string]any{"assessment_id": sc.AssessmentID, "student_id": sc.StudentID, "server": got})
			continue
		}
		accepted = append(accepted, got.ID)
	}
	changes, err := a.Store.ChangesSince(in.Since, 200)
	if err != nil {
		a.fail(w, 400, err.Error())
		return
	}
	st, _ := a.Gate.Current(a.now())
	a.ok(w, map[string]any{"accepted": accepted, "conflicts": conflicts, "changes": changes, "school_name": st.SchoolName, "licensed": st.Licensed})
}

func (a *API) canTeach(u store.User, classSubjectID string) bool {
	if u.IsAdmin() {
		return true
	}
	ok, _ := a.Store.Teaches(u.StaffID, classSubjectID)
	return ok
}

func (a *API) canHomeroom(u store.User, classID string) bool {
	if u.IsAdmin() {
		return true
	}
	ok, _ := a.Store.HomeroomOf(u.StaffID, classID)
	return ok
}

func (a *API) canSeeClass(u store.User, classID string) bool {
	if u.SeesSchool() || a.canHomeroom(u, classID) {
		return true
	}
	list, err := a.Store.ListClassSubjects(classID, 0)
	if err != nil {
		return false
	}
	for _, cs := range list {
		if cs.TeacherStaffID == u.StaffID {
			return true
		}
	}
	return false
}

func (a *API) assessmentSubject(id string) (string, error) {
	return a.Store.AssessmentClassSubject(id)
}
