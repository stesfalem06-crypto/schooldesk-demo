package report

import (
	"bytes"
	"strconv"

	"github.com/go-pdf/fpdf"
)

func PDF(doc Document) ([]byte, error) {
	pdf := fpdf.New("P", "mm", "A4", "")
	pdf.SetCompression(false)
	pdf.AddUTF8FontFromBytes("dejavu", "", fontRegular)
	pdf.AddUTF8FontFromBytes("dejavu", "B", fontBold)
	pdf.SetFooterFunc(func() {
		pdf.SetY(-12)
		pdf.SetFont("dejavu", "", 8)
		pdf.SetTextColor(90, 90, 90)
		pdf.CellFormat(0, 8, Footer, "", 0, "C", false, 0, "")
	})
	pdf.SetAutoPageBreak(true, 16)
	pdf.AddPage()
	pdf.SetFillColor(14, 124, 102)
	pdf.Rect(0, 0, 210, 28, "F")
	pdf.SetTextColor(255, 255, 255)
	pdf.SetFont("dejavu", "B", 16)
	pdf.SetXY(12, 6)
	pdf.CellFormat(186, 8, doc.School, "", 1, "L", false, 0, "")
	pdf.SetX(12)
	pdf.SetFont("dejavu", "", 11)
	pdf.CellFormat(186, 6, doc.Title, "", 1, "L", false, 0, "")
	pdf.SetY(34)
	pdf.SetTextColor(80, 80, 80)
	pdf.SetFont("dejavu", "", 10)
	if doc.Subtitle != "" {
		pdf.MultiCell(186, 5, doc.Subtitle, "", "L", false)
	}
	if !doc.When.IsZero() {
		pdf.CellFormat(186, 5, doc.When.Format("2 January 2006"), "", 1, "L", false, 0, "")
	}
	pdf.Ln(2)
	for i, sec := range doc.Sections {
		if pdf.GetY() > 250 {
			pdf.AddPage()
		}
		pdf.SetTextColor(14, 124, 102)
		pdf.SetFont("dejavu", "B", 13)
		pdf.CellFormat(186, 8, sec.Title, "", 1, "L", false, 0, "")
		pdf.SetTextColor(28, 36, 48)
		pdf.SetFont("dejavu", "", 10)
		for _, line := range sec.Lines {
			pdf.MultiCell(186, 5, line, "", "L", false)
		}
		if sec.Table != nil {
			drawTable(pdf, sec.Table)
		}
		if len(sec.Chart) > 0 {
			name := "c" + strconv.Itoa(i)
			opt := fpdf.ImageOptions{ImageType: "PNG"}
			pdf.RegisterImageOptionsReader(name, opt, bytes.NewReader(sec.Chart))
			pdf.ImageOptions(name, 12, pdf.GetY()+1, 150, 0, true, opt, 0, "")
		}
		pdf.Ln(3)
	}
	var buf bytes.Buffer
	if err := pdf.Output(&buf); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func drawTable(pdf *fpdf.Fpdf, t *Table) {
	if len(t.Headers) == 0 {
		return
	}
	cols := len(t.Headers)
	width := 186.0 / float64(cols)
	pdf.SetFont("dejavu", "B", 8)
	pdf.SetFillColor(14, 124, 102)
	pdf.SetTextColor(255, 255, 255)
	for _, h := range t.Headers {
		pdf.CellFormat(width, 7, h, "1", 0, "C", true, 0, "")
	}
	pdf.Ln(-1)
	pdf.SetFont("dejavu", "", 8)
	pdf.SetTextColor(28, 36, 48)
	for i, row := range t.Rows {
		if pdf.GetY() > 270 {
			pdf.AddPage()
		}
		if i%2 == 0 {
			pdf.SetFillColor(244, 247, 245)
		} else {
			pdf.SetFillColor(255, 255, 255)
		}
		for c := 0; c < cols; c++ {
			cell := ""
			if c < len(row) {
				cell = row[c]
			}
			pdf.CellFormat(width, 6, cell, "1", 0, "L", true, 0, "")
		}
		pdf.Ln(-1)
	}
}
