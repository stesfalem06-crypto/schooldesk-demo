//go:build !linux && !windows && !darwin

package license

import (
	"os"
	"strings"
)

func Collect() (Parts, error) {
	midRaw, _ := os.ReadFile("/etc/machine-id")
	machineID := strings.TrimSpace(string(midRaw))
	if machineID == "" {
		machineID = "unknown"
	}
	return FillMissing("", "", "", machineID), nil
}
