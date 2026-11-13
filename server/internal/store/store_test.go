package store

import (
	"path/filepath"
	"testing"
	"time"

	"schooldesk/internal/domain"
)

func TestMarksRankFeesAndAbsence(t *testing.T) {
	s, err := Open(filepath.Join(t.TempDir(), "school.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer s.Close()
	settings := Settings{
		AcademicYear: "2026-2027",
		Semester:     1,
		YearlyFee:    1000,
		UtilityFee:   200,
		Weights:      domain.DefaultWeights(),
		FailLimits:   domain.FailLimits{Elementary: 2, Junior: 3, High: 2},
	}
	if err := s.SaveSettings(settings); err != nil {
		t.Fatal(err)
	}
	teacher, err := s.SaveStaff(Staff{FullName: "Samuel Ghebremeskel", Sex: "M", StaffType: "teaching", Qualification: "degree"})
	if err != nil {
		t.Fatal(err)
	}
	class, err := s.SaveClass(Class{Name: "Grade 8A", Level: "junior", Grade: 8, AcademicYear: "2026-2027", HomeroomStaffID: teacher.ID})
	if err != nil {
		t.Fatal(err)
	}
	subject, err := s.SaveSubject(Subject{Name: "Mathematics"})
	if err != nil {
		t.Fatal(err)
	}
	cs, err := s.AddClassSubject(class.ID, subject.ID, teacher.ID, 5, 1, domain.DefaultWeights())
	if err != nil {
		t.Fatal(err)
	}
	names := []string{"Abel", "Bereket", "Dawit", "Yonatan"}
	var students []Student
	for _, name := range names {
		st, err := s.SaveStudent(Student{FullName: name, Sex: "M", MotherName: "Selam", ClassID: class.ID})
		if err != nil {
			t.Fatal(err)
		}
		students = append(students, st)
	}
	left, err := s.SaveStudent(Student{FullName: "Hiwet", Sex: "F", MotherName: "Rahwa", ClassID: class.ID})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := s.SetDropout(left.ID, true, "Moved away", "2026-10-01"); err != nil {
		t.Fatal(err)
	}
	assessments, err := s.ListAssessments(cs.ID)
	if err != nil || len(assessments) != 1 || assessments[0].Component != "exam" {
		t.Fatalf("exam missing: %+v %v", assessments, err)
	}
	exam := assessments[0].ID
	// Full continuous marks plus exams 40, 30, 30, 10 so averages are 100, 90, 90, 70.
	for _, c := range []string{"classwork", "quizzes", "tests", "assignments", "participation", "homework"} {
		for _, half := range []int{1, 2} {
			a, err := s.AddAssessment(cs.ID, c, half, c, 10, "")
			if err != nil {
				t.Fatal(err)
			}
			for _, st := range students {
				if _, conflict, err := s.SetScore("u", a.ID, st.ID, domain.F(10), 0); err != nil || conflict {
					t.Fatal(err, conflict)
				}
			}
		}
	}
	exams := []float64{40, 30, 30, 10}
	for i, st := range students {
		if _, conflict, err := s.SetScore("u", exam, st.ID, domain.F(exams[i]), 0); err != nil || conflict {
			t.Fatal(err, conflict)
		}
	}
	// A second write with a stale revision conflicts and keeps the old mark.
	if _, conflict, err := s.SetScore("u", exam, students[0].ID, domain.F(1), 0); err != nil || !conflict {
		t.Fatal("expected a conflict", err, conflict)
	}
	results, err := s.ClassResults(class.ID, 1)
	if err != nil {
		t.Fatal(err)
	}
	byName := map[string]StudentResult{}
	for _, sr := range results.Students {
		byName[sr.Student.FullName] = sr
	}
	if byName["Abel"].Standing.Average != 100 || byName["Abel"].Standing.Rank != 1 || byName["Abel"].Standing.Status != "promoted" {
		t.Fatalf("Abel %+v", byName["Abel"].Standing)
	}
	if byName["Bereket"].Standing.Rank != 2 || byName["Dawit"].Standing.Rank != 2 || byName["Yonatan"].Standing.Rank != 4 {
		t.Fatalf("ranks B=%d D=%d Y=%d", byName["Bereket"].Standing.Rank, byName["Dawit"].Standing.Rank, byName["Yonatan"].Standing.Rank)
	}
	if byName["Hiwet"].Standing.Status != "dropout" || byName["Hiwet"].Standing.Rank != 0 {
		t.Fatalf("dropout %+v", byName["Hiwet"].Standing)
	}
	if len(byName["Abel"].Subjects) != 1 || byName["Abel"].Subjects[0].Result.Mid != 30 || byName["Abel"].Subjects[0].Result.Total != 100 {
		t.Fatalf("subject %+v", byName["Abel"].Subjects)
	}
	if _, err := s.AddPayment(students[0].ID, "2026-2027", "2026-09-01", "u", 400); err != nil {
		t.Fatal(err)
	}
	if _, err := s.AddPayment(students[0].ID, "2026-2027", "2026-10-01", "u", 700); err == nil {
		t.Fatal("overpayment accepted")
	}
	rows, err := s.FeeRows(class.ID, "2026-2027")
	if err != nil {
		t.Fatal(err)
	}
	for _, row := range rows {
		if row.StudentID == students[0].ID && (row.Paid != 400 || row.Remaining != 600) {
			t.Fatalf("fee %+v", row)
		}
	}
	if err := s.SaveBell(Bell{Days: 5, PeriodsPerDay: 6}); err != nil {
		t.Fatal(err)
	}
	if err := s.SetWeeklyPeriods(teacher.ID, []int{3, 2, 0, 4, 1, 0, 0}); err != nil {
		t.Fatal(err)
	}
	if err := s.AddAbsence(teacher.ID, "2026-03-02", ""); err != nil {
		t.Fatal(err)
	}
	if err := s.AddAbsence(teacher.ID, "2026-03-03", ""); err != nil {
		t.Fatal(err)
	}
	if err := s.AddAbsence(teacher.ID, "2026-03-09", ""); err != nil {
		t.Fatal(err)
	}
	if err := s.AddMakeup(teacher.ID, "2026-03-12", "", 2); err != nil {
		t.Fatal(err)
	}
	rep, err := s.AbsenceReport(teacher.ID, 2026, time.March)
	if err != nil {
		t.Fatal(err)
	}
	if rep.AbsentDays != 3 || rep.Scheduled != 45 || rep.LostPeriods != 6 || rep.PercentLost != 13.33 {
		t.Fatalf("%+v", rep)
	}
	heads, err := s.Headcount(class.ID)
	if err != nil {
		t.Fatal(err)
	}
	if heads.Students != 5 || heads.Male != 4 || heads.Female != 1 || heads.Dropped != 1 || heads.DroppedF != 1 {
		t.Fatalf("%+v", heads)
	}
}
