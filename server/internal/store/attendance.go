package store

import (
	"database/sql"
	"errors"
	"strings"
	"time"
)

type Attendance struct {
	ID         string `json:"id"`
	ClassID    string `json:"class_id"`
	StudentID  string `json:"student_id"`
	RollNumber int    `json:"roll_number"`
	Day        string `json:"date"`
	Status     string `json:"status"`
	UpdatedAt  string `json:"updated_at"`
	SourceID   string `json:"source_id"`
	UpdatedBy  string `json:"updated_by"`
	Saved      bool   `json:"saved"`
}

// SaveAttendance keeps one row per student per date. A later updated_at wins.
// An older write is recorded in the audit list and does not replace the newer one.
func (s *Store) SaveAttendance(userID string, in Attendance) (Attendance, bool, error) {
	in.Status = strings.ToLower(strings.TrimSpace(in.Status))
	if in.Status != "present" && in.Status != "absent" {
		return Attendance{}, false, errors.New("mark present or absent")
	}
	if in.StudentID == "" || in.Day == "" {
		return Attendance{}, false, errors.New("choose the student and the date")
	}
	if _, err := time.Parse("2006-01-02", in.Day); err != nil {
		return Attendance{}, false, errors.New("use a date like 2026-11-23")
	}
	when := in.UpdatedAt
	if when == "" {
		when = Now()
	}
	if _, err := time.Parse(time.RFC3339, when); err != nil {
		return Attendance{}, false, errors.New("the time on this record is not understood")
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	tx, err := s.db.Begin()
	if err != nil {
		return Attendance{}, false, err
	}
	defer tx.Rollback()
	var existingID, existingAt string
	err = tx.QueryRow(`SELECT id, updated_at FROM student_attendance WHERE student_id = ? AND day = ?`, in.StudentID, in.Day).
		Scan(&existingID, &existingAt)
	if err != nil && !errors.Is(err, sql.ErrNoRows) {
		return Attendance{}, false, err
	}
	if existingID != "" && existingAt >= when {
		_ = s.logChange(tx, "attendance", existingID, false, map[string]any{
			"student_id": in.StudentID, "date": in.Day, "action": "kept", "source_id": in.SourceID,
			"note": "A newer attendance mark was already saved",
		})
		if err := tx.Commit(); err != nil {
			return Attendance{}, false, err
		}
		in.ID = existingID
		in.UpdatedAt = existingAt
		in.Saved = false
		return in, true, nil
	}
	if existingID == "" {
		in.ID = NewID()
		_, err = tx.Exec(`INSERT INTO student_attendance
			(id, class_id, student_id, roll_number, day, status, updated_at, source_id, updated_by)
			VALUES (?,?,?,?,?,?,?,?,?)`,
			in.ID, in.ClassID, in.StudentID, in.RollNumber, in.Day, in.Status, when, in.SourceID, userID)
	} else {
		in.ID = existingID
		_, err = tx.Exec(`UPDATE student_attendance SET class_id=?, roll_number=?, status=?, updated_at=?, source_id=?, updated_by=? WHERE id=?`,
			in.ClassID, in.RollNumber, in.Status, when, in.SourceID, userID, in.ID)
	}
	if err != nil {
		return Attendance{}, false, err
	}
	in.UpdatedAt = when
	in.UpdatedBy = userID
	in.Saved = true
	if err := s.logChange(tx, "attendance", in.ID, false, in); err != nil {
		return Attendance{}, false, err
	}
	return in, false, tx.Commit()
}

func (s *Store) AttendanceOn(classID, day string) ([]Attendance, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	rows, err := s.db.Query(`SELECT id, class_id, student_id, roll_number, day, status, updated_at, source_id, updated_by
		FROM student_attendance WHERE class_id = ? AND day = ? ORDER BY roll_number, student_id`, classID, day)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Attendance
	for rows.Next() {
		var a Attendance
		if err := rows.Scan(&a.ID, &a.ClassID, &a.StudentID, &a.RollNumber, &a.Day, &a.Status, &a.UpdatedAt, &a.SourceID, &a.UpdatedBy); err != nil {
			return nil, err
		}
		a.Saved = true
		out = append(out, a)
	}
	return out, rows.Err()
}
