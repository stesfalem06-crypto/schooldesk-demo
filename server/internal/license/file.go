package license

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"encoding/binary"
	"encoding/json"
	"errors"
	"os"
	"time"
)

const fileMagic = "SCH1LIC1"

var (
	errFile      = errors.New("the saved school code could not be read on this computer")
	errClock     = errors.New("the school computer's clock was set backwards. Set the correct date, then open this again")
	errNotOpened = errors.New("this school is not unlocked yet")
)

// Status is what the lock screen and the apps need.
type Status struct {
	Licensed     bool
	SchoolName   string
	MachineID    string
	QRPayload    string
	Expires      *time.Time
	MaxDevices   int
	NeverEnds    bool
	Unlimited    bool
	Expired      bool
	ClockProblem bool
	Message      string
}

type sealedPayload struct {
	School     string `json:"school"`
	IssueDay   int    `json:"issue_day"`
	ExpiryDay  int    `json:"expiry_day"`
	MaxDevices int    `json:"max_devices"`
	MachineID  string `json:"machine_id"`
	LastSeen   int64  `json:"last_seen"`
}

// Activate checks a code for these hardware parts and saves the licence file.
func Activate(path string, parts Parts, code string, now time.Time) (Status, error) {
	_, display := MachineID(parts)
	claims, err := VerifyCode(display, code)
	if err != nil {
		return lockedStatus(display, err.Error()), err
	}
	if err := claims.ValidAt(now); err != nil {
		st := lockedStatus(display, err.Error())
		if claims.ExpiryDay != 0 && DayNumber(now) > claims.ExpiryDay {
			st.Expired = true
			st.SchoolName = claims.SchoolName
		}
		return st, err
	}
	if err := Seal(path, parts, claims, now); err != nil {
		return lockedStatus(display, err.Error()), err
	}
	return statusFrom(display, claims, false), nil
}

// Current reads the saved licence. A missing file is a lock, not a failure.
func Current(path string, parts Parts, now time.Time) (Status, error) {
	_, display := MachineID(parts)
	if _, err := os.Stat(path); err != nil {
		if os.IsNotExist(err) {
			return lockedStatus(display, "This school is locked"), nil
		}
		return lockedStatus(display, errFile.Error()), err
	}
	claims, lastSeen, err := Open(path, parts, now)
	if err != nil {
		st := lockedStatus(display, err.Error())
		if errors.Is(err, errClock) {
			st.ClockProblem = true
		}
		return st, nil
	}
	if err := claims.ValidAt(now); err != nil {
		st := lockedStatus(display, err.Error())
		st.SchoolName = claims.SchoolName
		st.Expired = claims.ExpiryDay != 0 && DayNumber(now) > claims.ExpiryDay
		return st, nil
	}
	st := statusFrom(display, claims, false)
	st.Message = ""
	_ = lastSeen
	return st, nil
}

func lockedStatus(display, msg string) Status {
	return Status{
		Licensed:  false,
		MachineID: display,
		QRPayload: QRPayload(display),
		Message:   msg,
	}
}

func statusFrom(display string, claims Claims, expired bool) Status {
	st := Status{
		Licensed:   !expired,
		SchoolName: claims.SchoolName,
		MachineID:  display,
		QRPayload:  QRPayload(display),
		MaxDevices: claims.MaxDevices,
		NeverEnds:  claims.NeverExpires(),
		Unlimited:  claims.UnlimitedDevices(),
		Expired:    expired,
	}
	if exp, ok := claims.ExpiryDate(); ok {
		st.Expires = &exp
	}
	return st
}

// Seal writes an AES-256-GCM licence file. The data key is wrapped under
// every pair of hardware parts so any two original parts can open it.
func Seal(path string, parts Parts, claims Claims, now time.Time) error {
	_, display := MachineID(parts)
	payload := sealedPayload{
		School:     claims.SchoolName,
		IssueDay:   claims.IssueDay,
		ExpiryDay:  claims.ExpiryDay,
		MaxDevices: claims.MaxDevices,
		MachineID:  display,
		LastSeen:   now.UTC().Unix(),
	}
	return writeSealed(path, [3]string{parts.Board, parts.CPU, parts.Disk}, payload)
}

// Open decrypts a licence file with any two matching hardware parts.
// When an expiry is set, a clock moved backwards is rejected.
// On success the last-seen time is stored again.
func Open(path string, parts Parts, now time.Time) (Claims, int64, error) {
	blob, err := os.ReadFile(path)
	if err != nil {
		return Claims{}, 0, errNotOpened
	}
	payload, err := readSealed(blob, [3]string{parts.Board, parts.CPU, parts.Disk})
	if err != nil {
		return Claims{}, 0, err
	}
	claims := Claims{
		SchoolName: payload.School,
		IssueDay:   payload.IssueDay,
		ExpiryDay:  payload.ExpiryDay,
		MaxDevices: payload.MaxDevices,
	}
	nowUnix := now.UTC().Unix()
	if claims.ExpiryDay != 0 && nowUnix+120 < payload.LastSeen {
		return claims, payload.LastSeen, errClock
	}
	if nowUnix > payload.LastSeen+600 {
		payload.LastSeen = nowUnix
		if err := writeSealed(path, [3]string{parts.Board, parts.CPU, parts.Disk}, payload); err != nil {
			return claims, payload.LastSeen, err
		}
	}
	return claims, payload.LastSeen, nil
}

