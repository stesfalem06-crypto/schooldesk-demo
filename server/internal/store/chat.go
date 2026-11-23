package store

import (
	"errors"
	"strings"
)

const StaffRoom = "staff"

type Message struct {
	ID        string `json:"id"`
	FromUser  string `json:"from_user"`
	FromName  string `json:"from_name"`
	ToUser    string `json:"to_user"`
	Body      string `json:"body"`
	CreatedAt string `json:"created_at"`
}

func (s *Store) AddMessage(fromID, toID, body string) (Message, error) {
	body = strings.TrimSpace(body)
	if body == "" {
		return Message{}, errors.New("type a message")
	}
	if len([]rune(body)) > 2000 {
		return Message{}, errors.New("that message is too long")
	}
	if toID != StaffRoom {
		if _, err := s.UserByID(toID); err != nil {
			return Message{}, errors.New("choose a person")
		}
	}
	from, err := s.UserByID(fromID)
	if err != nil {
		return Message{}, err
	}
	msg := Message{
		ID: NewID(), FromUser: fromID, FromName: from.DisplayName, ToUser: toID,
		Body: body, CreatedAt: Now(),
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	_, err = s.db.Exec(`INSERT INTO messages (id, from_user, to_user, body, created_at) VALUES (?,?,?,?,?)`,
		msg.ID, msg.FromUser, msg.ToUser, msg.Body, msg.CreatedAt)
	return msg, err
}

func (s *Store) Messages(userID, with string, limit int) ([]Message, error) {
	if limit <= 0 || limit > 200 {
		limit = 100
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	var (
		rows interface {
			Close() error
			Next() bool
			Scan(...any) error
			Err() error
		}
		err error
	)
	q := `SELECT m.id, m.from_user, COALESCE(u.display_name, ''), m.to_user, m.body, m.created_at
		FROM messages m LEFT JOIN users u ON u.id = m.from_user `
	if with == StaffRoom {
		rows, err = s.db.Query(q+`WHERE m.to_user = ? ORDER BY m.created_at DESC LIMIT ?`, StaffRoom, limit)
	} else {
		rows, err = s.db.Query(q+`WHERE (m.from_user = ? AND m.to_user = ?) OR (m.from_user = ? AND m.to_user = ?)
			ORDER BY m.created_at DESC LIMIT ?`, userID, with, with, userID, limit)
	}
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Message
	for rows.Next() {
		var m Message
		if err := rows.Scan(&m.ID, &m.FromUser, &m.FromName, &m.ToUser, &m.Body, &m.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, m)
	}
	// Oldest first, so the screen reads top to bottom.
	for i, j := 0, len(out)-1; i < j; i, j = i+1, j-1 {
		out[i], out[j] = out[j], out[i]
	}
	return out, rows.Err()
}
