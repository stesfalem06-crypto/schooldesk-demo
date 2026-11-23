//go:build !windows

package winsvc

import "errors"

func Running() bool { return false }

func Install(exe, data string) error {
	return errors.New("the Windows service install is only for a Windows school computer")
}

func Run(start func(stop <-chan struct{})) error {
	return errors.New("this is not a Windows service")
}
