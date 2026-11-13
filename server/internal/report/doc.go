package report

import "time"

// Footer is drawn on every page and every slide.
const Footer = "Developed by 9 Multimedia and IT Solutions · SHAMM TESFALEM · 07162947"

type Table struct {
	Headers []string
	Rows    [][]string
}

type Section struct {
	Title string
	Lines []string
	Table *Table
	Chart []byte
}

type Document struct {
	School   string
	Title    string
	Subtitle string
	When     time.Time
	Sections []Section
}
