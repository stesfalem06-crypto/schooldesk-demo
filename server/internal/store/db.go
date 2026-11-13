package store

import (
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"strings"
	"sync"
	"time"

	_ "modernc.org/sqlite"
)

type Store struct {
	mu   sync.Mutex
	db   *sql.DB
	path string
}

func Open(path string) (*Store, error) {
	db, err := openDB(path)
	if err != nil {
		return nil, err
	}
	s := &Store{db: db, path: path}
	if err := s.migrate(); err != nil {
		db.Close()
		return nil, err
	}
	return s, nil
}

func openDB(path string) (*sql.DB, error) {
	dsn := "file:" + path + "?_pragma=busy_timeout(5000)&_pragma=journal_mode(WAL)&_pragma=foreign_keys(ON)"
	db, err := sql.Open("sqlite", dsn)
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(1)
	return db, nil
}

func (s *Store) Close() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.db.Close()
}

func (s *Store) Path() string { return s.path }

func (s *Store) migrate() error {
	_, err := s.db.Exec(schema)
	return err
}

func NewID() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

func Now() string { return time.Now().UTC().Format(time.RFC3339) }

func (s *Store) logChange(tx *sql.Tx, entity, id string, deleted bool, payload any) error {
	raw, err := json.Marshal(payload)
	if err != nil {
		return err
	}
	del := 0
	if deleted {
		del = 1
	}
	_, err = tx.Exec(`INSERT INTO changes (entity, entity_id, deleted, payload, updated_at) VALUES (?,?,?,?,?)`,
		entity, id, del, string(raw), Now())
	return err
}

type queryer interface {
	Query(string, ...any) (*sql.Rows, error)
	QueryRow(string, ...any) *sql.Row
	Exec(string, ...any) (sql.Result, error)
}

func (s *Store) setting(tx queryer, key, fallback string) string {
	var v string
	err := tx.QueryRow(`SELECT value FROM settings WHERE key = ?`, key).Scan(&v)
	if err != nil {
		return fallback
	}
	return v
}

func (s *Store) putSetting(tx queryer, key, value string) error {
	_, err := tx.Exec(`INSERT INTO settings (key, value) VALUES (?, ?)
		ON CONFLICT(key) DO UPDATE SET value = excluded.value`, key, value)
	return err
}

var ErrNotFound = errors.New("that record was not found")
var ErrConflict = errors.New("the school record is newer than this one")

func isEmpty(s string) bool { return strings.TrimSpace(s) == "" }

func requireText(s, label string, max int) error {
	s = strings.TrimSpace(s)
	if s == "" {
		return fmt.Errorf("enter %s", label)
	}
	if len([]rune(s)) > max {
		return fmt.Errorf("%s is too long", label)
	}
	return nil
}

