//go:build !schooldeskdemo

package main

import (
	"schooldesk/internal/httpapi"
	"schooldesk/internal/license"
	"schooldesk/internal/seed"
	"schooldesk/internal/store"
)

func loadSample(st *store.Store) error {
	return seed.Demo(st)
}

func openGate(path string, parts license.Parts) httpapi.Gate {
	return fileGate{path: path, parts: parts}
}
