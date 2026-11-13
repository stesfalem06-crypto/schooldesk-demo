package main

import (
	"flag"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"strconv"
	"syscall"
	"time"

	"schooldesk/internal/discover"
	"schooldesk/internal/httpapi"
	"schooldesk/internal/license"
	"schooldesk/internal/store"
)

func main() {
	data := flag.String("data", "data", "folder for the school records")
	addr := flag.String("addr", ":8741", "address to listen on")
	noMDNS := flag.Bool("no-mdns", false, "do not announce the server on the school network")
	flag.Parse()

	if err := os.MkdirAll(*data, 0o700); err != nil {
		log.Fatal(err)
	}
	dbPath := filepath.Join(*data, "school.db")
	st, err := store.Open(dbPath)
	if err != nil {
		log.Fatal(err)
	}
	defer st.Close()

	n, err := st.CountUsers()
	if err != nil {
		log.Fatal(err)
	}
	if n == 0 {
		if err := loadSample(st); err != nil {
			log.Fatal(err)
		}
		note := filepath.Join(*data, "FIRST_LOGIN.txt")
		_ = os.WriteFile(note, []byte(firstLogin), 0o600)
		log.Print("Sample school is ready. Sign-in names are in FIRST_LOGIN.txt")
	}

	parts, err := license.Collect()
	if err != nil {
		log.Fatal(err)
	}
	gate := openGate(filepath.Join(*data, "licence.dat"), parts)
	if err := license.PublicKeyCheck(); err != nil {
		log.Fatal(err)
	}
	api := &httpapi.API{Store: st, Gate: gate}
	api.MaybeAutoSemester()

	port := portOf(*addr)
	var stop func()
	if !*noMDNS && port > 0 {
		stop, err = discover.Announce(port)
		if err != nil {
			log.Print("The school network name could not be announced. Computers can still use the address.")
		}
	}
	go nightly(api)
	go func() {
		ticker := time.NewTicker(6 * time.Hour)
		defer ticker.Stop()
		for range ticker.C {
			api.MaybeAutoSemester()
		}
	}()

	server := &http.Server{Addr: *addr, Handler: api.Handler(), ReadHeaderTimeout: 10 * time.Second}
	go func() {
		log.Printf("SchoolDesk is on %s", *addr)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatal(err)
		}
	}()
	ch := make(chan os.Signal, 1)
	signal.Notify(ch, syscall.SIGINT, syscall.SIGTERM)
	<-ch
	if stop != nil {
		stop()
	}
	_ = server.Close()
}

func nightly(api *httpapi.API) {
	for {
		now := time.Now()
		next := time.Date(now.Year(), now.Month(), now.Day(), 2, 0, 0, 0, now.Location())
		if !next.After(now) {
			next = next.Add(24 * time.Hour)
		}
		timer := time.NewTimer(time.Until(next))
		<-timer.C
		if _, err := api.BackupNow(); err != nil {
			log.Print("Night backup did not finish")
		}
	}
}

func portOf(addr string) int {
	_, port, err := net.SplitHostPort(addr)
	if err != nil {
		return 8741
	}
	n, err := strconv.Atoi(port)
	if err != nil {
		return 0
	}
	return n
}

type fileGate struct {
	path  string
	parts license.Parts
}

func (g fileGate) Current(now time.Time) (license.Status, error) {
	return license.Current(g.path, g.parts, now)
}

func (g fileGate) Activate(code string, now time.Time) (license.Status, error) {
	return license.Activate(g.path, g.parts, code, now)
}

const firstLogin = `SchoolDesk sample sign-in

admin      admin1850
director   director1850
hanna      hanna1850
samuel     samuel1850
meron      meron1850
dawit      dawit1850

Change these after the school is set up.
`
