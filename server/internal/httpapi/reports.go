package httpapi

import (
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"

	"schooldesk/internal/report"
	"schooldesk/internal/store"
)

func (a *API) backupDir() string {
	settings, err := a.Store.Settings()
	if err == nil && strings.TrimSpace(settings.BackupDir) != "" {
		return settings.BackupDir
	}
	return filepath.Join(filepath.Dir(a.Store.Path()), "backups")
}

func (a *API) backupNow(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.must(w, r, "admin"); !ok {
		return
	}
	name, err := a.writeBackup()
	if err != nil {
		a.fail(w, 400, "The backup could not be saved. Check the folder.")
		return
	}
	a.ok(w, map[string]string{"file": name})
}

// BackupNow writes a versioned copy of the school records.
func (a *API) BackupNow() (string, error) { return a.writeBackup() }

func (a *API) writeBackup() (string, error) {
	dir := a.backupDir()
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return "", err
	}
	name := "schooldesk-" + time.Now().Format("20060102-150405") + ".db"
	dest := filepath.Join(dir, name)
	if err := a.Store.BackupTo(dest); err != nil {
		return "", err
	}
	a.pruneBackups(dir, 30)
	return name, nil
}

func (a *API) pruneBackups(dir string, keep int) {
	list := backupFiles(dir)
	if len(list) <= keep {
		return
	}
	for _, name := range list[:len(list)-keep] {
		_ = os.Remove(filepath.Join(dir, name))
	}
}

func backupFiles(dir string) []string {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil
	}
	var names []string
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		name := e.Name()
		if strings.HasPrefix(name, "schooldesk-") && strings.HasSuffix(name, ".db") {
			names = append(names, name)
		}
	}
	sort.Strings(names)
	return names
}

func (a *API) listBackups(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.must(w, r, "admin"); !ok {
		return
	}
	dir := a.backupDir()
	var out []map[string]any
	for _, name := range backupFiles(dir) {
		info, err := os.Stat(filepath.Join(dir, name))
		if err != nil {
			continue
		}
		out = append(out, map[string]any{"name": name, "size": info.Size(), "when": info.ModTime().Format(time.RFC3339)})
	}
	a.ok(w, out)
}

func (a *API) restore(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.must(w, r, "admin"); !ok {
		return
	}
	var in struct {
		Name string `json:"name"`
	}
	if !a.read(w, r, &in) {
		return
	}
	base := filepath.Base(in.Name)
	if base != in.Name || !strings.HasPrefix(base, "schooldesk-") || !strings.HasSuffix(base, ".db") {
		a.fail(w, 400, "Choose a backup from the list")
		return
	}
	path := filepath.Join(a.backupDir(), base)
	if err := a.Store.RestoreFrom(path); err != nil {
		a.fail(w, 400, "The backup could not be put back")
		return
	}
	a.ok(w, map[string]bool{"ok": true})
}

func (a *API) closeSemester(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.must(w, r, "admin"); !ok {
		return
	}
	n, err := a.MakeSemesterReports()
	if err != nil {
		a.fail(w, 400, err.Error())
		return
	}
	a.ok(w, map[string]any{"ok": true, "reports": n})
}

func (a *API) MakeSemesterReports() (int, error) {
	settings, err := a.Store.Settings()
	if err != nil {
		return 0, err
	}
	classes, err := a.Store.ListClasses()
	if err != nil {
		return 0, err
	}
	var stats []store.PromotionStat
	n := 0
	for _, c := range classes {
		st, err := a.Store.Promotion(c.ID, settings.Semester)
		if err != nil {
			return n, err
		}
		reasons, _ := a.Store.DropoutReasons(c.ID)
		pdf, err := report.PDF(classStatDoc(a.schoolName(), settings, st, reasons))
		if err != nil {
			return n, err
		}
		if _, err := a.Store.SavePDF(settings.AcademicYear, settings.Semester, c.ID, c.Name+" semester stats", pdf); err != nil {
			return n, err
		}
		stats = append(stats, st)
		n++
	}
	pdf, err := report.PDF(schoolStatDoc(a.schoolName(), settings, stats))
	if err != nil {
		return n, err
	}
	if _, err := a.Store.SavePDF(settings.AcademicYear, settings.Semester, "", "Whole school semester stats", pdf); err != nil {
		return n, err
	}
	key := settings.AcademicYear + "-" + strconv.Itoa(settings.Semester)
	_ = a.Store.MarkReportGenerated(key)
	return n + 1, nil
}

