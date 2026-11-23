//go:build darwin

package license

import (
	"context"
	"os/exec"
	"strings"
	"time"
)

// Collect reads the Mac identity parts.
// H0 is the hardware serial, H1 is the platform UUID, H2 is the boot disk UUID.
// A missing part becomes G:<platform UUID>.
func Collect() (Parts, error) {
	platform := ioregField("IOPlatformUUID")
	serial := ioregField("IOPlatformSerialNumber")
	return FillMissing(serial, platform, diskUUID(), platform), nil
}

func ioregField(key string) string {
	out, err := runLimited(3*time.Second, "ioreg", "-rd1", "-c", "IOPlatformExpertDevice")
	if err != nil {
		return ""
	}
	needle := `"` + key + `"`
	for _, line := range strings.Split(string(out), "\n") {
		if !strings.Contains(line, needle) {
			continue
		}
		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			return ""
		}
		return strings.Trim(strings.TrimSpace(parts[1]), `"`)
	}
	return ""
}

func diskUUID() string {
	out, err := runLimited(3*time.Second, "diskutil", "info", "disk0")
	if err != nil {
		return ""
	}
	for _, line := range strings.Split(string(out), "\n") {
		if !strings.Contains(line, "Disk / Partition UUID") && !strings.Contains(line, "Volume UUID") {
			continue
		}
		parts := strings.SplitN(line, ":", 2)
		if len(parts) != 2 {
			return ""
		}
		return strings.TrimSpace(parts[1])
	}
	return ""
}

func runLimited(limit time.Duration, name string, args ...string) ([]byte, error) {
	ctx, cancel := context.WithTimeout(context.Background(), limit)
	defer cancel()
	return exec.CommandContext(ctx, name, args...).Output()
}
