package discover

import (
	"io"
	"log"

	"github.com/hashicorp/mdns"
)

// Announce tells other computers on the school network where SchoolDesk is.
func Announce(port int) (func(), error) {
	service, err := mdns.NewMDNSService("SchoolDesk", "_schooldesk._tcp", "", "", port, nil, []string{"ver=1"})
	if err != nil {
		return nil, err
	}
	srv, err := mdns.NewServer(&mdns.Config{Zone: service, Logger: log.New(io.Discard, "", 0)})
	if err != nil {
		return nil, err
	}
	return func() { _ = srv.Shutdown() }, nil
}