func (a *API) MaybeAutoSemester() {
	settings, err := a.Store.Settings()
	if err != nil || settings.SemesterEnd == "" {
		return
	}
	end, err := time.Parse("2006-01-02", settings.SemesterEnd)
	if err != nil || end.After(a.now()) {
		return
	}
	key := settings.AcademicYear + "-" + strconv.Itoa(settings.Semester)
	got, _ := a.Store.ReportGeneratedFor()
	if got == key {
		return
	}
	_, _ = a.MakeSemesterReports()
}

func (a *API) listSemester(w http.ResponseWriter, r *http.Request) {
	u, ok := a.user(w, r)
	if !ok {
		return
	}
	if !u.SeesSchool() && u.Role != "teacher" {
		a.fail(w, 403, "You cannot do that")
		return
	}
	list, err := a.Store.ListPDFs()
	a.call(w, err, list)
}

func (a *API) getSemester(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.user(w, r); !ok {
		return
	}
	meta, pdf, err := a.Store.PDF(r.PathValue("id"))
	if err != nil {
		a.fail(w, 404, "That report was not found")
		return
	}
	w.Header().Set("Content-Type", "application/pdf")
	w.Header().Set("Content-Disposition", "attachment; filename=\""+safeName(meta.Title)+".pdf\"")
	_, _ = w.Write(pdf)
}

func (a *API) marksheet(w http.ResponseWriter, r *http.Request) {
	u, ok := a.user(w, r)
	if !ok {
		return
	}
	id := r.PathValue("id")
	if !a.canSeeClass(u, id) {
		a.fail(w, 403, "You cannot open that class")
		return
	}
	settings, _ := a.Store.Settings()
	results, err := a.Store.ClassResults(id, settings.Semester)
	if err != nil {
		a.fail(w, 400, err.Error())
		return
	}
	pdf, err := report.PDF(marksheetDoc(a.schoolName(), settings, results))
	if err != nil {
		a.fail(w, 500, "The sheet could not be made")
		return
	}
	w.Header().Set("Content-Type", "application/pdf")
	w.Header().Set("Content-Disposition", "attachment; filename=\""+safeName(results.Class.Name)+"-marks.pdf\"")
	_, _ = w.Write(pdf)
}

func (a *API) timetablePDF(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.user(w, r); !ok {
		return
	}
	slots, err := a.Store.Timetable()
	if err != nil {
		a.fail(w, 400, err.Error())
		return
	}
	classID := r.URL.Query().Get("class_id")
	teacherID := r.URL.Query().Get("teacher_id")
	var rows [][]string
	days := []string{"Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"}
	for _, sl := range slots {
		if classID != "" && sl.ClassID != classID {
			continue
		}
		if teacherID != "" && sl.TeacherStaffID != teacherID {
			continue
		}
		day := strconv.Itoa(sl.Day + 1)
		if sl.Day >= 0 && sl.Day < len(days) {
			day = days[sl.Day]
		}
		rows = append(rows, []string{sl.ClassName, day, strconv.Itoa(sl.Period + 1), sl.SubjectName, sl.TeacherName})
	}
	doc := report.Document{
		School: a.schoolName(), Title: "Timetable", When: a.now(),
		Sections: []report.Section{{
			Title: "Week",
			Table: &report.Table{Headers: []string{"Class", "Day", "Period", "Subject", "Teacher"}, Rows: rows},
		}},
	}
	pdf, err := report.PDF(doc)
	if err != nil {
		a.fail(w, 500, "The timetable could not be made")
		return
	}
	w.Header().Set("Content-Type", "application/pdf")
	w.Header().Set("Content-Disposition", "attachment; filename=\"timetable.pdf\"")
	_, _ = w.Write(pdf)
}

