package license

import (
	"crypto/sha256"
	"strings"
)

// Parts are the three hardware values that form a machine id.
// Empty values must already have been replaced with the G: fallback.
type Parts struct {
	Board string
	CPU   string
	Disk  string
}

// FillMissing replaces blank parts with G:<fallback>.
func FillMissing(board, cpu, disk, fallback string) Parts {
	fb := "G:" + strings.TrimSpace(fallback)
	return Parts{
		Board: orFallback(board, fb),
		CPU:   orFallback(cpu, fb),
		Disk:  orFallback(disk, fb),
	}
}

func orFallback(v, fb string) string {
	v = strings.TrimSpace(v)
	if v == "" || zerosOnly(v) {
		return fb
	}
	return v
}

func zerosOnly(v string) bool {
	if v == "" {
		return false
	}
	for _, r := range v {
		if r != '0' && r != ' ' {
			return false
		}
	}
	return true
}

// Canonical string hashed for the machine id.
func (p Parts) identity() string {
	return "SCH-MID|H0:" + p.Board + "|H1:" + p.CPU + "|H2:" + p.Disk
}

// MachineID returns the raw 10-byte id and the dashed display form.
func MachineID(p Parts) (raw []byte, display string) {
	sum := sha256.Sum256([]byte(p.identity()))
	raw = append([]byte(nil), sum[:machineBytes]...)
	display = FormatMachineID(raw)
	return raw, display
}

// QRPayload is what a phone should scan on the lock screen.
func QRPayload(display string) string {
	return Scheme + ":" + display
}
