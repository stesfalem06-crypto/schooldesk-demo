//go:build schooldeskdemo

package main

import (
	"log"
	"time"

	"schooldesk/internal/httpapi"
	"schooldesk/internal/license"
	"schooldesk/internal/seed"
	"schooldesk/internal/store"
)

func loadSample(st *store.Store) error {
	return seed.Preview(st)
}

func openGate(path string, parts license.Parts) httpapi.Gate {
	log.Print("SchoolDesk demo. No unlock code is required.")
	return demoGate{fileGate: fileGate{path: path, parts: parts}}
}

// demoGate is compiled only into the demo binary. It reports the school as unlocked.
type demoGate struct {
	fileGate
}

func (g demoGate) Current(now time.Time) (license.Status, error) {
	st, _ := g.fileGate.Current(now)
	st.Licensed = true
	st.Expired = false
	st.ClockProblem = false
	st.NeverEnds = true
	st.Unlimited = true
	st.Message = ""
	if st.SchoolName == "" {
		st.SchoolName = "Hope Academy"
	}
	return st, nil
}