func (a *API) exportReport(w http.ResponseWriter, r *http.Request) {
	if _, ok := a.must(w, r, "director"); !ok {
		return
	}
	var in struct {
		Format   string   `json:"format"`
		Sections []string `json:"sections"`
	}
	if !a.read(w, r, &in) {
		return
	}
	doc, err := a.directorDoc(in.Sections)
	if err != nil {
		a.fail(w, 400, err.Error())
		return
	}
	var raw []byte
	var ctype, ext string
	switch in.Format {
	case "docx":
		raw, err = report.DOCX(doc)
		ctype, ext = "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "docx"
	case "pptx":
		raw, err = report.PPTX(doc)
		ctype, ext = "application/vnd.openxmlformats-officedocument.presentationml.presentation", "pptx"
	default:
		raw, err = report.PDF(doc)
		ctype, ext = "application/pdf", "pdf"
	}
	if err != nil {
		a.fail(w, 500, "The report could not be made")
		return
	}
	w.Header().Set("Content-Type", ctype)
	w.Header().Set("Content-Disposition", "attachment; filename=\"school-report."+ext+"\"")
	_, _ = w.Write(raw)
}

func (a *API) directorDoc(sections []string) (report.Document, error) {
	want := map[string]bool{}
	if len(sections) == 0 {
		for _, s := range []string{"overview", "results", "fees", "finance", "staff", "absence", "meetings"} {
			want[s] = true
		}
	}
	for _, s := range sections {
		want[s] = true
	}
	settings, err := a.Store.Settings()
	if err != nil {
		return report.Document{}, err
	}
	doc := report.Document{
		School: a.schoolName(), Title: "School report",
		Subtitle: fmt.Sprintf("Semester %d · %s", settings.Semester, settings.AcademicYear),
		When:     a.now(),
	}
	classes, _ := a.Store.ListClasses()
	students, _ := a.Store.ListStudents("")
	if want["overview"] {
		head := storeHead(students)
		doc.Sections = append(doc.Sections, report.Section{
			Title: "The school",
			Lines: []string{
				fmt.Sprintf("Classes %d. Students %d. Boys %d. Girls %d.", len(classes), head.Students, head.Male, head.Female),
				fmt.Sprintf("Still in school %d. Left school %d.", head.Active, head.Dropped),
			},
		})
	}
	if want["results"] {
		var rows [][]string
		var labels []string
		var values []float64
		for _, c := range classes {
			st, err := a.Store.Promotion(c.ID, settings.Semester)
			if err != nil {
				continue
			}
			rows = append(rows, []string{c.Name, itoa(st.Promoted), itoa(st.PromotedM), itoa(st.PromotedF), itoa(st.Failed), itoa(st.FailedM), itoa(st.FailedF), itoa(st.Head.Dropped), fmt.Sprintf("%.2f", st.PromotedPct)})
			labels = append(labels, c.Name)
			values = append(values, float64(st.Promoted))
		}
		doc.Sections = append(doc.Sections, report.Section{
			Title: "Promoted and failed",
			Table: &report.Table{Headers: []string{"Class", "Promoted", "Boys", "Girls", "Failed", "Boys", "Girls", "Left", "% promoted"}, Rows: rows},
			Chart: report.Bars("PROMOTED", labels, values),
		})
	}
	if want["fees"] {
		fin, _ := a.Store.Finance()
		doc.Sections = append(doc.Sections, report.Section{Title: "School fees", Lines: []string{
			fmt.Sprintf("Paid %.2f. Still to pay %.2f.", fin.FeesCollected, fin.FeesRemaining),
		}})
	}
	if want["finance"] {
		fin, _ := a.Store.Finance()
		doc.Sections = append(doc.Sections, report.Section{Title: "Money", Lines: []string{
			fmt.Sprintf("Fees collected %.2f. Other income %.2f. Income together %.2f.", fin.FeesCollected, fin.ManualIncome, fin.TotalIncome),
			fmt.Sprintf("Expenses %.2f. Workshops %.2f. Sports %.2f. Utility fee %.2f.", fin.Expenses, fin.Workshops, fin.Sports, fin.UtilityFee),
			fmt.Sprintf("Spent together %.2f. Balance %.2f.", fin.TotalExpense, fin.Balance),
		}})
	}
	if want["staff"] {
		st, _ := a.Store.StaffStats()
		var rows [][]string
		for _, q := range st.ByQualification {
			rows = append(rows, []string{q.Qualification, itoa(q.Male), itoa(q.Female), itoa(q.Male + q.Female)})
		}
		doc.Sections = append(doc.Sections, report.Section{
			Title: "Staff",
			Lines: []string{fmt.Sprintf("Teaching boys %d, girls %d. Other staff boys %d, girls %d.", st.TeachingMale, st.TeachingFemale, st.NonTeachingMale, st.NonTeachingFemale)},
			Table: &report.Table{Headers: []string{"Qualification", "Male", "Female", "Total"}, Rows: rows},
		})
	}
	if want["absence"] {
		staff, _ := a.Store.ListStaff()
		var rows [][]string
		now := a.now()
		for _, p := range staff {
			if p.StaffType != "teaching" {
				continue
			}
			rep, err := a.Store.AbsenceReport(p.ID, now.Year(), now.Month())
			if err != nil {
				continue
			}
			rows = append(rows, []string{p.FullName, itoa(rep.AbsentDays), fmt.Sprintf("%.2f", rep.AbsenteeismPerWeek), itoa(rep.LostPeriods), itoa(rep.MakeupClasses), fmt.Sprintf("%.2f", rep.PercentLost)})
		}
		doc.Sections = append(doc.Sections, report.Section{
			Title: "Teacher absence this month",
			Table: &report.Table{Headers: []string{"Teacher", "Days away", "Days per week", "Periods lost", "Make-up classes", "% lost"}, Rows: rows},
		})
	}
	if want["meetings"] {
		meetings, _ := a.Store.ListMeetings()
		var rows [][]string
		for _, m := range meetings {
			rows = append(rows, []string{m.MeetingDate, m.Title, m.Attendees, m.Notes})
		}
		doc.Sections = append(doc.Sections, report.Section{
			Title: "Meetings",
			Table: &report.Table{Headers: []string{"Date", "Title", "People", "Notes"}, Rows: rows},
		})
	}
	return doc, nil
}

