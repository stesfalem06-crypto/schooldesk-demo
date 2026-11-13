package store

import (
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"errors"
	"strings"
	"time"
)

func (s *Store) CountUsers() (int, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	var n int
	err := s.db.QueryRow(`SELECT COUNT(*) FROM users`).Scan(&n)
	return n, err
}

func (s *Store) CreateUser(username, passwordHash, role, staffID, displayName string) (User, error) {
	if err := requireText(username, "a username", 40); err != nil {
		return User{}, err
	}
	if err := requireText(displayName, "a name", 80); err != nil {
		return User{}, err
	}
	if role != "teacher" && role != "admin" && role != "director" {
		return User{}, errors.New("choose teacher, admin, or director")
	}
	id := NewID()
	now := Now()
	s.mu.Lock()
	defer s.mu.Unlock()
	tx, err := s.db.Begin()
	if err != nil {
		return User{}, err
	}
	defer tx.Rollback()
	_, err = tx.Exec(`INSERT INTO users (id, username, password_hash, role, staff_id, display_name, active, created_at, updated_at)
		VALUES (?,?,?,?,?,?,1,?,?)`, id, strings.TrimSpace(username), passwordHash, role, staffID, strings.TrimSpace(displayName), now, now)
	if err != nil {
		if strings.Contains(strings.ToLower(err.Error()), "unique") {
			return User{}, errors.New("that username is already used")
		}
		return User{}, err
	}
	u := User{ID: id, Username: strings.TrimSpace(username), Role: role, StaffID: staffID, DisplayName: strings.TrimSpace(displayName), Active: true}
	if err := s.logChange(tx, "users", id, false, u); err != nil {
		return User{}, err
	}
	return u, tx.Commit()
}

func (s *Store) UserByUsername(username string) (User, string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	var u User
	var hash string
	var active int
	err := s.db.QueryRow(`SELECT id, username, password_hash, role, staff_id, display_name, active FROM users WHERE username = ?`, strings.TrimSpace(username)).
		Scan(&u.ID, &u.Username, &hash, &u.Role, &u.StaffID, &u.DisplayName, &active)
	if errors.Is(err, sql.ErrNoRows) {
		return User{}, "", ErrNotFound
	}
	if err != nil {
		return User{}, "", err
	}
	u.Active = active == 1
	s.fillAccess(&u)
	return u, hash, nil
}

func (s *Store) UserByID(id string) (User, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.userByID(s.db, id)
}

func (s *Store) userByID(q queryer, id string) (User, error) {
	var u User
	var active int
	err := q.QueryRow(`SELECT id, username, role, staff_id, display_name, active FROM users WHERE id = ?`, id).
		Scan(&u.ID, &u.Username, &u.Role, &u.StaffID, &u.DisplayName, &active)
	if errors.Is(err, sql.ErrNoRows) {
		return User{}, ErrNotFound
	}
	if err != nil {
		return User{}, err
	}
	u.Active = active == 1
	s.fillAccessQ(q, &u)
	return u, nil
}

func (s *Store) fillAccess(u *User) { s.fillAccessQ(s.db, u) }

func (s *Store) fillAccessQ(q queryer, u *User) {
	u.HomeroomClassIDs = nil
	u.TeachingIDs = nil
	if u.StaffID == "" {
		return
	}
	rows, err := q.Query(`SELECT id FROM classes WHERE homeroom_staff_id = ? ORDER BY name`, u.StaffID)
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var id string
			if rows.Scan(&id) == nil {
				u.HomeroomClassIDs = append(u.HomeroomClassIDs, id)
			}
		}
	}
	rows2, err := q.Query(`SELECT id FROM class_subjects WHERE teacher_staff_id = ?`, u.StaffID)
	if err == nil {
		defer rows2.Close()
		for rows2.Next() {
			var id string
			if rows2.Scan(&id) == nil {
				u.TeachingIDs = append(u.TeachingIDs, id)
			}
		}
	}
}

func (s *Store) ListUsers() ([]User, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	rows, err := s.db.Query(`SELECT id FROM users ORDER BY display_name`)
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
	out := make([]User, 0, len(ids))
	for _, id := range ids {
		u, err := s.userByID(s.db, id)
		if err != nil {
			return nil, err
		}
		out = append(out, u)
	}
	return out, nil
}

func (s *Store) ChangePassword(userID, passwordHash string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	_, err := s.db.Exec(`UPDATE users SET password_hash = ?, updated_at = ?, revision = revision + 1 WHERE id = ?`, passwordHash, Now(), userID)
	return err
}

func tokenHash(token string) string {
	sum := sha256.Sum256([]byte(token))
	return hex.EncodeToString(sum[:])
}

func (s *Store) CreateSession(userID, token string, ttl time.Duration) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	now := time.Now().UTC()
	_, err := s.db.Exec(`INSERT INTO sessions (token_hash, user_id, created_at, expires_at) VALUES (?,?,?,?)`,
		tokenHash(token), userID, now.Format(time.RFC3339), now.Add(ttl).Format(time.RFC3339))
	return err
}

func (s *Store) UserByToken(token string) (User, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	var userID, exp string
	err := s.db.QueryRow(`SELECT user_id, expires_at FROM sessions WHERE token_hash = ?`, tokenHash(token)).Scan(&userID, &exp)
	if errors.Is(err, sql.ErrNoRows) {
		return User{}, ErrNotFound
	}
	if err != nil {
		return User{}, err
	}
	until, err := time.Parse(time.RFC3339, exp)
	if err != nil || time.Now().UTC().After(until) {
		_, _ = s.db.Exec(`DELETE FROM sessions WHERE token_hash = ?`, tokenHash(token))
		return User{}, ErrNotFound
	}
	return s.userByID(s.db, userID)
}

func (s *Store) DeleteSession(token string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	_, err := s.db.Exec(`DELETE FROM sessions WHERE token_hash = ?`, tokenHash(token))
	return err
}

func (s *Store) Audit(userID, action, detail string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	_, _ = s.db.Exec(`INSERT INTO audit (at, user_id, action, detail) VALUES (?,?,?,?)`, Now(), userID, action, detail)
}
