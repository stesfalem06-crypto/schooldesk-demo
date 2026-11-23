package discover

import (
	"fmt"
	"net"
	"strconv"
	"strings"
	"time"
)

const BeaconPort = 8742

// ServeUDP answers "where is the school computer?" on the school network.
// A phone can also hear the regular beacon. No internet is used.
func ServeUDP(httpPort int) (func(), error) {
	conn, err := net.ListenUDP("udp4", &net.UDPAddr{IP: net.IPv4zero, Port: BeaconPort})
	if err != nil {
		return nil, err
	}
	stop := make(chan struct{})
	go func() {
		buf := make([]byte, 512)
		for {
			_ = conn.SetReadDeadline(time.Now().Add(2 * time.Second))
			n, addr, err := conn.ReadFromUDP(buf)
			select {
			case <-stop:
				return
			default:
			}
			if err != nil || n == 0 || addr == nil {
				continue
			}
			text := strings.TrimSpace(string(buf[:n]))
			if text == "SHAMM?" || strings.HasPrefix(text, "SHAMM?") {
				_, _ = conn.WriteToUDP([]byte(fmt.Sprintf("SHAMM/1 %d", httpPort)), addr)
			}
		}
	}()
	go func() {
		tick := time.NewTicker(3 * time.Second)
		defer tick.Stop()
		msg := []byte(fmt.Sprintf("SHAMM/1 %d", httpPort))
		bcast := &net.UDPAddr{IP: net.IPv4bcast, Port: BeaconPort}
		for {
			select {
			case <-stop:
				return
			case <-tick.C:
				_, _ = conn.WriteToUDP(msg, bcast)
			}
		}
	}()
	return func() {
		close(stop)
		_ = conn.Close()
	}, nil
}

// ParseBeacon reads "SHAMM/1 8741" and returns the HTTP port.
func ParseBeacon(text string) (int, bool) {
	fields := strings.Fields(strings.TrimSpace(text))
	if len(fields) < 2 || fields[0] != "SHAMM/1" {
		return 0, false
	}
	n, err := strconv.Atoi(fields[1])
	if err != nil || n < 1 || n > 65535 {
		return 0, false
	}
	return n, true
}
