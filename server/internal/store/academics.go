package store

import (
	"database/sql"
	"errors"

	"schooldesk/internal/domain"
)

func (s *Store) AddClassSubject(classID, subjectID, teacherID string, periods, semester int, weights domain.Weights) (ClassSubject, error) {
	if periods < 1 || periods > 20 {
		return ClassSubject{}, errStr("periods per week must be from 1 to 20")
	}
	if semester != 1 && semester != 2 {
		return ClassSubject{}, errStr("semester must be 1 or 2")
	}
	if !weights.Valid() {
		return ClassSubject{}, errStr("the six parts must add up to 60")
	}
	now := Now()
	id := NewID()
	s.mu.Lock()
	defer s.mu.Unlock()
	tx, err := s.db.Begin()
	if err != nil {
		return ClassSubject{}, err
	}
	defer tx.Rollback()
	_, err = tx.Exec(`INSERT INTO class_subjects (id, class_id, subject_id, teacher_staff_id, periods_per_week, semester,
		w_classwork, w_quizzes, w_tests, w_assignments, w_participation, w_homework, created_at, updated_at)
		VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
		id, classID, subjectID, teacherID, periods, semester,
		weights.Classwork, weights.Quizzes, weights.Tests, weights.Assignments, weights.Participation, weights.Homework, now, now)
	if err != nil {
		if stringsContainsUnique(err) {
			return ClassSubject{}, errStr("that subject is already on this class for the semester")
		}
		return ClassSubject{}, err
	}
	examID := NewID()
	_, err = tx.Exec(`INSERT INTO assessments (id, class_subject_id, component, half, title, max_marks, assessment_date, created_at, updated_at)
		VALUES (?,?, 'exam', 0, 'Semester exam', 40, '', ?, ?)`, examID, id, now, now)
	if err != nil {
		return ClassSubject{}, err
	}
	rows, err := tx.Query(`SELECT id FROM students WHERE class_id = ?`, classID)
	if err != nil {
		return ClassSubject{}, err
	}
	var students []string
	for rows.Next() {
		var sid string
		if err := rows.Scan(&sid); err != nil {
			rows.Close()
			return ClassSubject{}, err
		}
		students = append(students, sid)
	}
	rows.Close()
	for _, sid := range students {
		if _, err := tx.Exec(`INSERT OR IGNORE INTO enrollments (student_id, class_subject_id) VALUES (?,?)`, sid, id); err != nil {
			return ClassSubject{}, err
		}
	}
	got, err := s.classSubjectByID(tx, id)
	if err != nil {
		return ClassSubject{}, err
	}
	if err := s.logChange(tx, "class_subjects", id, false, got); err != nil {
		return ClassSubject{}, err
	}
	return got, tx.Commit()
}

func stringsContainsUnique(err error) bool {
	if err == nil {
		return false
	}
	msg := err.Error()
	return containsFold(msg, "unique")
}

func containsFold(s, sub string) bool {
	return len(s) >= len(sub) && (func() bool {
		for i := 0; i+len(sub) <= len(s); i++ {
			ok := true
			for j := 0; j < len(sub); j++ {
				a, b := s[i+j], sub[j]
				if a >= 'A' && a <= 'Z' {
					a += 'a' - 'A'
				}
				if b >= 'A' && b <= 'Z' {
					b += 'a' - 'A'
				}
				if a != b {
					ok = false
					break
				}
			}
			if ok {
				return true
			}
		}
		return false
	})()
}

func (s *Store) SetWeights(id string, weights domain.Weights, locked bool) error {
	if locked {
		return errStr("the school set these parts. Teachers cannot change them")
	}
	if !weights.Valid() {
		return errStr("the six parts must add up to 60")
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	res, err := s.db.Exec(`UPDATE class_subjects SET w_classwork=?, w_quizzes=?, w_tests=?, w_assignments=?, w_participation=?, w_homework=?, updated_at=?, revision=revision+1 WHERE id=?`,
		weights.Classwork, weights.Quizzes, weights.Tests, weights.Assignments, weights.Participation, weights.Homework, Now(), id)
	if err != nil {
		return err
	}
	n, _ := res.RowsAffected()
	if n == 0 {
		return ErrNotFound
	}
	return nil
}

func (s *Store) ListClassSubjects(classID string, semester int) ([]ClassSubject, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	q := `SELECT cs.id FROM class_subjects cs WHERE 1=1`
	var args []any
	if classID != "" {
		q += ` AND cs.class_id = ?`
		args = append(args, classID)
	}
	if semester == 1 || semester == 2 {
		q += ` AND cs.semester = ?`
		args = append(args, semester)
	}
	rows, err := s.db.Query(q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var ids []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	rows.Close()
	out := make([]ClassSubject, 0, len(ids))
	for _, id := range ids {
		cs, err := s.classSubjectByID(s.db, id)
		if err != nil {
			return nil, err
		}
		out = append(out, cs)
	}
	return out, nil
}

func (s *Store) classSubjectByID(q queryer, id string) (ClassSubject, error) {
	var cs ClassSubject
	err := q.QueryRow(`SELECT cs.id, cs.class_id, c.name, cs.subject_id, sub.name, cs.teacher_staff_id, COALESCE(st.full_name,''),
		cs.periods_per_week, cs.semester, cs.w_classwork, cs.w_quizzes, cs.w_tests, cs.w_assignments, cs.w_participation, cs.w_homework
		FROM class_subjects cs
		JOIN classes c ON c.id = cs.class_id
		JOIN subjects sub ON sub.id = cs.subject_id
		LEFT JOIN staff st ON st.id = cs.teacher_staff_id
		WHERE cs.id = ?`, id).Scan(&cs.ID, &cs.ClassID, &cs.ClassName, &cs.SubjectID, &cs.SubjectName, &cs.TeacherStaffID, &cs.TeacherName,
		&cs.PeriodsPerWeek, &cs.Semester, &cs.Weights.Classwork, &cs.Weights.Quizzes, &cs.Weights.Tests, &cs.Weights.Assignments, &cs.Weights.Participation, &cs.Weights.Homework)
	if errors.Is(err, sql.ErrNoRows) {
		return ClassSubject{}, ErrNotFound
	}
	return cs, err
}

func (s *Store) ClassSubject(id string) (ClassSubject, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.classSubjectByID(s.db, id)
}

func (s *Store) AddAssessment(classSubjectID, component string, half int, title string, max float64, date string) (Assessment, error) {
	if component == "exam" {
		return Assessment{}, errStr("the semester exam is already on the subject")
	}
	if !domain.Component(component).CA() {
		return Assessment{}, errStr("choose a mark part")
	}
	if half != 1 && half != 2 {
		return Assessment{}, errStr("choose the first half or the second half")
	}
	if err := requireText(title, "a name for this mark", 60); err != nil {
		return Assessment{}, err
	}
	if max <= 0 || max > 1000 {
		return Assessment{}, errStr("the full mark must be more than zero")
	}
	if date != "" && !validDate(date) {
		return Assessment{}, errStr("the date is not valid")
	}
	a := Assessment{ID: NewID(), ClassSubjectID: classSubjectID, Component: component, Half: half, Title: clean(title), MaxMarks: max, AssessmentDate: date, Revision: 1}
	now := Now()
	s.mu.Lock()
	defer s.mu.Unlock()
	tx, err := s.db.Begin()
	if err != nil {
		return Assessment{}, err
	}
	defer tx.Rollback()
	if _, err := s.classSubjectByID(tx, classSubjectID); err != nil {
		return Assessment{}, err
	}
	_, err = tx.Exec(`INSERT INTO assessments (id, class_subject_id, component, half, title, max_marks, assessment_date, created_at, updated_at)
		VALUES (?,?,?,?,?,?,?,?,?)`, a.ID, a.ClassSubjectID, a.Component, a.Half, a.Title, a.MaxMarks, a.AssessmentDate, now, now)
	if err != nil {
		return Assessment{}, err
	}
	if err := s.logChange(tx, "assessments", a.ID, false, a); err != nil {
		return Assessment{}, err
	}
	return a, tx.Commit()
}

func (s *Store) AssessmentClassSubject(id string) (string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	var cs string
	err := s.db.QueryRow(`SELECT class_subject_id FROM assessments WHERE id = ?`, id).Scan(&cs)
	if errors.Is(err, sql.ErrNoRows) {
		return "", ErrNotFound
	}
	return cs, err
}

func (s *Store) ListAssessments(classSubjectID string) ([]Assessment, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	rows, err := s.db.Query(`SELECT id, class_subject_id, component, half, title, max_marks, assessment_date, revision FROM assessments WHERE class_subject_id = ? ORDER BY component, half, title`, classSubjectID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Assessment
	for rows.Next() {
		var a Assessment
		if err := rows.Scan(&a.ID, &a.ClassSubjectID, &a.Component, &a.Half, &a.Title, &a.MaxMarks, &a.AssessmentDate, &a.Revision); err != nil {
			return nil, err
		}
		out = append(out, a)
	}
	return out, rows.Err()
}

func (s *Store) ListScores(assessmentID string) ([]Score, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.scoresFor(s.db, assessmentID)
}

func (s *Store) scoresFor(q queryer, assessmentID string) ([]Score, error) {
	rows, err := q.Query(`SELECT id, assessment_id, student_id, score, revision, updated_at FROM scores WHERE assessment_id = ?`, assessmentID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Score
	for rows.Next() {
		var sc Score
		var val sql.NullFloat64
		if err := rows.Scan(&sc.ID, &sc.AssessmentID, &sc.StudentID, &val, &sc.Revision, &sc.UpdatedAt); err != nil {
			return nil, err
		}
		if val.Valid {
			v := val.Float64
			sc.Score = &v
		}
		out = append(out, sc)
	}
	return out, rows.Err()
}

// SetScore writes one mark. baseRevision 0 inserts. A stale revision returns the current score.
func (s *Store) SetScore(userID, assessmentID, studentID string, value *float64, baseRevision int) (Score, bool, error) {
	if value != nil && (*value < 0 || domainBad(*value)) {
		return Score{}, false, errStr("enter a mark of zero or more")
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	tx, err := s.db.Begin()
	if err != nil {
		return Score{}, false, err
	}
	defer tx.Rollback()
	var max float64
	err = tx.QueryRow(`SELECT max_marks FROM assessments WHERE id = ?`, assessmentID).Scan(&max)
	if errors.Is(err, sql.ErrNoRows) {
		return Score{}, false, ErrNotFound
	}
	if err != nil {
		return Score{}, false, err
	}
	if value != nil && *value > max {
		return Score{}, false, errStr("that mark is higher than the full mark")
	}
	var enrolled int
	if err := tx.QueryRow(`SELECT COUNT(*) FROM enrollments e JOIN assessments a ON a.class_subject_id = e.class_subject_id
		WHERE a.id = ? AND e.student_id = ?`, assessmentID, studentID).Scan(&enrolled); err != nil {
		return Score{}, false, err
	}
	if enrolled == 0 {
		return Score{}, false, errStr("this student does not take this subject")
	}
	current, err := s.findScore(tx, assessmentID, studentID)
	if err != nil && !errors.Is(err, ErrNotFound) {
		return Score{}, false, err
	}
	if err == nil && current.Revision != baseRevision {
		return current, true, nil
	}
	if errors.Is(err, ErrNotFound) && baseRevision != 0 {
		return Score{}, true, nil
	}
	now := Now()
	if current.ID == "" {
		current = Score{ID: NewID(), AssessmentID: assessmentID, StudentID: studentID, Score: value, Revision: 1, UpdatedAt: now}
		_, err = tx.Exec(`INSERT INTO scores (id, assessment_id, student_id, score, updated_at, updated_by, revision) VALUES (?,?,?,?,?,?,1)`,
			current.ID, assessmentID, studentID, nullFloat(value), now, userID)
	} else {
		_, err = tx.Exec(`INSERT INTO score_undo (user_id, score_id, prev_null, prev_score, created_at) VALUES (?,?,?,?,?)`,
			userID, current.ID, boolToNull(current.Score == nil), nullFloat(current.Score), now)
		if err != nil {
			return Score{}, false, err
		}
		current.Revision++
		current.Score = value
		current.UpdatedAt = now
		_, err = tx.Exec(`UPDATE scores SET score=?, updated_at=?, updated_by=?, revision=? WHERE id=?`,
			nullFloat(value), now, userID, current.Revision, current.ID)
	}
	if err != nil {
		return Score{}, false, err
	}
	if err := s.logChange(tx, "scores", current.ID, false, current); err != nil {
		return Score{}, false, err
	}
	return current, false, tx.Commit()
}

func boolToNull(v bool) int {
	if v {
		return 1
	}
	return 0
}

func nullFloat(v *float64) any {
	if v == nil {
		return nil
	}
	return *v
}

func (s *Store) findScore(q queryer, assessmentID, studentID string) (Score, error) {
	var sc Score
	var val sql.NullFloat64
	err := q.QueryRow(`SELECT id, assessment_id, student_id, score, revision, updated_at FROM scores WHERE assessment_id = ? AND student_id = ?`, assessmentID, studentID).
		Scan(&sc.ID, &sc.AssessmentID, &sc.StudentID, &val, &sc.Revision, &sc.UpdatedAt)
	if errors.Is(err, sql.ErrNoRows) {
		return Score{}, ErrNotFound
	}
	if val.Valid {
		v := val.Float64
		sc.Score = &v
	}
	return sc, err
}

func (s *Store) UndoScore(userID string) (Score, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	tx, err := s.db.Begin()
	if err != nil {
		return Score{}, err
	}
	defer tx.Rollback()
	var undoID int
	var scoreID string
	var prevNull int
	var prev sql.NullFloat64
	err = tx.QueryRow(`SELECT id, score_id, prev_null, prev_score FROM score_undo WHERE user_id = ? ORDER BY id DESC LIMIT 1`, userID).
		Scan(&undoID, &scoreID, &prevNull, &prev)
	if errors.Is(err, sql.ErrNoRows) {
		return Score{}, errStr("there is nothing to undo")
	}
	if err != nil {
		return Score{}, err
	}
	var value *float64
	if prevNull == 0 && prev.Valid {
		v := prev.Float64
		value = &v
	}
	now := Now()
	_, err = tx.Exec(`UPDATE scores SET score=?, updated_at=?, updated_by=?, revision=revision+1 WHERE id=?`, nullFloat(value), now, userID, scoreID)
	if err != nil {
		return Score{}, err
	}
	if _, err := tx.Exec(`DELETE FROM score_undo WHERE id = ?`, undoID); err != nil {
		return Score{}, err
	}
	var sc Score
	var val sql.NullFloat64
	err = tx.QueryRow(`SELECT id, assessment_id, student_id, score, revision, updated_at FROM scores WHERE id = ?`, scoreID).
		Scan(&sc.ID, &sc.AssessmentID, &sc.StudentID, &val, &sc.Revision, &sc.UpdatedAt)
	if err != nil {
		return Score{}, err
	}
	if val.Valid {
		v := val.Float64
		sc.Score = &v
	}
	if err := s.logChange(tx, "scores", sc.ID, false, sc); err != nil {
		return Score{}, err
	}
	return sc, tx.Commit()
}

func (s *Store) ClassResults(classID string, semester int) (ClassResults, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	class, err := s.classByID(s.db, classID)
	if err != nil {
		return ClassResults{}, err
	}
	settings := s.readSettings(s.db)
	subjects, err := s.subjectsFor(s.db, classID, semester)
	if err != nil {
		return ClassResults{}, err
	}
	students, err := s.studentsOf(s.db, classID)
	if err != nil {
		return ClassResults{}, err
	}
	out := ClassResults{Class: class, Semester: semester}
	var marks []domain.StudentMarks
	for _, st := range students {
		sr := StudentResult{Student: st}
		sm := domain.StudentMarks{ID: st.ID, Level: class.Level, Sex: st.Sex, Dropout: st.DroppedOut}
		for _, cs := range subjects {
			var enrolled int
			if err := s.db.QueryRow(`SELECT COUNT(*) FROM enrollments WHERE student_id = ? AND class_subject_id = ?`, st.ID, cs.ID).Scan(&enrolled); err != nil {
				return ClassResults{}, err
			}
			if enrolled == 0 {
				continue
			}
			items, err := s.itemsFor(s.db, cs.ID, st.ID)
			if err != nil {
				return ClassResults{}, err
			}
			res, err := domain.Summarize(cs.Weights, items)
			if err != nil {
				return ClassResults{}, err
			}
			sr.Subjects = append(sr.Subjects, SubjectColumn{ClassSubject: cs, Result: res})
			if !st.DroppedOut {
				sm.Totals = append(sm.Totals, res.Total)
			}
		}
		out.Students = append(out.Students, sr)
		marks = append(marks, sm)
	}
	standings := domain.Standings(marks, settings.FailLimits)
	for i := range out.Students {
		out.Students[i].Standing = standings[i]
	}
	return out, nil
}

func (s *Store) subjectsFor(q queryer, classID string, semester int) ([]ClassSubject, error) {
	rows, err := q.Query(`SELECT id FROM class_subjects WHERE class_id = ? AND semester = ?`, classID, semester)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var ids []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	rows.Close()
	var out []ClassSubject
	for _, id := range ids {
		cs, err := s.classSubjectByID(q, id)
		if err != nil {
			return nil, err
		}
		out = append(out, cs)
	}
	return out, nil
}

func (s *Store) studentsOf(q queryer, classID string) ([]Student, error) {
	rows, err := q.Query(`SELECT id FROM students WHERE class_id = ? ORDER BY full_name`, classID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var ids []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	rows.Close()
	var out []Student
	for _, id := range ids {
		st, err := s.studentByID(q, id)
		if err != nil {
			return nil, err
		}
		out = append(out, st)
	}
	return out, nil
}

func (s *Store) itemsFor(q queryer, classSubjectID, studentID string) ([]domain.Item, error) {
	rows, err := q.Query(`SELECT a.component, a.half, a.max_marks, sc.score
		FROM assessments a
		LEFT JOIN scores sc ON sc.assessment_id = a.id AND sc.student_id = ?
		WHERE a.class_subject_id = ?`, studentID, classSubjectID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var items []domain.Item
	for rows.Next() {
		var it domain.Item
		var comp string
		var val sql.NullFloat64
		if err := rows.Scan(&comp, &it.Half, &it.Max, &val); err != nil {
			return nil, err
		}
		it.Component = domain.Component(comp)
		if val.Valid {
			v := val.Float64
			it.Score = &v
		}
		items = append(items, it)
	}
	return items, rows.Err()
}

func (s *Store) Promotion(classID string, semester int) (PromotionStat, error) {
	results, err := s.ClassResults(classID, semester)
	if err != nil {
		return PromotionStat{}, err
	}
	// ClassResults locks. Headcount also locks. Call headcount math here without a second lock by reusing results.
	students := make([]Student, 0, len(results.Students))
	stat := PromotionStat{ClassID: results.Class.ID, ClassName: results.Class.Name, Level: results.Class.Level}
	for _, sr := range results.Students {
		students = append(students, sr.Student)
		if sr.Student.DroppedOut {
			continue
		}
		male := sr.Student.Sex == "M"
		switch sr.Standing.Status {
		case "promoted":
			stat.Promoted++
			if male {
				stat.PromotedM++
			} else {
				stat.PromotedF++
			}
		case "failed":
			stat.Failed++
			if male {
				stat.FailedM++
			} else {
				stat.FailedF++
			}
		}
	}
	stat.Head = countHeads(students)
	base := float64(stat.Head.Students)
	if base > 0 {
		stat.PromotedPct = domain.Round2(float64(stat.Promoted) / base * 100)
		stat.FailedPct = domain.Round2(float64(stat.Failed) / base * 100)
		stat.DropoutPct = domain.Round2(float64(stat.Head.Dropped) / base * 100)
	}
	return stat, nil
}
