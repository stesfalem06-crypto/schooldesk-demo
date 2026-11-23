package report

import (
	"bytes"
	"strings"

	"github.com/go-pdf/fpdf"

	"schooldesk/internal/engine"
)

// TimetablePDF prints one class or one teacher. An empty filter prints every class.
func TimetablePDF(school engine.School, classID, teacherID string) ([]byte, error) {
	pdf := fpdf.New("L", "mm", "A4", "")
	pdf.SetCompression(false)
	pdf.AddUTF8FontFromBytes("dejavu", "", fontRegular)
	pdf.AddUTF8FontFromBytes("dejavu", "B", fontBold)
	pdf.SetFooterFunc(func() {
		pdf.SetY(-12)
		pdf.SetFont("dejavu", "", 8)
		pdf.SetTextColor(90, 90, 90)
		pdf.CellFormat(0, 8, Footer, "", 0, "C", false, 0, "")
	})
	periods := school.Bell.Periods()
	targets := timetableTargets(school, classID, teacherID)
	if len(targets) == 0 {
		targets = []timetableTarget{{Title: school.Name}}
	}
	for _, target := range targets {
		pdf.AddPage()
		pdf.SetFont("dejavu", "B", 16)
		pdf.SetTextColor(20, 40, 70)
		title := school.Name
		if title == "" {
			title = "Timetable"
		}
		pdf.CellFormat(0, 8, title, "", 1, "L", false, 0, "")
		pdf.SetFont("dejavu", "", 12)
		pdf.CellFormat(0, 7, target.Title, "", 1, "L", false, 0, "")
		pdf.Ln(2)
		drawGrid(pdf, school, periods, target)
	}
	var buf bytes.Buffer
	if err := pdf.Output(&buf); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

type timetableTarget struct {
	Title     string
	ClassID   string
	TeacherID string
}

func timetableTargets(school engine.School, classID, teacherID string) []timetableTarget {
	if classID != "" {
		title := classID
		if c := school.ClassByID(classID); c != nil {
			title = c.TimetableName()
		}
		return []timetableTarget{{Title: title, ClassID: classID}}
	}
	if teacherID != "" {
		title := teacherID
		if t := school.TeacherByID(teacherID); t != nil {
			title = t.Name
		}
		return []timetableTarget{{Title: title, TeacherID: teacherID}}
	}
	var out []timetableTarget
	for _, c := range school.ClassesInOrder() {
		out = append(out, timetableTarget{Title: c.TimetableName(), ClassID: c.ID})
	}
	return out
}

func drawGrid(pdf *fpdf.Fpdf, school engine.School, periods []engine.PeriodInfo, target timetableTarget) {
	days := school.Days
	if len(days) == 0 || len(periods) == 0 {
		return
	}
	left := 14.0
	top := pdf.GetY()
	labelW := 28.0
	width := (277.0 - labelW) / float64(len(days))
	height := 18.0
	pdf.SetFont("dejavu", "B", 8)
	pdf.SetFillColor(10, 120, 160)
	pdf.SetTextColor(255, 255, 255)
	pdf.Rect(left, top, labelW, 8, "F")
	for i, day := range days {
		x := left + labelW + float64(i)*width
		pdf.Rect(x, top, width, 8, "F")
		pdf.SetXY(x, top)
		pdf.CellFormat(width, 8, day.Name, "", 0, "C", false, 0, "")
	}
	pdf.SetTextColor(20, 30, 40)
	for p, period := range periods {
		y := top + 8 + float64(p)*height
		pdf.SetFont("dejavu", "B", 8)
		pdf.SetFillColor(232, 244, 248)
		pdf.Rect(left, y, labelW, height, "FD")
		pdf.SetXY(left, y+1)
		pdf.CellFormat(labelW, 5, period.Label, "", 0, "C", false, 0, "")
		pdf.SetFont("dejavu", "", 7)
		pdf.SetXY(left, y+7)
		pdf.CellFormat(labelW, 5, period.Start, "", 0, "C", false, 0, "")
		for d := range days {
			x := left + labelW + float64(d)*width
			pdf.SetFillColor(255, 255, 255)
			pdf.Rect(x, y, width, height, "FD")
			text := cellText(school, target, d, period.Index)
			pdf.SetXY(x+1, y+4)
			pdf.SetFont("dejavu", "", 7)
			pdf.CellFormat(width-2, 8, text, "", 0, "C", false, 0, "")
		}
	}
}

func cellText(school engine.School, target timetableTarget, day, period int) string {
	if school.Timetable == nil {
		return ""
	}
	var lines []string
	for _, p := range school.Timetable.Placements {
		lesson := school.LessonByID(p.LessonID)
		if lesson == nil {
			continue
		}
		if p.Day != day {
			continue
		}
		if period < p.Period || period >= p.Period+lesson.Duration {
			continue
		}
		if target.ClassID != "" && lesson.ClassID != target.ClassID {
			continue
		}
		if target.TeacherID != "" && lesson.TeacherID != target.TeacherID {
			continue
		}
		subject := lesson.SubjectID
		if s := school.SubjectByID(lesson.SubjectID); s != nil {
			subject = s.Short
			if subject == "" {
				subject = s.Name
			}
		}
		who := ""
		if target.TeacherID == "" {
			if t := school.TeacherByID(lesson.TeacherID); t != nil {
				who = t.Short
			}
		} else if c := school.ClassByID(lesson.ClassID); c != nil {
			who = c.Label()
		}
		line := subject
		if who != "" {
			line = subject + " " + who
		}
		lines = append(lines, line)
	}
	return strings.Join(lines, " / ")
}