func classStatDoc(school string, settings store.Settings, st store.PromotionStat, reasons []store.ReasonCount) report.Document {
	lines := []string{
		fmt.Sprintf("On the roll %d. Boys %d. Girls %d.", st.Head.Students, st.Head.Male, st.Head.Female),
		fmt.Sprintf("Promoted %d (%.2f%%). Boys %d. Girls %d.", st.Promoted, st.PromotedPct, st.PromotedM, st.PromotedF),
		fmt.Sprintf("Failed %d (%.2f%%). Boys %d. Girls %d.", st.Failed, st.FailedPct, st.FailedM, st.FailedF),
		fmt.Sprintf("Left school %d (%.2f%%). Boys %d. Girls %d.", st.Head.Dropped, st.DropoutPct, st.Head.DroppedM, st.Head.DroppedF),
	}
	for _, reason := range reasons {
		lines = append(lines, fmt.Sprintf("Left: %s. %d (boys %d, girls %d).", reason.Reason, reason.Total, reason.Male, reason.Female))
	}
	return report.Document{
		School: school, Title: st.ClassName + " semester stats",
		Subtitle: fmt.Sprintf("Semester %d · %s", settings.Semester, settings.AcademicYear),
		When:     time.Now(),
		Sections: []report.Section{{
			Title: "Promoted, failed, and left",
			Lines: lines,
			Chart: report.Bars("STUDENTS", []string{"Promoted", "Failed", "Left"}, []float64{float64(st.Promoted), float64(st.Failed), float64(st.Head.Dropped)}),
		}},
	}
}

