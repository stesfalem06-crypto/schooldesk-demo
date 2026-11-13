//go:build linux

package license

import (
	"os"
	"path/filepath"
	"strings"
)

// Collect reads the Pi / Linux identity parts.
// H0 is /proc/cpuinfo Serial, H1 is /etc/machine-id, H2 is the root disk
// serial or, if that is missing, the root filesystem UUID.
func Collect() (Parts, error) {
	midRaw, _ := os.ReadFile("/etc/machine-id")
	machineID := strings.TrimSpace(string(midRaw))
	return FillMissing(cpuinfoSerial(), machineID, rootDisk(), machineID), nil
}

func cpuinfoSerial() string {
	b, err := os.ReadFile("/proc/cpuinfo")
	if err != nil {
		return ""
	}
	for _, line := range strings.Split(string(b), "\n") {
		lower := strings.ToLower(strings.TrimSpace(line))
		if !strings.HasPrefix(lower, "serial") {
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

func rootDisk() string {
	dev := mountSource("/")
	if dev == "" {
		return ""
	}
	if serial := blockSerial(dev); serial != "" {
		return serial
	}
	return deviceUUID(dev)
}

func mountSource(target string) string {
	b, err := os.ReadFile("/proc/mounts")
	if err != nil {
		return ""
	}
	for _, line := range strings.Split(string(b), "\n") {
		fields := strings.Fields(line)
		if len(fields) >= 2 && fields[1] == target {
			return fields[0]
		}
	}
	return ""
}

func blockSerial(dev string) string {
	base := filepath.Base(dev)
	disk := parentDisk(base)
	paths := []string{
		"/sys/block/" + disk + "/device/serial",
		"/sys/class/block/" + disk + "/device/serial",
		"/sys/block/" + disk + "/serial",
	}
	for _, p := range paths {
		b, err := os.ReadFile(p)
		if err != nil {
			continue
		}
		s := strings.TrimSpace(string(b))
		if s != "" && !zerosOnly(s) {
			return s
		}
	}
	return ""
}

func parentDisk(name string) string {
	switch {
	case strings.HasPrefix(name, "nvme"):
		if i := strings.LastIndex(name, "p"); i > 0 && digits(name[i+1:]) {
			return name[:i]
		}
	case strings.HasPrefix(name, "mmcblk"), strings.HasPrefix(name, "loop"):
		if i := strings.LastIndex(name, "p"); i > 0 && digits(name[i+1:]) {
			return name[:i]
		}
	default:
		i := len(name)
		for i > 0 && name[i-1] >= '0' && name[i-1] <= '9' {
			i--
		}
		if i > 0 && i < len(name) {
			return name[:i]
		}
	}
	return name
}

func digits(s string) bool {
	if s == "" {
		return false
	}
	for _, r := range s {
		if r < '0' || r > '9' {
			return false
		}
	}
	return true
}

func deviceUUID(dev string) string {
	entries, err := os.ReadDir("/dev/disk/by-uuid")
	if err != nil {
		return ""
	}
	want, err := filepath.EvalSymlinks(dev)
	if err != nil {
		want = dev
	}
	for _, e := range entries {
		link := filepath.Join("/dev/disk/by-uuid", e.Name())
		target, err := filepath.EvalSymlinks(link)
		if err != nil {
			continue
		}
		if target == want {
			return e.Name()
		}
	}
	return ""
}
