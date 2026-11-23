package httpapi

import (
	"net/http"
	"os"
	"path/filepath"

	"schooldesk/internal/engine"
	"schooldesk/internal/report"
	"schooldesk/internal/store"
)

func (a *API) planFile() string {
	dir := a.DataDir
	if dir == "" && a.Store != nil {
		dir = filepath.Dir(a.Store.Path())
	}
	return filepath.Join(dir, "week.json")
}

func (a *API) loadPlan() (engine.School, error) {
	raw, err := os.ReadFile(a.planFile())
	if err != nil {
		return engine.School{}, err
	}
	return engine.ParseSchool(raw)
}

func (a *API) savePlan(school engine.School) error {
	raw, err := encodeSchool(school)
	if err != nil {
		return err
	}
	return os.WriteFile(a.planFile(), raw, 0o600)
}

func (a *API) planView(w http.ResponseWriter, r *http.Request) {
	u, ok := a.user(w, r)
	if !ok {
		return
	}
	school, err := a.loadPlan()
	if err != nil {
		a.ok(w, map[string]any{"ready": false, "placements": []any{}})
		return
	}
	a.ok(w, planJSON(school, u))
}

func (a *API) planSolve(w http.ResponseWriter, r *http.Request) {
	u, ok := a.must(w, r, "admin", "director")
	if !ok {
		return
	}
	var in struct {
		Seed   int64 `json:"seed"`
		Budget int64 `json:"time_budget_ms"`
	}
	if r.ContentLength != 0 {
		if !a.read(w, r, &in) {
			return
		}
	}
	school, err := a.loadPlan()
	if err != nil {
		a.fail(w, 400, "There is no timetable to build yet")
		return
	}
	var locks []engine.Placement
	if school.Timetable != nil {
		for _, p := range school.Timetable.Placements {
			if p.Locked {
				locks = append(locks, p)
			}
		}
	}
	if in.Seed == 0 {
		in.Seed = 2
	}
	if in.Budget == 0 {
		in.Budget = 8000
	}
	school.Timetable = nil
	result := engine.Solve(school, engine.SolveOptions{Seed: in.Seed, TimeBudgetMs: in.Budget, Locks: locks})
	if result.Timetable == nil {
		msg := "The week could not be built"
		if len(result.Issues) > 0 {
			msg = result.Issues[0].Title
		}
		a.fail(w, 400, msg)
		return
	}
	school.Timetable = result.Timetable
	if err := a.savePlan(school); err != nil {
		a.fail(w, 500, "The week could not be saved")
		return
	}
	a.ok(w, planJSON(school, u))
}

func (a *API) planMove(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.must(w, r, "admin", "director"); !ok {
		return
	}
	var in struct {
		LessonID string `json:"lesson_id"`
		Instance int    `json:"instance"`
		Day      int    `json:"day"`
		Period   int    `json:"period"`
	}
	if !a.read(w, r, &in) {
		return
	}
	school, err := a.loadPlan()
	if err != nil || school.Timetable == nil {
		a.fail(w, 400, "Build the week first")
		return
	}
	lesson := school.LessonByID(in.LessonID)
	if lesson == nil {
		a.fail(w, 400, "That lesson is not in the week")
		return
	}
	if lesson.Duration == 2 {
		if br := school.Bell.EffectiveBreakAfter(); br != nil && in.Period <= *br && in.Period+lesson.Duration-1 > *br {
			a.fail(w, 400, "A double lesson cannot cross the break")
			return
		}
	}
	if in.Day < 0 || in.Day >= len(school.Days) || in.Period < 0 || in.Period+lesson.Duration > school.Bell.PeriodCount {
		a.fail(w, 400, "That spot is outside the week")
		return
	}
	found := false
	for i := range school.Timetable.Placements {
		p := &school.Timetable.Placements[i]
		if p.LessonID == in.LessonID && p.Instance == in.Instance {
			p.Day = in.Day
			p.Period = in.Period
			found = true
		}
	}
	if !found {
		school.Timetable.Placements = append(school.Timetable.Placements, engine.Placement{
			LessonID: in.LessonID, Instance: in.Instance, Day: in.Day, Period: in.Period,
		})
	}
	school.Timetable.Summary = "Edited by hand"
	if err := a.savePlan(school); err != nil {
		a.fail(w, 500, "The week could not be saved")
		return
	}
	problems := engine.Problems(engine.Validate(school, school.Timetable))
	a.ok(w, map[string]any{"ok": true, "problems": len(problems)})
}