func schoolStatDoc(school string, settings store.Settings, stats []store.PromotionStat) report.Document {
	var rows [][]string
	var p, f, d, n int
	var labels []string
	var values []float64
	for _, st := range stats {
		rows = append(rows, []string{st.ClassName, itoa(st.Promoted), itoa(st.PromotedM), itoa(st.PromotedF), itoa(st.Failed), itoa(st.FailedM), itoa(st.FailedF), itoa(st.Head.Dropped), itoa(st.Head.DroppedM), itoa(st.Head.DroppedF)})
		p += st.Promoted
		f += st.Failed
		d += st.Head.Dropped
		n += st.Head.Students
		labels = append(labels, st.ClassName)
		values = append(values, st.PromotedPct)
	}
	return report.Document{
		School: school, Title: "Whole school semester stats",
		Subtitle: fmt.Sprintf("Semester %d · %s", settings.Semester, settings.AcademicYear),
		When:     time.Now(),
		Sections: []report.Section{{
			Title: "All classes",
			Lines: []string{fmt.Sprintf("Students %d. Promoted %d. Failed %d. Left %d.", n, p, f, d)},
			Table: &report.Table{Headers: []string{"Class", "Promoted", "Boys", "Girls", "Failed", "Boys", "Girls", "Left", "Boys", "Girls"}, Rows: rows},
			Chart: report.Bars("PERCENT PROMOTED", labels, values),
		}},
	}
}

func marksheetDoc(school string, settings store.Settings, results store.ClassResults) report.Document {
	headers := []string{"Student"}
	if len(results.Students) > 0 {
		for _, col := range results.Students[0].Subjects {
			headers = append(headers, col.ClassSubject.SubjectName)
		}
	}
	headers = append(headers, "Average", "Rank", "Result")
	var rows [][]string
	for _, sr := range results.Students {
		row := []string{sr.Student.FullName}
		for _, col := range sr.Subjects {
			row = append(row, fmt.Sprintf("%.2f", col.Result.Total))
		}
		rank := ""
		if sr.Standing.Rank > 0 {
			rank = itoa(sr.Standing.Rank)
		}
		row = append(row, fmt.Sprintf("%.2f", sr.Standing.Average), rank, plainStatus(sr.Standing.Status))
		rows = append(rows, row)
	}
	return report.Document{
		School: school, Title: results.Class.Name + " marks",
		Subtitle: fmt.Sprintf("Semester %d · %s", settings.Semester, settings.AcademicYear),
		When:     time.Now(),
		Sections: []report.Section{{Title: "Marks out of 100", Table: &report.Table{Headers: headers, Rows: rows}}},
	}
}

func plainStatus(s string) string {
	switch s {
	case "promoted":
		return "Promoted"
	case "failed":
		return "Failed"
	case "dropout":
		return "Left"
	default:
		return "Not ready"
	}
}

func itoa(n int) string { return strconv.Itoa(n) }

func safeName(s string) string {
	s = strings.Map(func(r rune) rune {
		if r == ' ' || r == '-' || (r >= '0' && r <= '9') || (r >= 'A' && r <= 'Z') || (r >= 'a' && r <= 'z') {
			return r
		}
		return '-'
	}, s)
	if s == "" {
		return "report"
	}
	return s
}
