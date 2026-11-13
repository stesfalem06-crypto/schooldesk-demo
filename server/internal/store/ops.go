package store

import (
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"

	"schooldesk/internal/domain"
)

func (s *Store) AddAbsence(staffID, date, note string) error {
	if !validDate(date) {
		return errStr("the date is not valid")
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	var n int
	if err := s.db.QueryRow(`SELECT COUNT(*) FROM staff WHERE id = ?`, staffID).Scan(&n); err != nil {
		return err
	}
	if n == 0 {
		return ErrNotFound
	}
	id := NewID()
	now := Now()
	_, err := s.db.Exec(`INSERT INTO absences (id, staff_id, absent_on, note, created_at, updated_at) VALUES (?,?,?,?,?,?)`,
		id, staffID, date, clean(note), now, now)
	if err != nil && stringsContainsUnique(err) {
		return errStr("that day is already marked")
	}
	return err
}

type AbsenceDay struct {
	ID         string `json:"id"`
	StaffID    string `json:"staff_id"`
	StaffName  string `json:"staff_name"`
	EmployeeID string `json:"employee_id"`
	Date       string `json:"date"`
	Note       string `json:"note"`
}

func (s *Store) ListAbsences(year int, month int) ([]AbsenceDay, error) {
	if month < 1 || month > 12 || year < 2000 {
		return nil, errStr("that month is not valid")
	}
	start := time.Date(year, time.Month(month), 1, 0, 0, 0, 0, time.UTC)
	end := start.AddDate(0, 1, 0)
	s.mu.Lock()
	defer s.mu.Unlock()
	rows, err := s.db.Query(`SELECT a.id, a.staff_id, st.full_name, st.employee_id, a.absent_on, a.note
		FROM absences a JOIN staff st ON st.id = a.staff_id
		WHERE a.absent_on >= ? AND a.absent_on < ?
		ORDER BY st.full_name, a.absent_on`, start.Format("2006-01-02"), end.Format("2006-01-02"))
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []AbsenceDay{}
	for rows.Next() {
		var d AbsenceDay
		if err := rows.Scan(&d.ID, &d.StaffID, &d.StaffName, &d.EmployeeID, &d.Date, &d.Note); err != nil {
			return nil, err
		}
		out = append(out, d)
	}
	return out, rows.Err()
}

func (s *Store) DeleteAbsence(id string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	res, err := s.db.Exec(`DELETE FROM absences WHERE id = ?`, id)
	if err != nil {
		return err
	}
	n, _ := res.RowsAffected()
	if n == 0 {
		return ErrNotFound
	}
	return nil
}

func (s *Store) AddMakeup(staffID, date, note string, periods int) error {
	if !validDate(date) {
		return errStr("the date is not valid")
	}
	if periods < 1 || periods > 12 {
		return errStr("enter how many periods were made up")
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	_, err := s.db.Exec(`INSERT INTO makeups (id, staff_id, held_on, periods, note, created_at, updated_at) VALUES (?,?,?,?,?,?,?)`,
		NewID(), staffID, date, periods, clean(note), Now(), Now())
	return err
}

func (s *Store) SetWeeklyPeriods(staffID string, periods []int) error {
	if len(periods) != 7 {
		return errStr("enter periods for each day of the week")
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if _, err := tx.Exec(`DELETE FROM weekly_periods WHERE staff_id = ?`, staffID); err != nil {
		return err
	}
	for day, n := range periods {
		if n < 0 || n > 16 {
			return errStr("periods in a day must be from 0 to 16")
		}
		if n == 0 {
			continue
		}
		if _, err := tx.Exec(`INSERT INTO weekly_periods (staff_id, weekday, periods) VALUES (?,?,?)`, staffID, day, n); err != nil {
			return err
		}
	}
	return tx.Commit()
}

func (s *Store) AbsenceReport(staffID string, year int, month time.Month) (domain.MonthReport, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	bell := s.bell(s.db)
	periods := map[time.Weekday]int{}
	var slotCount int
	_ = s.db.QueryRow(`SELECT COUNT(*) FROM timetable_slots WHERE teacher_staff_id = ? AND class_subject_id != ''`, staffID).Scan(&slotCount)
	if slotCount > 0 {
		rows, err := s.db.Query(`SELECT day_index, COUNT(*) FROM timetable_slots WHERE teacher_staff_id = ? AND class_subject_id != '' GROUP BY day_index`, staffID)
		if err != nil {
			return domain.MonthReport{}, err
		}
		for rows.Next() {
			var day, n int
			if err := rows.Scan(&day, &n); err != nil {
				rows.Close()
				return domain.MonthReport{}, err
			}
			if wd, ok := weekdayFromIndex(day); ok {
				periods[wd] = n
			}
		}
		rows.Close()
	} else {
		rows, err := s.db.Query(`SELECT weekday, periods FROM weekly_periods WHERE staff_id = ?`, staffID)
		if err != nil {
			return domain.MonthReport{}, err
		}
		for rows.Next() {
			var day, n int
			if err := rows.Scan(&day, &n); err != nil {
				rows.Close()
				return domain.MonthReport{}, err
			}
			if wd, ok := weekdayFromIndex(day); ok {
				periods[wd] = n
			}
		}
		rows.Close()
	}
	var school []time.Weekday
	for i := 0; i < bell.Days && i < 7; i++ {
		if wd, ok := weekdayFromIndex(i); ok {
			school = append(school, wd)
		}
	}
	start := time.Date(year, month, 1, 0, 0, 0, 0, time.UTC)
	end := start.AddDate(0, 1, 0)
	rows, err := s.db.Query(`SELECT absent_on FROM absences WHERE staff_id = ? AND absent_on >= ? AND absent_on < ?`, staffID, start.Format("2006-01-02"), end.Format("2006-01-02"))
	if err != nil {
		return domain.MonthReport{}, err
	}
	var absent []time.Time
	for rows.Next() {
		var d string
		if err := rows.Scan(&d); err != nil {
			rows.Close()
			return domain.MonthReport{}, err
		}
		t, err := time.Parse("2006-01-02", d)
		if err == nil {
			absent = append(absent, t)
		}
	}
	rows.Close()
	var classes, per int
	_ = s.db.QueryRow(`SELECT COUNT(*), COALESCE(SUM(periods),0) FROM makeups WHERE staff_id = ? AND held_on >= ? AND held_on < ?`, staffID, start.Format("2006-01-02"), end.Format("2006-01-02")).Scan(&classes, &per)
	return domain.Absence(domain.MonthInput{
		Year: year, Month: month, SchoolDays: school, Periods: periods,
		Absent: absent, MakeupClasses: classes, MakeupPeriods: per,
	})
}

func weekdayFromIndex(i int) (time.Weekday, bool) {
	switch i {
	case 0:
		return time.Monday, true
	case 1:
		return time.Tuesday, true
	case 2:
		return time.Wednesday, true
	case 3:
		return time.Thursday, true
	case 4:
		return time.Friday, true
	case 5:
		return time.Saturday, true
	case 6:
		return time.Sunday, true
	default:
		return time.Monday, false
	}
}

func (s *Store) SaveMeeting(in Meeting) (Meeting, error) {
	if err := requireText(in.Title, "a title", 80); err != nil {
		return Meeting{}, err
	}
	if err := requireText(in.Attendees, "who attended", 400); err != nil {
		return Meeting{}, err
	}
	if !validDate(in.MeetingDate) {
		return Meeting{}, errStr("the date is not valid")
	}
	in.Title = clean(in.Title)
	in.Attendees = clean(in.Attendees)
	in.Notes = clean(in.Notes)
	now := Now()
	s.mu.Lock()
	defer s.mu.Unlock()
	if in.ID == "" {
		in.ID = NewID()
		_, err := s.db.Exec(`INSERT INTO meetings (id, meeting_date, title, attendees, notes, created_at, updated_at) VALUES (?,?,?,?,?,?,?)`,
			in.ID, in.MeetingDate, in.Title, in.Attendees, in.Notes, now, now)
		return in, err
	}
	res, err := s.db.Exec(`UPDATE meetings SET meeting_date=?, title=?, attendees=?, notes=?, updated_at=?, revision=revision+1 WHERE id=?`,
		in.MeetingDate, in.Title, in.Attendees, in.Notes, now, in.ID)
	if err != nil {
		return Meeting{}, err
	}
	n, _ := res.RowsAffected()
	if n == 0 {
		return Meeting{}, ErrNotFound
	}
	return in, nil
}

func (s *Store) ListMeetings() ([]Meeting, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	rows, err := s.db.Query(`SELECT id, meeting_date, title, attendees, notes FROM meetings ORDER BY meeting_date DESC, title`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Meeting
	for rows.Next() {
		var m Meeting
		if err := rows.Scan(&m.ID, &m.MeetingDate, &m.Title, &m.Attendees, &m.Notes); err != nil {
			return nil, err
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

func (s *Store) bell(q queryer) Bell {
	var b Bell
	err := q.QueryRow(`SELECT days, periods_per_day FROM bell WHERE id = 1`).Scan(&b.Days, &b.PeriodsPerDay)
	if err != nil || b.Days < 1 || b.PeriodsPerDay < 1 {
		return Bell{Days: 5, PeriodsPerDay: 6}
	}
	return b
}

func (s *Store) GetBell() (Bell, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.bell(s.db), nil
}

func (s *Store) SaveBell(b Bell) error {
	if b.Days < 1 || b.Days > 7 || b.PeriodsPerDay < 1 || b.PeriodsPerDay > 16 {
		return errStr("check the days and the periods in a day")
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	_, err := s.db.Exec(`INSERT INTO bell (id, days, periods_per_day, updated_at) VALUES (1,?,?,?)
		ON CONFLICT(id) DO UPDATE SET days=excluded.days, periods_per_day=excluded.periods_per_day, updated_at=excluded.updated_at`,
		b.Days, b.PeriodsPerDay, Now())
	return err
}

func (s *Store) SetBlocks(staffID string, slots [][2]int) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if _, err := tx.Exec(`DELETE FROM teacher_blocks WHERE staff_id = ?`, staffID); err != nil {
		return err
	}
	for _, sl := range slots {
		if _, err := tx.Exec(`INSERT INTO teacher_blocks (staff_id, day_index, period_index) VALUES (?,?,?)`, staffID, sl[0], sl[1]); err != nil {
			return err
		}
	}
	return tx.Commit()
}

func (s *Store) GenerateTimetable(semester int) ([]Slot, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	bell := s.bell(s.db)
	rows, err := s.db.Query(`SELECT id, class_id, teacher_staff_id, periods_per_week FROM class_subjects WHERE semester = ? AND teacher_staff_id != ''`, semester)
	if err != nil {
		return nil, err
	}
	var lessons []domain.LessonNeed
	for rows.Next() {
		var ls domain.LessonNeed
		if err := rows.Scan(&ls.ID, &ls.ClassID, &ls.TeacherID, &ls.Periods); err != nil {
			rows.Close()
			return nil, err
		}
		lessons = append(lessons, ls)
	}
	rows.Close()
	if len(lessons) == 0 {
		return nil, errStr("add subjects to classes before making a timetable")
	}
	unavail := map[string]map[int]bool{}
	brows, err := s.db.Query(`SELECT staff_id, day_index, period_index FROM teacher_blocks`)
	if err != nil {
		return nil, err
	}
	for brows.Next() {
		var staff string
		var day, period int
		if err := brows.Scan(&staff, &day, &period); err != nil {
			brows.Close()
			return nil, err
		}
		if unavail[staff] == nil {
			unavail[staff] = map[int]bool{}
		}
		unavail[staff][day*bell.PeriodsPerDay+period] = true
	}
	brows.Close()
	placed, err := domain.Solve(domain.Problem{Days: bell.Days, PeriodsPerDay: bell.PeriodsPerDay, Lessons: lessons, Unavailable: unavail})
	if err != nil {
		return nil, err
	}
	tx, err := s.db.Begin()
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()
	if _, err := tx.Exec(`DELETE FROM timetable_slots`); err != nil {
		return nil, err
	}
	now := Now()
	for _, p := range placed {
		if _, err := tx.Exec(`INSERT INTO timetable_slots (id, class_id, day_index, period_index, class_subject_id, teacher_staff_id, updated_at) VALUES (?,?,?,?,?,?,?)`,
			NewID(), p.ClassID, p.Day, p.Period, p.LessonID, p.TeacherID, now); err != nil {
			return nil, err
		}
	}
	if err := tx.Commit(); err != nil {
		return nil, err
	}
	return s.slots(s.db)
}

// MoveSlot drags the lesson in one cell to another cell of the same class.
func (s *Store) MoveSlot(classID string, fromDay, fromPeriod, toDay, toPeriod int) error {
	if fromDay == toDay && fromPeriod == toPeriod {
		return nil
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	bell := s.bell(s.db)
	if fromDay < 0 || toDay < 0 || fromDay >= bell.Days || toDay >= bell.Days || fromPeriod < 0 || toPeriod < 0 || fromPeriod >= bell.PeriodsPerDay || toPeriod >= bell.PeriodsPerDay {
		return errStr("that time is outside the week")
	}
	existing, err := s.slots(s.db)
	if err != nil {
		return err
	}
	var moving *Slot
	for i := range existing {
		if existing[i].ClassID == classID && existing[i].Day == fromDay && existing[i].Period == fromPeriod {
			moving = &existing[i]
			break
		}
	}
	if moving == nil || moving.ClassSubjectID == "" {
		return errStr("there is nothing to move")
	}
	var kept []domain.Placement
	for _, sl := range existing {
		if sl.ClassID == classID && sl.Day == fromDay && sl.Period == fromPeriod {
			continue
		}
		kept = append(kept, domain.Placement{ClassID: sl.ClassID, TeacherID: sl.TeacherStaffID, LessonID: sl.ClassSubjectID, Day: sl.Day, Period: sl.Period})
	}
	for _, p := range kept {
		if p.ClassID == classID && p.Day == toDay && p.Period == toPeriod {
			return errStr("This class already has a lesson then")
		}
	}
	var blocked int
	_ = s.db.QueryRow(`SELECT COUNT(*) FROM teacher_blocks WHERE staff_id = ? AND day_index = ? AND period_index = ?`, moving.TeacherStaffID, toDay, toPeriod).Scan(&blocked)
	unavail := map[string]map[int]bool{}
	if blocked > 0 {
		unavail[moving.TeacherStaffID] = map[int]bool{toDay*bell.PeriodsPerDay + toPeriod: true}
	}
	msgs := domain.ClashMessages(kept, domain.Placement{
		ClassID: classID, TeacherID: moving.TeacherStaffID, LessonID: moving.ClassSubjectID, Day: toDay, Period: toPeriod,
	}, unavail, bell.PeriodsPerDay)
	if len(msgs) > 0 {
		return errStr(msgs[0])
	}
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if _, err := tx.Exec(`DELETE FROM timetable_slots WHERE class_id = ? AND day_index = ? AND period_index = ?`, classID, fromDay, fromPeriod); err != nil {
		return err
	}
	if _, err := tx.Exec(`DELETE FROM timetable_slots WHERE class_id = ? AND day_index = ? AND period_index = ?`, classID, toDay, toPeriod); err != nil {
		return err
	}
	_, err = tx.Exec(`INSERT INTO timetable_slots (id, class_id, day_index, period_index, class_subject_id, teacher_staff_id, updated_at) VALUES (?,?,?,?,?,?,?)`,
		NewID(), classID, toDay, toPeriod, moving.ClassSubjectID, moving.TeacherStaffID, Now())
	if err != nil {
		return err
	}
	return tx.Commit()
}

func (s *Store) Timetable() ([]Slot, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.slots(s.db)
}

func (s *Store) slots(q queryer) ([]Slot, error) {
	rows, err := q.Query(`SELECT ts.id, ts.class_id, ts.day_index, ts.period_index, ts.class_subject_id, ts.teacher_staff_id,
		COALESCE(sub.name,''), COALESCE(st.full_name,''), COALESCE(c.name,'')
		FROM timetable_slots ts
		LEFT JOIN class_subjects cs ON cs.id = ts.class_subject_id
		LEFT JOIN subjects sub ON sub.id = cs.subject_id
		LEFT JOIN staff st ON st.id = ts.teacher_staff_id
		LEFT JOIN classes c ON c.id = ts.class_id
		ORDER BY ts.class_id, ts.day_index, ts.period_index`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Slot
	for rows.Next() {
		var sl Slot
		if err := rows.Scan(&sl.ID, &sl.ClassID, &sl.Day, &sl.Period, &sl.ClassSubjectID, &sl.TeacherStaffID, &sl.SubjectName, &sl.TeacherName, &sl.ClassName); err != nil {
			return nil, err
		}
		out = append(out, sl)
	}
	return out, rows.Err()
}

func (s *Store) TouchDevice(id, name, platform string, max int) error {
	if id == "" {
		return nil
	}
	if len(id) < 8 || len(id) > 80 {
		return errStr("this device is not recognised")
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	var n int
	err := s.db.QueryRow(`SELECT COUNT(*) FROM devices WHERE id = ?`, id).Scan(&n)
	if err != nil {
		return err
	}
	now := Now()
	if n == 0 {
		var count int
		if err := s.db.QueryRow(`SELECT COUNT(*) FROM devices`).Scan(&count); err != nil {
			return err
		}
		if max > 0 && count >= max {
			return errStr("this school already has the allowed number of devices")
		}
		_, err = s.db.Exec(`INSERT INTO devices (id, name, platform, created_at, last_seen_at) VALUES (?,?,?,?,?)`, id, clean(name), clean(platform), now, now)
		return err
	}
	_, err = s.db.Exec(`UPDATE devices SET name = ?, platform = ?, last_seen_at = ? WHERE id = ?`, clean(name), clean(platform), now, id)
	return err
}

func (s *Store) ListDevices() ([]Device, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	rows, err := s.db.Query(`SELECT id, name, platform, created_at, last_seen_at FROM devices ORDER BY last_seen_at DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Device
	for rows.Next() {
		var d Device
		if err := rows.Scan(&d.ID, &d.Name, &d.Platform, &d.CreatedAt, &d.LastSeenAt); err != nil {
			return nil, err
		}
		out = append(out, d)
	}
	return out, rows.Err()
}

func (s *Store) DeleteDevice(id string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	_, err := s.db.Exec(`DELETE FROM devices WHERE id = ?`, id)
	return err
}

func (s *Store) ChangesSince(seq int64, limit int) ([]Change, error) {
	if limit <= 0 || limit > 500 {
		limit = 200
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	rows, err := s.db.Query(`SELECT seq, entity, entity_id, deleted, payload, updated_at FROM changes WHERE seq > ? ORDER BY seq LIMIT ?`, seq, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Change
	for rows.Next() {
		var c Change
		var del int
		if err := rows.Scan(&c.Seq, &c.Entity, &c.EntityID, &del, &c.Payload, &c.UpdatedAt); err != nil {
			return nil, err
		}
		c.Deleted = del == 1
		out = append(out, c)
	}
	return out, rows.Err()
}

func (s *Store) SavePDF(year string, semester int, classID, title string, pdf []byte) (SavedReport, error) {
	rep := SavedReport{ID: NewID(), AcademicYear: year, Semester: semester, ClassID: classID, Title: title, GeneratedAt: Now()}
	s.mu.Lock()
	defer s.mu.Unlock()
	_, err := s.db.Exec(`INSERT INTO semester_reports (id, academic_year, semester, class_id, title, generated_at, pdf) VALUES (?,?,?,?,?,?,?)`,
		rep.ID, rep.AcademicYear, rep.Semester, rep.ClassID, rep.Title, rep.GeneratedAt, pdf)
	return rep, err
}

func (s *Store) ListPDFs() ([]SavedReport, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	rows, err := s.db.Query(`SELECT id, academic_year, semester, class_id, title, generated_at FROM semester_reports ORDER BY generated_at DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []SavedReport
	for rows.Next() {
		var r SavedReport
		if err := rows.Scan(&r.ID, &r.AcademicYear, &r.Semester, &r.ClassID, &r.Title, &r.GeneratedAt); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

func (s *Store) PDF(id string) (SavedReport, []byte, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	var r SavedReport
	var pdf []byte
	err := s.db.QueryRow(`SELECT id, academic_year, semester, class_id, title, generated_at, pdf FROM semester_reports WHERE id = ?`, id).
		Scan(&r.ID, &r.AcademicYear, &r.Semester, &r.ClassID, &r.Title, &r.GeneratedAt, &pdf)
	return r, pdf, err
}

func (s *Store) BackupTo(dest string) error {
	if err := os.MkdirAll(filepath.Dir(dest), 0o755); err != nil {
		return err
	}
	_ = os.Remove(dest)
	s.mu.Lock()
	defer s.mu.Unlock()
	slash := filepath.ToSlash(dest)
	_, err := s.db.Exec(`VACUUM INTO '` + strings.ReplaceAll(slash, `'`, `''`) + `'`)
	return err
}

func (s *Store) RestoreFrom(src string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	_, _ = s.db.Exec(`PRAGMA wal_checkpoint(TRUNCATE)`)
	if err := s.db.Close(); err != nil {
		return err
	}
	backup := s.path + ".before-restore"
	if err := copyFile(s.path, backup); err != nil {
		s.reopen()
		return err
	}
	if err := copyFile(src, s.path); err != nil {
		_ = copyFile(backup, s.path)
		s.reopen()
		return err
	}
	RemoveWAL(s.path)
	if err := s.reopen(); err != nil {
		_ = copyFile(backup, s.path)
		_ = s.reopen()
		return err
	}
	return nil
}

func (s *Store) reopen() error {
	db, err := openDB(s.path)
	if err != nil {
		return err
	}
	s.db = db
	return nil
}

func copyFile(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	out, err := os.OpenFile(dst, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0o600)
	if err != nil {
		return err
	}
	defer out.Close()
	if _, err := io.Copy(out, in); err != nil {
		return err
	}
	return out.Close()
}

func (s *Store) ClearSample() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	stmts := []string{
		`DELETE FROM scores`,
		`DELETE FROM score_undo`,
		`DELETE FROM assessments`,
		`DELETE FROM enrollments`,
		`DELETE FROM student_fields`,
		`DELETE FROM students`,
		`DELETE FROM custom_fields`,
		`DELETE FROM timetable_slots`,
		`DELETE FROM teacher_blocks`,
		`DELETE FROM class_subjects`,
		`DELETE FROM subjects`,
		`DELETE FROM classes`,
		`DELETE FROM fee_payments`,
		`DELETE FROM incomes`,
		`DELETE FROM expenses`,
		`DELETE FROM workshop_expenses`,
		`DELETE FROM sports_expenses`,
		`DELETE FROM absences`,
		`DELETE FROM makeups`,
		`DELETE FROM weekly_periods`,
		`DELETE FROM meetings`,
		`DELETE FROM semester_reports`,
		`DELETE FROM changes`,
		`DELETE FROM staff`,
		`DELETE FROM users WHERE role = 'teacher'`,
	}
	for _, q := range stmts {
		if _, err := tx.Exec(q); err != nil {
			return err
		}
	}
	if err := s.putSetting(tx, "sample_data", "0"); err != nil {
		return err
	}
	return tx.Commit()
}
