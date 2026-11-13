package report

import (
	"archive/zip"
	"bytes"
	"io"
	"strings"
	"testing"
	"time"
	"unicode/utf16"
)

func utf16be(s string) []byte {
	u := utf16.Encode([]rune(s))
	b := make([]byte, len(u)*2)
	for i, v := range u {
		b[i*2] = byte(v >> 8)
		b[i*2+1] = byte(v)
	}
	return b
}

func sample() Document {
	return Document{
		School:   "Hope Academy",
		Title:    "School report",
		Subtitle: "Semester 1 · 2026-2027",
		When:     time.Date(2026, 11, 13, 0, 0, 0, 0, time.UTC),
		Sections: []Section{{
			Title: "Results",
			Lines: []string{"Promoted 8 of 10."},
			Table: &Table{Headers: []string{"Class", "Promoted"}, Rows: [][]string{{"Grade 8A", "6"}}},
			Chart: Bars("PROMOTED", []string{"8A", "11A"}, []float64{6, 4}),
		}},
	}
}

func TestDocumentsCarryFooter(t *testing.T) {
	doc := sample()
	pdf, err := PDF(doc)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Contains(pdf, utf16be(Footer)) {
		t.Fatal("pdf is missing the footer")
	}
	for _, build := range []func(Document) ([]byte, error){DOCX, PPTX} {
		raw, err := build(doc)
		if err != nil {
			t.Fatal(err)
		}
		zr, err := zip.NewReader(bytes.NewReader(raw), int64(len(raw)))
		if err != nil {
			t.Fatal(err)
		}
		var joined strings.Builder
		slides := 0
		for _, f := range zr.File {
			rc, err := f.Open()
			if err != nil {
				t.Fatal(err)
			}
			b, _ := io.ReadAll(rc)
			rc.Close()
			joined.Write(b)
			if strings.Contains(f.Name, "slide") && strings.HasSuffix(f.Name, ".xml") && !strings.Contains(f.Name, "rels") {
				slides++
				if !bytes.Contains(b, []byte(Footer)) {
					t.Fatalf("%s missing footer", f.Name)
				}
			}
		}
		if !strings.Contains(joined.String(), Footer) {
			t.Fatal("office file missing footer")
		}
		if build != nil && slides == 0 && bytes.Contains(raw[:2], []byte("PK")) {
			// docx has no slides; pptx must
		}
	}
	pptx, err := PPTX(doc)
	if err != nil {
		t.Fatal(err)
	}
	zr, err := zip.NewReader(bytes.NewReader(pptx), int64(len(pptx)))
	if err != nil {
		t.Fatal(err)
	}
	n := 0
	for _, f := range zr.File {
		if strings.HasPrefix(f.Name, "ppt/slides/slide") && strings.HasSuffix(f.Name, ".xml") {
			n++
		}
	}
	if n < 2 {
		t.Fatalf("slides %d", n)
	}
}
