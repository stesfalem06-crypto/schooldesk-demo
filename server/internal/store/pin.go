package store

import "strings"

func (s *Store) SetPIN(userID, pinHash string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	res, err := s.db.Exec(`UPDATE users SET pin_hash = ?, updated_at = ?, revision = revision + 1 WHERE id = ?`, pinHash, Now(), userID)
	if err != nil {
		return err
	}
	n, _ := res.RowsAffected()
	if n == 0 {
		return ErrNotFound
	}
	return nil
}

func (s *Store) PINHash(userID string) (string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	var hash string
	err := s.db.QueryRow(`SELECT pin_hash FROM users WHERE id = ? AND active = 1`, userID).Scan(&hash)
	if err != nil {
		return "", ErrNotFound
	}
	return hash, nil
}

type Person struct {
	ID          string `json:"id"`
	DisplayName string `json:"display_name"`
	Role        string `json:"role"`
}

func (s *Store) ListPeople() ([]Person, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	rows, err := s.db.Query(`SELECT id, display_name, role FROM users WHERE active = 1 ORDER BY display_name COLLATE NOCASE`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Person
	for rows.Next() {
		var p Person
		if err := rows.Scan(&p.ID, &p.DisplayName, &p.Role); err != nil {
			return nil, err
		}
		p.DisplayName = strings.TrimSpace(p.DisplayName)
		out = append(out, p)
	}
	return out, rows.Err()
}
