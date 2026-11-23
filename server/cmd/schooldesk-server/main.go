package main

import (
	"crypto/ed25519"
	"encoding/base64"
	"errors"
	"flag"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"

	"schooldesk/internal/brand"
	"schooldesk/internal/discover"
	"schooldesk/internal/httpapi"
	"schooldesk/internal/license"
	"schooldesk/internal/store"
	"schooldesk/internal/update"
	"schooldesk/internal/winsvc"
)

func main() {
	if len(os.Args) > 1 && os.Args[1] == "--install-service" {
		dataDir := filepath.Join(os.Getenv("ProgramData"), "ShammSchool")
		for i := 2; i < len(os.Args)-1; i++ {
			if os.Args[i] == "--data" {
				dataDir = os.Args[i+1]
			}
		}
		exe, err := os.Executable()
		if err != nil {
			log.Fatal(err)
		}
		if err := winsvc.Install(exe, dataDir); err != nil {
			log.Fatal(err)
		}
		log.Print("The school service is installed")
		return
	}
	if winsvc.Running() {
		if err := winsvc.Run(func(stop <-chan struct{}) { serve(stop) }); err != nil {
			log.Fatal(err)
		}
		return
	}
	serve(nil)
}

func serve(serviceStop <-chan struct{}) {
	flags := flag.NewFlagSet(os.Args[0], flag.ExitOnError)
	data := flags.String("data", "data", "folder for the school records")
	addr := flags.String("addr", ":8741", "address to listen on")
	noMDNS := flags.Bool("no-mdns", false, "do not announce the server on the school network")
	_ = flags.Parse(os.Args[1:])

	if err := os.MkdirAll(*data, 0o700); err != nil {
		log.Fatal(err)
	}
	dbPath := filepath.Join(*data, "school.db")
	st, err := store.Open(dbPath)
	if err != nil {
		log.Fatal(err)
	}
	defer st.Close()

	parts, err := license.Collect()
	if err != nil {
		log.Fatal(err)
	}
	gate := openGate(filepath.Join(*data, "licence.dat"), parts)
	if err := license.PublicKeyCheck(); err != nil {
		log.Fatal(err)
	}
	exe, _ := os.Executable()
	api := &httpapi.API{Store: st, Gate: gate, DataDir: *data, Binary: exe, OnRestart: func() {
		log.Print("Restarting after an update")
		os.Exit(0)
	}}
	go prepareSchool(st, api, *data)

	port := portOf(*addr)
	var stopAnnounce func()
	if !*noMDNS && port > 0 {
		stopAnnounce, err = discover.Announce(port)
		if err != nil {
			log.Print("The school network name could not be announced. Computers can still use the address.")
		}
		stopUDP, udpErr := discover.ServeUDP(port)
		if udpErr != nil {
			log.Print("The school address beacon could not start. Computers can still use the address.")
		} else {
			defer stopUDP()
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
	go update.Watch(update.DefaultDisks(), func(path string) error {
		body, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		key, err := apiUpdateKey(*data)
		if err != nil {
			log.Print(err)
			return err
		}
		_, err = update.Apply(body, update.ApplyConfig{PublicKey: key, DataDir: *data, BinaryPath: exe})
		if err != nil {
			log.Print(err)
			return err
		}
		log.Print("Update from a plugged-in disk is ready. Restarting.")
		os.Exit(0)
		return nil
	}, func() <-chan struct{} {
		if serviceStop != nil {
			return serviceStop
		}
		return make(chan struct{})
	}())

	server := &http.Server{Addr: *addr, Handler: api.Handler(), ReadHeaderTimeout: 10 * time.Second}
	go func() {
		log.Printf("%s is on %s", brand.Product, *addr)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatal(err)
		}
	}()
	ch := make(chan os.Signal, 1)
	signal.Notify(ch, syscall.SIGINT, syscall.SIGTERM)
	select {
	case <-ch:
	case <-serviceStopOrNever(serviceStop):
	}
	if stopAnnounce != nil {
		stopAnnounce()
	}
	_ = server.Close()
}

func prepareSchool(st *store.Store, api *httpapi.API, data string) {
	n, err := st.CountUsers()
	if err != nil {
		log.Print(err)
		return
	}
	if n == 0 {
		if err := loadSample(st); err != nil {
			log.Print(err)
			return
		}
		note := filepath.Join(data, "FIRST_LOGIN.txt")
		_ = os.WriteFile(note, []byte(firstLogin), 0o600)
		log.Print("Sample school is ready. Sign-in names are in FIRST_LOGIN.txt")
	}
	api.MaybeAutoSemester()
}

func serviceStopOrNever(stop <-chan struct{}) <-chan struct{} {
	if stop != nil {
		return stop
	}
	return make(chan struct{})
}

func apiUpdateKey(data string) (ed25519.PublicKey, error) {
	if raw, err := os.ReadFile(filepath.Join(data, "update.pub")); err == nil {
		if key, err := decodePub(string(raw)); err == nil {
			return key, nil
		}
	}
	return update.EmbeddedKey()
}

func decodePub(s string) (ed25519.PublicKey, error) {
	raw, err := base64.StdEncoding.DecodeString(strings.TrimSpace(s))
	if err != nil || len(raw) != ed25519.PublicKeySize {
		return nil, errors.New("the update key file is not valid")
	}
	return ed25519.PublicKey(raw), nil
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

const firstLogin = `Shamm School Management Systems
Sample sign-in. Pick your name, then type the 4-digit number.

admin      1850
director   1851
hanna      1852
samuel     1853
meron      1854
dawit      1855

The old passwords (name plus 1850) still work for the admin.
Change these after the school is set up.
`