func writeSealed(path string, hw [3]string, payload sealedPayload) error {
	plain, err := json.Marshal(payload)
	if err != nil {
		return err
	}
	dataKey := make([]byte, 32)
	salt := make([]byte, 16)
	nonce := make([]byte, 12)
	if _, err := rand.Read(dataKey); err != nil {
		return err
	}
	if _, err := rand.Read(salt); err != nil {
		return err
	}
	if _, err := rand.Read(nonce); err != nil {
		return err
	}
	ct, err := gcmSeal(dataKey, nonce, plain, []byte(fileMagic))
	if err != nil {
		return err
	}
	pairs := [3][2]int{{0, 1}, {0, 2}, {1, 2}}
	type wrap struct {
		id byte
		ct []byte
		n  []byte
	}
	wraps := make([]wrap, 0, 3)
	for i, pair := range pairs {
		wn := make([]byte, 12)
		if _, err := rand.Read(wn); err != nil {
			return err
		}
		wk := wrapKey(hw[pair[0]], hw[pair[1]], salt)
		wct, err := gcmSeal(wk, wn, dataKey, []byte{byte(i)})
		if err != nil {
			return err
		}
		wraps = append(wraps, wrap{id: byte(i), ct: wct, n: wn})
	}
	buf := make([]byte, 0, 8+1+16+12+4+len(ct)+1+3*(1+12+len(wraps[0].ct)))
	buf = append(buf, []byte(fileMagic)...)
	buf = append(buf, 1)
	buf = append(buf, salt...)
	buf = append(buf, nonce...)
	lenb := make([]byte, 4)
	binary.BigEndian.PutUint32(lenb, uint32(len(ct)))
	buf = append(buf, lenb...)
	buf = append(buf, ct...)
	buf = append(buf, byte(len(wraps)))
	for _, w := range wraps {
		buf = append(buf, w.id)
		buf = append(buf, w.n...)
		wlen := make([]byte, 2)
		binary.BigEndian.PutUint16(wlen, uint16(len(w.ct)))
		buf = append(buf, wlen...)
		buf = append(buf, w.ct...)
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, buf, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

func readSealed(blob []byte, hw [3]string) (sealedPayload, error) {
	if len(blob) < 8+1+16+12+4+1 || string(blob[:8]) != fileMagic || blob[8] != 1 {
		return sealedPayload{}, errFile
	}
	salt := blob[9:25]
	nonce := blob[25:37]
	n := int(binary.BigEndian.Uint32(blob[37:41]))
	if n < 16 || 41+n > len(blob) {
		return sealedPayload{}, errFile
	}
	ct := blob[41 : 41+n]
	rest := blob[41+n:]
	if len(rest) < 1 {
		return sealedPayload{}, errFile
	}
	count := int(rest[0])
	rest = rest[1:]
	if count < 1 || count > 6 {
		return sealedPayload{}, errFile
	}
	var dataKey []byte
	for i := 0; i < count; i++ {
		if len(rest) < 1+12+2 {
			return sealedPayload{}, errFile
		}
		id := rest[0]
		wn := rest[1:13]
		wlen := int(binary.BigEndian.Uint16(rest[13:15]))
		rest = rest[15:]
		if wlen < 16 || len(rest) < wlen {
			return sealedPayload{}, errFile
		}
		wct := rest[:wlen]
		rest = rest[wlen:]
		if int(id) > 2 {
			continue
		}
		pair := [3][2]int{{0, 1}, {0, 2}, {1, 2}}[id]
		wk := wrapKey(hw[pair[0]], hw[pair[1]], salt)
		key, err := gcmOpen(wk, wn, wct, []byte{id})
		if err != nil || len(key) != 32 {
			continue
		}
		dataKey = key
		break
	}
	if dataKey == nil {
		return sealedPayload{}, errFile
	}
	plain, err := gcmOpen(dataKey, nonce, ct, []byte(fileMagic))
	if err != nil {
		return sealedPayload{}, errFile
	}
	var payload sealedPayload
	if err := json.Unmarshal(plain, &payload); err != nil {
		return sealedPayload{}, errFile
	}
	return payload, nil
}

func wrapKey(a, b string, salt []byte) []byte {
	h := sha256.New()
	h.Write([]byte("SCH1-WRAP-v1|"))
	h.Write([]byte(a))
	h.Write([]byte("|"))
	h.Write([]byte(b))
	h.Write([]byte("|"))
	h.Write(salt)
	return h.Sum(nil)
}

func gcmSeal(key, nonce, plain, aad []byte) ([]byte, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	g, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}
	if len(nonce) != g.NonceSize() {
		return nil, errFile
	}
	return g.Seal(nil, nonce, plain, aad), nil
}

func gcmOpen(key, nonce, ct, aad []byte) ([]byte, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	g, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}
	if len(nonce) != g.NonceSize() {
		return nil, err
	}
	return g.Open(nil, nonce, ct, aad)
}
