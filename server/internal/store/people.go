package store

import (
	"database/sql"
	"errors"
)

func (s *Store) SaveStaff(in Staff) (Staff, error) {
	if err := requireText(in.FullName, "the full name", 120); err != nil {
		return Staff{}, err
	}
	if !validSex(in.Sex) {
		return Staff{}, errStr("choose male or female")
	}
	if in.StaffType != "teaching" && in.StaffType != "non-teaching" {
		return Staff{}, errStr("choose teaching or non-teaching")
	}
	if !validQual(in.Qualification) {
		return Staff{}, errStr("choose a qualification")
	}
	if in.DateOfBirth != "" && !validDate(in.DateOfBirth) {
		return Staff{}, errStr("the date of birth is not valid")
	}
	in.FullName = clean(in.FullName)
	now := Now()
	s.mu.Lock()
	defer s.mu.Unlock()
	tx, err := s.db.Begin()
	if err != nil {
		return Staff{}, err
	}
	defer tx.Rollback()
	if in.ID == "" {
		in.ID = NewID()
		_, err = tx.Exec(`INSERT INTO staff (id, full_name, sex, village, id_number, employee_id, phone, date_of_birth, residence, graduation_field, qualification, staff_type, created_at, updated_at)
			VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
			in.ID, in.FullName, in.Sex, clean(in.Village), clean(in.IDNumber), clean(in.EmployeeID), clean(in.Phone), in.DateOfBirth, clean(in.Residence), clean(in.GraduationField), in.Qualification, in.StaffType, now, now)
	} else {
		res, err2 := tx.Exec(`UPDATE staff SET full_name=?, sex=?, village=?, id_number=?, employee_id=?, phone=?, date_of_birth=?, residence=?, graduation_field=?, qualification=?, staff_type=?, updated_at=?, revision=revision+1 WHERE id=?`,
			in.FullName, in.Sex, clean(in.Village), clean(in.IDNumber), clean(in.EmployeeID), clean(in.Phone), in.DateOfBirth, clean(in.Residence), clean(in.GraduationField), in.Qualification, in.StaffType, now, in.ID)
		if err2 != nil {
			return Staff{}, err2
		}
		n, _ := res.RowsAffected()
		if n == 0 {
			return Staff{}, ErrNotFound
		}
		err = nil
	}
	if err != nil {
		return Staff{}, err
	}
	if err := s.logChange(tx, "staff", in.ID, false, in); err != nil {
		return Staff{}, err
	}
	return in, tx.Commit()
}

func (s *Store) ListStaff() ([]Staff, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	rows, err := s.db.Query(`SELECT id, full_name, sex, village, id_number, employee_id, phone, date_of_birth, residence, graduation_field, qualification, staff_type FROM staff ORDER BY full_name`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Staff
	for rows.Next() {
		var st Staff
		if err := rows.Scan(&st.ID, &st.FullName, &st.Sex, &st.Village, &st.IDNumber, &st.EmployeeID, &st.Phone, &st.DateOfBirth, &st.Residence, &st.GraduationField, &st.Qualification, &st.StaffType); err != nil {
			return nil, err
		}
		out = append(out, st)
	}
	return out, rows.Err()
}

func (s *Store) StaffStats() (StaffStats, error) {
	list, err := s.ListStaff()
	if err != nil {
		return StaffStats{}, err
	}
	var st StaffStats
	qual := map[string]*QualCount{}
	for _, p := range list {
		male := p.Sex == "M"
		if p.StaffType == "teaching" {
			if male {
				st.TeachingMale++
			} else {
				st.TeachingFemale++
			}
		} else if male {
			st.NonTeachingMale++
		} else {
			st.NonTeachingFemale++
		}
		q := p.Qualification
		if q == "" {
			q = "not set"
		}
		row := qual[q]
		if row == nil {
			row = &QualCount{Qualification: q}
			qual[q] = row
		}
		if male {
			row.Male++
		} else {
			row.Female++
		}
	}
	order := []string{"12+certificate", "diploma", "degree", "masters", "not set"}
	for _, name := range order {
		if row := qual[name]; row != nil {
			st.ByQualification = append(st.ByQualification, *row)
		}
	}
	return st, nil
}

func (s *Store) SaveClass(in Class) (Class, error) {
	if err := requireText(in.Name, "the class name", 40); err != nil {
		return Class{}, err
	}
	if !validLevel(in.Level) {
		return Class{}, errStr("choose elementary, junior, or high school")
	}
	if err := requireText(in.AcademicYear, "the school year", 20); err != nil {
		return Class{}, err
	}
	in.Name = clean(in.Name)
	now := Now()
	s.mu.Lock()
	defer s.mu.Unlock()
	tx, err := s.db.Begin()
	if err != nil {
		return Class{}, err
	}
	defer tx.Rollback()
	if in.ID == "" {
		in.ID = NewID()
		_, err = tx.Exec(`INSERT INTO classes (id, name, level, grade, academic_year, homeroom_staff_id, created_at, updated_at) VALUES (?,?,?,?,?,?,?,?)`,
			in.ID, in.Name, in.Level, in.Grade, clean(in.AcademicYear), in.HomeroomStaffID, now, now)
	} else {
		res, err2 := tx.Exec(`UPDATE classes SET name=?, level=?, grade=?, academic_year=?, homeroom_staff_id=?, updated_at=?, revision=revision+1 WHERE id=?`,
			in.Name, in.Level, in.Grade, clean(in.AcademicYear), in.HomeroomStaffID, now, in.ID)
		if err2 != nil {
			return Class{}, err2
		}
		n, _ := res.RowsAffected()
		if n == 0 {
			return Class{}, ErrNotFound
		}
	}
	if err != nil {
		return Class{}, err
	}
	if err := s.logChange(tx, "classes", in.ID, false, in); err != nil {
		return Class{}, err
	}
	return in, tx.Commit()
}

func (s *Store) ListClasses() ([]Class, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	rows, err := s.db.Query(`SELECT c.id, c.name, c.level, c.grade, c.academic_year, c.homeroom_staff_id, COALESCE(st.full_name,'')
		FROM classes c LEFT JOIN staff st ON st.id = c.homeroom_staff_id ORDER BY c.grade, c.name`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Class
	for rows.Next() {
		var c Class
		if err := rows.Scan(&c.ID, &c.Name, &c.Level, &c.Grade, &c.AcademicYear, &c.HomeroomStaffID, &c.HomeroomName); err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

func (s *Store) Class(id string) (Class, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.classByID(s.db, id)
}

func (s *Store) classByID(q queryer, id string) (Class, error) {
	var c Class
	err := q.QueryRow(`SELECT c.id, c.name, c.level, c.grade, c.academic_year, c.homeroom_staff_id, COALESCE(st.full_name,'')
		FROM classes c LEFT JOIN staff st ON st.id = c.homeroom_staff_id WHERE c.id = ?`, id).
		Scan(&c.ID, &c.Name, &c.Level, &c.Grade, &c.AcademicYear, &c.HomeroomStaffID, &c.HomeroomName)
	if errors.Is(err, sql.ErrNoRows) {
		return Class{}, ErrNotFound
	}
	return c, err
}

func (s *Store) SaveSubject(in Subject) (Subject, error) {
	if err := requireText(in.Name, "the subject name", 60); err != nil {
		return Subject{}, err
	}
	in.Name = clean(in.Name)
	now := Now()
	s.mu.Lock()
	defer s.mu.Unlock()
	tx, err := s.db.Begin()
	if err != nil {
		return Subject{}, err
	}
	defer tx.Rollback()
	if in.ID == "" {
		in.ID = NewID()
		_, err = tx.Exec(`INSERT INTO subjects (id, name, code, created_at, updated_at) VALUES (?,?,?,?,?)`, in.ID, in.Name, clean(in.Code), now, now)
	} else {
		res, err2 := tx.Exec(`UPDATE subjects SET name=?, code=?, updated_at=?, revision=revision+1 WHERE id=?`, in.Name, clean(in.Code), now, in.ID)
		if err2 != nil {
			return Subject{}, err2
		}
		n, _ := res.RowsAffected()
		if n == 0 {
			return Subject{}, ErrNotFound
		}
	}
	if err != nil {
		return Subject{}, err
	}
	if err := s.logChange(tx, "subjects", in.ID, false, in); err != nil {
		return Subject{}, err
	}
	return in, tx.Commit()
}

func (s *Store) ListSubjects() ([]Subject, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	rows, err := s.db.Query(`SELECT id, name, code FROM subjects ORDER BY name`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Subject
	for rows.Next() {
		var sub Subject
		if err := rows.Scan(&sub.ID, &sub.Name, &sub.Code); err != nil {
			return nil, err
		}
		out = append(out, sub)
	}
	return out, rows.Err()
}

func (s *Store) AddCustomField(name string) (CustomField, error) {
	if err := requireText(name, "a field name", 40); err != nil {
		return CustomField{}, err
	}
	f := CustomField{ID: NewID(), Name: clean(name)}
	now := Now()
	s.mu.Lock()
	defer s.mu.Unlock()
	var n int
	_ = s.db.QueryRow(`SELECT COUNT(*) FROM custom_fields`).Scan(&n)
	f.SortOrder = n
	_, err := s.db.Exec(`INSERT INTO custom_fields (id, name, sort_order, created_at, updated_at) VALUES (?,?,?,?,?)`, f.ID, f.Name, f.SortOrder, now, now)
	return f, err
}

func (s *Store) ListCustomFields() ([]CustomField, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.listFields(s.db)
}

func (s *Store) listFields(q queryer) ([]CustomField, error) {
	rows, err := q.Query(`SELECT id, name, sort_order FROM custom_fields ORDER BY sort_order, name`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []CustomField
	for rows.Next() {
		var f CustomField
		if err := rows.Scan(&f.ID, &f.Name, &f.SortOrder); err != nil {
			return nil, err
		}
		out = append(out, f)
	}
	return out, rows.Err()
}

func (s *Store) SaveStudent(in Student) (Student, error) {
	if err := requireText(in.FullName, "the student's full name", 120); err != nil {
		return Student{}, err
	}
	if !validSex(in.Sex) {
		return Student{}, errStr("choose male or female")
	}
	if in.ClassID == "" {
		return Student{}, errStr("choose a class")
	}
	in.FullName = clean(in.FullName)
	in.MotherName = clean(in.MotherName)
	now := Now()
	s.mu.Lock()
	defer s.mu.Unlock()
	tx, err := s.db.Begin()
	if err != nil {
		return Student{}, err
	}
	defer tx.Rollback()
	if _, err := s.classByID(tx, in.ClassID); err != nil {
		return Student{}, err
	}
	if in.ID == "" {
		in.ID = NewID()
		_, err = tx.Exec(`INSERT INTO students (id, full_name, sex, mother_name, class_id, dropped_out, dropout_reason, dropout_date, created_at, updated_at)
			VALUES (?,?,?,?,?,0,'','',?,?)`, in.ID, in.FullName, in.Sex, in.MotherName, in.ClassID, now, now)
		if err != nil {
			return Student{}, err
		}
		if err := s.enrollAll(tx, in.ID, in.ClassID); err != nil {
			return Student{}, err
		}
	} else {
		res, err2 := tx.Exec(`UPDATE students SET full_name=?, sex=?, mother_name=?, class_id=?, updated_at=?, revision=revision+1 WHERE id=?`,
			in.FullName, in.Sex, in.MotherName, in.ClassID, now, in.ID)
		if err2 != nil {
			return Student{}, err2
		}
		n, _ := res.RowsAffected()
		if n == 0 {
			return Student{}, ErrNotFound
		}
	}
	if err := s.saveFields(tx, in.ID, in.Fields); err != nil {
		return Student{}, err
	}
	got, err := s.studentByID(tx, in.ID)
	if err != nil {
		return Student{}, err
	}
	if err := s.logChange(tx, "students", in.ID, false, got); err != nil {
		return Student{}, err
	}
	return got, tx.Commit()
}

func (s *Store) enrollAll(tx *sql.Tx, studentID, classID string) error {
	rows, err := tx.Query(`SELECT id FROM class_subjects WHERE class_id = ?`, classID)
	if err != nil {
		return err
	}
	defer rows.Close()
	var ids []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return err
		}
		ids = append(ids, id)
	}
	rows.Close()
	for _, id := range ids {
		if _, err := tx.Exec(`INSERT OR IGNORE INTO enrollments (student_id, class_subject_id) VALUES (?,?)`, studentID, id); err != nil {
			return err
		}
	}
	return nil
}

func (s *Store) saveFields(tx *sql.Tx, studentID string, fields map[string]string) error {
	for id, value := range fields {
		value = clean(value)
		if len([]rune(value)) > 120 {
			return errStr("a custom answer is too long")
		}
		_, err := tx.Exec(`INSERT INTO student_fields (student_id, field_id, value, updated_at, revision) VALUES (?,?,?,?,1)
			ON CONFLICT(student_id, field_id) DO UPDATE SET value=excluded.value, updated_at=excluded.updated_at, revision=revision+1`,
			studentID, id, value, Now())
		if err != nil {
			return err
		}
	}
	return nil
}

func (s *Store) SetDropout(id string, dropped bool, reason, date string) (Student, error) {
	if dropped && date != "" && !validDate(date) {
		return Student{}, errStr("the date is not valid")
	}
	if !dropped {
		reason, date = "", ""
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	tx, err := s.db.Begin()
	if err != nil {
		return Student{}, err
	}
	defer tx.Rollback()
	flag := 0
	if dropped {
		flag = 1
	}
	res, err := tx.Exec(`UPDATE students SET dropped_out=?, dropout_reason=?, dropout_date=?, updated_at=?, revision=revision+1 WHERE id=?`,
		flag, clean(reason), date, Now(), id)
	if err != nil {
		return Student{}, err
	}
	n, _ := res.RowsAffected()
	if n == 0 {
		return Student{}, ErrNotFound
	}
	got, err := s.studentByID(tx, id)
	if err != nil {
		return Student{}, err
	}
	if err := s.logChange(tx, "students", id, false, got); err != nil {
		return Student{}, err
	}
	return got, tx.Commit()
}

func (s *Store) ListStudents(classID string) ([]Student, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	q := `SELECT id FROM students`
	var args []any
	if classID != "" {
		q += ` WHERE class_id = ?`
		args = append(args, classID)
	}
	q += ` ORDER BY full_name`
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
	out := make([]Student, 0, len(ids))
	for _, id := range ids {
		st, err := s.studentByID(s.db, id)
		if err != nil {
			return nil, err
		}
		out = append(out, st)
	}
	return out, nil
}

func (s *Store) studentByID(q queryer, id string) (Student, error) {
	var st Student
	var dropped int
	err := q.QueryRow(`SELECT id, full_name, sex, mother_name, class_id, dropped_out, dropout_reason, dropout_date FROM students WHERE id = ?`, id).
		Scan(&st.ID, &st.FullName, &st.Sex, &st.MotherName, &st.ClassID, &dropped, &st.DropoutReason, &st.DropoutDate)
	if errors.Is(err, sql.ErrNoRows) {
		return Student{}, ErrNotFound
	}
	if err != nil {
		return Student{}, err
	}
	st.DroppedOut = dropped == 1
	st.Fields = map[string]string{}
	rows, err := q.Query(`SELECT field_id, value FROM student_fields WHERE student_id = ?`, id)
	if err != nil {
		return Student{}, err
	}
	defer rows.Close()
	for rows.Next() {
		var fid, val string
		if err := rows.Scan(&fid, &val); err != nil {
			return Student{}, err
		}
		st.Fields[fid] = val
	}
	return st, rows.Err()
}

func (s *Store) Headcount(classID string) (Headcount, error) {
	students, err := s.ListStudents(classID)
	if err != nil {
		return Headcount{}, err
	}
	return countHeads(students), nil
}

func countHeads(students []Student) Headcount {
	var h Headcount
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

func (s *Store) DropoutReasons(classID string) ([]ReasonCount, error) {
	students, err := s.ListStudents(classID)
	if err != nil {
		return nil, err
	}
	order := []string{}
	by := map[string]*ReasonCount{}
	for _, st := range students {
		if !st.DroppedOut {
			continue
		}
		reason := st.DropoutReason
		if reason == "" {
			reason = "No reason given"
		}
		row := by[reason]
		if row == nil {
			row = &ReasonCount{Reason: reason}
			by[reason] = row
			order = append(order, reason)
		}
		row.Total++
		if st.Sex == "M" {
			row.Male++
		} else {
			row.Female++
		}
	}
	out := make([]ReasonCount, 0, len(order))
	for _, reason := range order {
		out = append(out, *by[reason])
	}
	return out, nil
}

func (s *Store) Teaches(staffID, classSubjectID string) (bool, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	var n int
	err := s.db.QueryRow(`SELECT COUNT(*) FROM class_subjects WHERE id = ? AND teacher_staff_id = ?`, classSubjectID, staffID).Scan(&n)
	return n > 0, err
}

func (s *Store) HomeroomOf(staffID, classID string) (bool, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	var n int
	err := s.db.QueryRow(`SELECT COUNT(*) FROM classes WHERE id = ? AND homeroom_staff_id = ?`, classID, staffID).Scan(&n)
	return n > 0, err
}
