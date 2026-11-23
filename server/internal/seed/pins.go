package seed

import (
	"schooldesk/internal/auth"
	"schooldesk/internal/store"
)

// SamplePINs are the 4-digit numbers for the sample school.
// The admin can change them after the real school is set up.
var SamplePINs = map[string]string{
	"admin":    "1850",
	"director": "1851",
	"hanna":    "1852",
	"samuel":   "1853",
	"meron":    "1854",
	"dawit":    "1855",
}

func SetSamplePINs(s *store.Store) error {
	for username, pin := range SamplePINs {
		user, _, err := s.UserByUsername(username)
		if err != nil {
			continue
		}
		hash, err := auth.HashPIN(pin)
		if err != nil {
			return err
		}
		if err := s.SetPIN(user.ID, hash); err != nil {
			return err
		}
	}
	return nil
}
