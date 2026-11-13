//go:build windows

package license

import (
	"os/exec"
	"strings"
)

// Collect reads Windows identity parts through PowerShell / WMI.
// H0 is the baseboard serial, H1 is the CPU ProcessorId, H2 is the first
// disk serial. A missing part becomes G:<MachineGuid>.
func Collect() (Parts, error) {
	guid := ps(`(Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Cryptography' -Name MachineGuid).MachineGuid`)
	if guid == "" {
		guid = machineGUIDReg()
	}
	board := ps(`(Get-CimInstance -ClassName Win32_BaseBoard).SerialNumber`)
	cpu := ps(`(Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1 -ExpandProperty ProcessorId)`)
	disk := ps(`(Get-CimInstance -ClassName Win32_DiskDrive | Select-Object -First 1 -ExpandProperty SerialNumber)`)
	return FillMissing(board, cpu, disk, guid), nil
}

func ps(expr string) string {
	cmd := exec.Command("powershell.exe", "-NoProfile", "-NonInteractive", "-Command", expr)
	out, err := cmd.Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}

func machineGUIDReg() string {
	cmd := exec.Command("reg", "query", `HKLM\SOFTWARE\Microsoft\Cryptography`, "/v", "MachineGuid")
	out, err := cmd.Output()
	if err != nil {
		return ""
	}
	for _, line := range strings.Split(string(out), "\n") {
		if strings.Contains(line, "MachineGuid") {
			fields := strings.Fields(line)
			if len(fields) > 0 {
				return fields[len(fields)-1]
			}
		}
	}
	return ""
}