func (a *API) planPDF(w http.ResponseWriter, r *http.Request) {
	u, ok := a.user(w, r)
	if !ok {
		return
	}
	school, err := a.loadPlan()
	if err != nil || school.Timetable == nil {
		a.fail(w, 400, "Build the week first")
		return
	}
	classID := r.URL.Query().Get("class_id")
	teacherID := r.URL.Query().Get("teacher_id")
	if !u.SeesSchool() {
		teacherID = ""
		if u.StaffID != "" {
			// Teachers see their own sheet, or their class when they ask for it.
			if classID == "" {
				teacherID = linkedTeacher(school, u)
			}
		}
		if classID != "" && !teacherCanSeeClass(school, u, classID) {
			a.fail(w, 403, "You can only print your own class")
			return
		}
	}
	pdf, err := report.TimetablePDF(school, classID, teacherID)
	if err != nil {
		a.fail(w, 500, "The timetable could not be printed")
		return
	}
	w.Header().Set("Content-Type", "application/pdf")
	w.Header().Set("Content-Disposition", `attachment; filename="timetable.pdf"`)
	_, _ = w.Write(pdf)
}

func planJSON(school engine.School, u store.User) map[string]any {
	periods := school.Bell.Periods()
	type cell struct {
		ClassID   string `json:"class_id"`
		ClassName string `json:"class_name"`
		Subject   string `json:"subject"`
		Teacher   string `json:"teacher"`
		TeacherID string `json:"teacher_id"`
		Day       int    `json:"day"`
		Period    int    `json:"period"`
		Room      string `json:"room"`
		Locked    bool   `json:"locked"`
		LessonID  string `json:"lesson_id"`
		Instance  int    `json:"instance"`
	}
	var rows []cell
	if school.Timetable != nil {
		for _, p := range school.Timetable.Placements {
			lesson := school.LessonByID(p.LessonID)
			if lesson == nil {
				continue
			}
			if !u.SeesSchool() && !placementVisible(school, u, *lesson) {
				continue
			}
			cls := school.ClassByID(lesson.ClassID)
			sub := school.SubjectByID(lesson.SubjectID)
			tch := school.TeacherByID(lesson.TeacherID)
			row := cell{
				ClassID: lesson.ClassID, TeacherID: lesson.TeacherID,
				Day: p.Day, Period: p.Period, Locked: p.Locked,
				LessonID: p.LessonID, Instance: p.Instance,
			}
			if cls != nil {
				row.ClassName = cls.TimetableName()
			}
			if sub != nil {
				row.Subject = sub.Name
			}
			if tch != nil {
				row.Teacher = tch.Name
			}
			if p.RoomID != nil {
				if room := school.RoomByID(*p.RoomID); room != nil {
					row.Room = room.Name
				}
			}
			rows = append(rows, row)
		}
	}
	if rows == nil {
		rows = []cell{}
	}
	var breakAfter any
	if v := school.Bell.EffectiveBreakAfter(); v != nil {
		breakAfter = *v
	}
	return map[string]any{
		"ready": school.Timetable != nil, "name": school.Name, "days": school.Days,
		"periods": periods, "break_after": breakAfter, "placements": rows,
		"can_edit": u.Role == "admin" || u.Role == "director",
		"summary":  summaryOf(school),
	}
}

func summaryOf(school engine.School) string {
	if school.Timetable == nil {
		return ""
	}
	return school.Timetable.Summary
}

func placementVisible(school engine.School, u store.User, lesson engine.Lesson) bool {
	if u.SeesSchool() {
		return true
	}
	tch := school.TeacherByID(lesson.TeacherID)
	if tch != nil && (tch.Name == u.DisplayName || tch.ID == u.StaffID) {
		return true
	}
	cls := school.ClassByID(lesson.ClassID)
	if cls != nil && cls.HomeroomTeacherID != nil {
		home := school.TeacherByID(*cls.HomeroomTeacherID)
		if home != nil && (home.Name == u.DisplayName || home.ID == u.StaffID) {
			return true
		}
	}
	for _, id := range u.HomeroomClassIDs {
		if id == lesson.ClassID {
			return true
		}
	}
	return false
}

func teacherCanSeeClass(school engine.School, u store.User, classID string) bool {
	if u.SeesSchool() {
		return true
	}
	for _, id := range u.HomeroomClassIDs {
		if id == classID {
			return true
		}
	}
	cls := school.ClassByID(classID)
	if cls != nil && cls.HomeroomTeacherID != nil {
		if home := school.TeacherByID(*cls.HomeroomTeacherID); home != nil && home.Name == u.DisplayName {
			return true
		}
	}
	if school.Timetable != nil {
		for _, p := range school.Timetable.Placements {
			lesson := school.LessonByID(p.LessonID)
			if lesson != nil && lesson.ClassID == classID && placementVisible(school, u, *lesson) {
				return true
			}
		}
	}
	return false
}

func linkedTeacher(school engine.School, u store.User) string {
	for _, t := range school.Teachers {
		if t.ID == u.StaffID || t.Name == u.DisplayName {
			return t.ID
		}
	}
	return "none"
}