const schema = `
CREATE TABLE IF NOT EXISTS settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  username TEXT NOT NULL COLLATE NOCASE UNIQUE,
  password_hash TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('teacher','admin','director')),
  staff_id TEXT NOT NULL DEFAULT '',
  display_name TEXT NOT NULL,
  active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  revision INTEGER NOT NULL DEFAULT 1
);
CREATE TABLE IF NOT EXISTS sessions (
  token_hash TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  created_at TEXT NOT NULL,
  expires_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS staff (
  id TEXT PRIMARY KEY,
  full_name TEXT NOT NULL,
  sex TEXT NOT NULL CHECK (sex IN ('M','F')),
  village TEXT NOT NULL DEFAULT '',
  id_number TEXT NOT NULL DEFAULT '',
  employee_id TEXT NOT NULL DEFAULT '',
  phone TEXT NOT NULL DEFAULT '',
  date_of_birth TEXT NOT NULL DEFAULT '',
  residence TEXT NOT NULL DEFAULT '',
  graduation_field TEXT NOT NULL DEFAULT '',
  qualification TEXT NOT NULL DEFAULT '' CHECK (qualification IN ('','12+certificate','diploma','degree','masters')),
  staff_type TEXT NOT NULL CHECK (staff_type IN ('teaching','non-teaching')),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  revision INTEGER NOT NULL DEFAULT 1
);
CREATE TABLE IF NOT EXISTS classes (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  level TEXT NOT NULL CHECK (level IN ('elementary','junior','high')),
  grade INTEGER NOT NULL DEFAULT 0,
  academic_year TEXT NOT NULL,
  homeroom_staff_id TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  revision INTEGER NOT NULL DEFAULT 1
);
CREATE TABLE IF NOT EXISTS subjects (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  code TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  revision INTEGER NOT NULL DEFAULT 1
);
CREATE TABLE IF NOT EXISTS class_subjects (
  id TEXT PRIMARY KEY,
  class_id TEXT NOT NULL,
  subject_id TEXT NOT NULL,
  teacher_staff_id TEXT NOT NULL DEFAULT '',
  periods_per_week INTEGER NOT NULL DEFAULT 1,
  semester INTEGER NOT NULL,
  w_classwork REAL NOT NULL,
  w_quizzes REAL NOT NULL,
  w_tests REAL NOT NULL,
  w_assignments REAL NOT NULL,
  w_participation REAL NOT NULL,
  w_homework REAL NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  revision INTEGER NOT NULL DEFAULT 1,
  UNIQUE (class_id, subject_id, semester)
);
CREATE TABLE IF NOT EXISTS students (
  id TEXT PRIMARY KEY,
  full_name TEXT NOT NULL,
  sex TEXT NOT NULL CHECK (sex IN ('M','F')),
  mother_name TEXT NOT NULL DEFAULT '',
  class_id TEXT NOT NULL DEFAULT '',
  dropped_out INTEGER NOT NULL DEFAULT 0,
  dropout_reason TEXT NOT NULL DEFAULT '',
  dropout_date TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  revision INTEGER NOT NULL DEFAULT 1
);
CREATE TABLE IF NOT EXISTS custom_fields (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS student_fields (
  student_id TEXT NOT NULL,
  field_id TEXT NOT NULL,
  value TEXT NOT NULL DEFAULT '',
  updated_at TEXT NOT NULL,
  revision INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY (student_id, field_id)
);
CREATE TABLE IF NOT EXISTS enrollments (
  student_id TEXT NOT NULL,
  class_subject_id TEXT NOT NULL,
  PRIMARY KEY (student_id, class_subject_id)
);
CREATE TABLE IF NOT EXISTS assessments (
  id TEXT PRIMARY KEY,
  class_subject_id TEXT NOT NULL,
  component TEXT NOT NULL CHECK (component IN ('classwork','quizzes','tests','assignments','participation','homework','exam')),
  half INTEGER NOT NULL DEFAULT 1,
  title TEXT NOT NULL,
  max_marks REAL NOT NULL,
  assessment_date TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  revision INTEGER NOT NULL DEFAULT 1
);
CREATE TABLE IF NOT EXISTS scores (
  id TEXT PRIMARY KEY,
  assessment_id TEXT NOT NULL,
  student_id TEXT NOT NULL,
  score REAL,
  updated_at TEXT NOT NULL,
  updated_by TEXT NOT NULL DEFAULT '',
  revision INTEGER NOT NULL DEFAULT 1,
  UNIQUE (assessment_id, student_id)
);
CREATE TABLE IF NOT EXISTS score_undo (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL,
  score_id TEXT NOT NULL,
  prev_null INTEGER NOT NULL,
  prev_score REAL,
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS fee_payments (
  id TEXT PRIMARY KEY,
  student_id TEXT NOT NULL,
  academic_year TEXT NOT NULL,
  amount REAL NOT NULL,
  paid_on TEXT NOT NULL,
  recorded_by TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  revision INTEGER NOT NULL DEFAULT 1
);
CREATE TABLE IF NOT EXISTS incomes (
  id TEXT PRIMARY KEY,
  amount REAL NOT NULL,
  source TEXT NOT NULL,
  received_on TEXT NOT NULL,
  note TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  revision INTEGER NOT NULL DEFAULT 1
);
CREATE TABLE IF NOT EXISTS expenses (
  id TEXT PRIMARY KEY,
  amount REAL NOT NULL,
  reason TEXT NOT NULL,
  spent_on TEXT NOT NULL,
  receipt_number TEXT NOT NULL,
  cheque_number TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  revision INTEGER NOT NULL DEFAULT 1
);
CREATE TABLE IF NOT EXISTS workshop_expenses (
  id TEXT PRIMARY KEY,
  amount REAL NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  attended_on TEXT NOT NULL DEFAULT '',
  days INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  revision INTEGER NOT NULL DEFAULT 1
);
CREATE TABLE IF NOT EXISTS sports_expenses (
  id TEXT PRIMARY KEY,
  amount REAL NOT NULL,
  reason TEXT NOT NULL,
  spent_on TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  revision INTEGER NOT NULL DEFAULT 1
);
CREATE TABLE IF NOT EXISTS absences (
  id TEXT PRIMARY KEY,
  staff_id TEXT NOT NULL,
  absent_on TEXT NOT NULL,
  note TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  revision INTEGER NOT NULL DEFAULT 1,
  UNIQUE (staff_id, absent_on)
);
CREATE TABLE IF NOT EXISTS makeups (
  id TEXT PRIMARY KEY,
  staff_id TEXT NOT NULL,
  held_on TEXT NOT NULL,
  periods INTEGER NOT NULL,
  note TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  revision INTEGER NOT NULL DEFAULT 1
);
CREATE TABLE IF NOT EXISTS weekly_periods (
  staff_id TEXT NOT NULL,
  weekday INTEGER NOT NULL,
  periods INTEGER NOT NULL,
  PRIMARY KEY (staff_id, weekday)
);
CREATE TABLE IF NOT EXISTS meetings (
  id TEXT PRIMARY KEY,
  meeting_date TEXT NOT NULL,
  title TEXT NOT NULL,
  attendees TEXT NOT NULL,
  notes TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  revision INTEGER NOT NULL DEFAULT 1
);
CREATE TABLE IF NOT EXISTS bell (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  days INTEGER NOT NULL,
  periods_per_day INTEGER NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS teacher_blocks (
  staff_id TEXT NOT NULL,
  day_index INTEGER NOT NULL,
  period_index INTEGER NOT NULL,
  PRIMARY KEY (staff_id, day_index, period_index)
);
CREATE TABLE IF NOT EXISTS timetable_slots (
  id TEXT PRIMARY KEY,
  class_id TEXT NOT NULL,
  day_index INTEGER NOT NULL,
  period_index INTEGER NOT NULL,
  class_subject_id TEXT NOT NULL DEFAULT '',
  teacher_staff_id TEXT NOT NULL DEFAULT '',
  updated_at TEXT NOT NULL,
  UNIQUE (class_id, day_index, period_index)
);
CREATE TABLE IF NOT EXISTS devices (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL DEFAULT '',
  platform TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL,
  last_seen_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS changes (
  seq INTEGER PRIMARY KEY AUTOINCREMENT,
  entity TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  deleted INTEGER NOT NULL DEFAULT 0,
  payload TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS semester_reports (
  id TEXT PRIMARY KEY,
  academic_year TEXT NOT NULL,
  semester INTEGER NOT NULL,
  class_id TEXT NOT NULL DEFAULT '',
  title TEXT NOT NULL,
  generated_at TEXT NOT NULL,
  pdf BLOB NOT NULL
);
CREATE TABLE IF NOT EXISTS audit (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  at TEXT NOT NULL,
  user_id TEXT NOT NULL DEFAULT '',
  action TEXT NOT NULL,
  detail TEXT NOT NULL DEFAULT ''
);
CREATE INDEX IF NOT EXISTS idx_students_class ON students(class_id);
CREATE INDEX IF NOT EXISTS idx_scores_assessment ON scores(assessment_id);
CREATE INDEX IF NOT EXISTS idx_changes_seq ON changes(seq);
`

// RemoveWAL deletes sqlite sidecars after the database is closed.
func RemoveWAL(path string) {
	os.Remove(path + "-wal")
	os.Remove(path + "-shm")
}
