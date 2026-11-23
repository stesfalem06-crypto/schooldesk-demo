//go:build windows

package winsvc

import (
	"fmt"
	"time"

	"golang.org/x/sys/windows/svc"
	"golang.org/x/sys/windows/svc/mgr"
)

const name = "ShammSchool"

func Running() bool {
	in, err := svc.IsWindowsService()
	return err == nil && in
}

func Install(exe, data string) error {
	m, err := mgr.Connect()
	if err != nil {
		return err
	}
	defer m.Disconnect()
	if s, err := m.OpenService(name); err == nil {
		s.Close()
		return fmt.Errorf("the school service is already installed")
	}
	s, err := m.CreateService(name, exe, mgr.Config{
		DisplayName:      "Shamm School Management Systems",
		StartType:        mgr.StartAutomatic,
		ServiceStartName: "",
		Description:      "School server for this computer. It does not use the internet.",
	}, "--data", data, "--addr", ":8741")
	if err != nil {
		return err
	}
	defer s.Close()
	_ = s.SetRecoveryActions([]mgr.RecoveryAction{{Type: mgr.ServiceRestart, Delay: 3 * time.Second}}, 0)
	return s.Start()
}

type handler struct {
	start func(stop <-chan struct{})
}

func (h handler) Execute(_ []string, requests <-chan svc.ChangeRequest, changes chan<- svc.Status) (bool, uint32) {
	changes <- svc.Status{State: svc.StartPending}
	stop := make(chan struct{})
	done := make(chan struct{})
	go func() {
		h.start(stop)
		close(done)
	}()
	changes <- svc.Status{State: svc.Running, Accepts: svc.AcceptStop | svc.AcceptShutdown}
	for {
		select {
		case <-done:
			return false, 0
		case req := <-requests:
			switch req.Cmd {
			case svc.Interrogate:
				changes <- req.CurrentStatus
			case svc.Stop, svc.Shutdown:
				changes <- svc.Status{State: svc.StopPending}
				close(stop)
				<-done
				return false, 0
			}
		}
	}
}

func Run(start func(stop <-chan struct{})) error {
	return svc.Run(name, handler{start: start})
}
