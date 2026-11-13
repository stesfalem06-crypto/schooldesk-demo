package license

import (
	"crypto/ed25519"
	"encoding/binary"
	"errors"
	"time"
	"unicode/utf8"
)

const (
	Scheme       = "SCH1"
	codeVersion  = 1
	maxNameBytes = 60
	machineBytes = 10
	sigBytes     = 64
	headerBytes  = 8
)

// epoch is day zero for issue and expiry dates.
var epoch = time.Date(2024, 1, 1, 0, 0, 0, 0, time.UTC)

var (
	errLayout    = errors.New("this code is not a valid school code")
	errSignature = errors.New("this code does not match this school computer")
	errIntegrity = errors.New("licence check failed")
)

// Claims are the fields carried in a verified code.
type Claims struct {
	SchoolName string
	IssueDay   int
	ExpiryDay  int // 0 means the code never ends
	MaxDevices int // 0 means unlimited devices
}

// NeverExpires reports whether expiry day is 0.
func (c Claims) NeverExpires() bool { return c.ExpiryDay == 0 }

// UnlimitedDevices reports whether max devices is 0.
func (c Claims) UnlimitedDevices() bool { return c.MaxDevices == 0 }

// IssueDate is the UTC calendar day the code was issued.
func (c Claims) IssueDate() time.Time {
	return DateFromDay(c.IssueDay)
}

// ExpiryDate returns the last valid UTC day. The second result is false when
// the code never ends.
func (c Claims) ExpiryDate() (time.Time, bool) {
	if c.ExpiryDay == 0 {
		return time.Time{}, false
	}
	return DateFromDay(c.ExpiryDay), true
}

// ValidAt reports whether now falls inside the issued window.
// The expiry day itself is still valid. The next day is not.
func (c Claims) ValidAt(now time.Time) error {
	today := DayNumber(now)
	if today < c.IssueDay {
		return errors.New("this code is not valid yet")
	}
	if c.ExpiryDay != 0 && today > c.ExpiryDay {
		return errors.New("this code has ended")
	}
	return nil
}

// DayNumber counts UTC midnights since 2024-01-01.
func DayNumber(t time.Time) int {
	t = t.UTC()
	d := time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC)
	return int(d.Sub(epoch) / (24 * time.Hour))
}

// DateFromDay converts a day count back to a UTC date.
func DateFromDay(day int) time.Time {
	return epoch.AddDate(0, 0, day)
}

// VerifyCode checks a code against the embedded production key and machine id.
func VerifyCode(machineDisplay, code string) (Claims, error) {
	pub, err := publicKey()
	if err != nil {
		return Claims{}, err
	}
	return verifyWithKey(machineDisplay, code, pub)
}

func verifyWithKey(machineDisplay, code string, pub ed25519.PublicKey) (Claims, error) {
	if len(pub) != ed25519.PublicKeySize {
		return Claims{}, errIntegrity
	}
	rawMid, err := decodeStrict(Clean(machineDisplay))
	if err != nil || len(rawMid) != machineBytes {
		return Claims{}, errLayout
	}
	blob, err := decodeStrict(Clean(code))
	if err != nil {
		return Claims{}, errLayout
	}
	claims, body, sig, err := splitBody(blob)
	if err != nil {
		return Claims{}, err
	}
	msg := make([]byte, 0, 4+machineBytes+len(body))
	msg = append(msg, 'S', 'C', 'H', '1')
	msg = append(msg, rawMid...)
	msg = append(msg, body...)
	if !ed25519.Verify(pub, msg, sig) {
		return Claims{}, errSignature
	}
	return claims, nil
}

func splitBody(blob []byte) (Claims, []byte, []byte, error) {
	if len(blob) < headerBytes+sigBytes {
		return Claims{}, nil, nil, errLayout
	}
	if blob[0] != codeVersion {
		return Claims{}, nil, nil, errLayout
	}
	nameLen := int(blob[7])
	if nameLen > maxNameBytes {
		return Claims{}, nil, nil, errLayout
	}
	total := headerBytes + nameLen + sigBytes
	if len(blob) != total {
		return Claims{}, nil, nil, errLayout
	}
	name := blob[8 : 8+nameLen]
	if !utf8.Valid(name) {
		return Claims{}, nil, nil, errLayout
	}
	claims := Claims{
		SchoolName: string(name),
		IssueDay:   int(binary.BigEndian.Uint16(blob[1:3])),
		ExpiryDay:  int(binary.BigEndian.Uint16(blob[3:5])),
		MaxDevices: int(binary.BigEndian.Uint16(blob[5:7])),
	}
	body := blob[:headerBytes+nameLen]
	sig := blob[headerBytes+nameLen:]
	if len(sig) != sigBytes {
		return Claims{}, nil, nil, errLayout
	}
	return claims, body, sig, nil
}
