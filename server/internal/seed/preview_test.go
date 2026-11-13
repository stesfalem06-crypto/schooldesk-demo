package seed

import (
	"path/filepath"
	"testing"

	"schooldesk/internal/buildinfo"
	"schooldesk/internal/store"
)

func TestPreviewFillsTheSchool(t *testing.T) {
	if buildinfo.IsDemo() {
		t.Fatal("the test build must not use the demo tag")
	}
	s, err := store.Open(filepath.Join(t.TempDir(), "school.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer s.Close()
	if err := Preview(s); err != nil {
		t.Fatal(err)
	}
	n, err := s.CountUsers()
	if err != nil || n < 6 {
		t.Fatalf("users %d %v", n, err)
	}
	classes, err := s.ListClasses()
	if err != nil || len(classes) < 4 {
		t.Fatalf("classes %+v %v", classes, err)
	}
	var promoted, failed int
	for _, class := range classes {
		results, err := s.ClassResults(class.ID, 1)
		if err != nil {
			t.Fatal(err)
		}
		if len(results.Students) == 0 {
			t.Fatalf("%s has no results", class.Name)
		}
		for _, student := range results.Students {
			if student.Student.DroppedOut {
				continue
			}
			if len(student.Subjects) == 0 {
				t.Fatalf("%s has no subject totals", student.Student.FullName)
			}
		}
		stat, err := s.Promotion(class.ID, 1)
		if err != nil {
			t.Fatal(err)
		}
		promoted += stat.Promoted
		failed += stat.Failed
	}
	if promoted == 0 || failed == 0 {
		t.Fatalf("semester stats promoted=%d failed=%d", promoted, failed)
	}
	subjects, err := s.ListClassSubjects("", 1)
	if err != nil {
		t.Fatal(err)
	}
	for _, cs := range subjects {
		assessments, err := s.ListAssessments(cs.ID)
		if err != nil {
			t.Fatal(err)
		}
		seen := map[string]bool{}
		for _, a := range assessments {
			seen[a.Component] = true
		}
		for _, part := range []string{"classwork", "quizzes", "tests", "assignments", "participation", "homework", "exam"} {
			if !seen[part] {
				t.Fatalf("%s %s missing %s", cs.ClassName, cs.SubjectName, part)
			}
		}
	}
	finance, err := s.Finance()
	if err != nil || finance.FeesCollected == 0 || finance.Expenses == 0 {
		t.Fatalf("finance %+v %v", finance, err)
	}
	meetings, err := s.ListMeetings()
	if err != nil || len(meetings) < 2 {
		t.Fatalf("meetings %+v %v", meetings, err)
	}
	slots, err := s.Timetable()
	if err != nil || len(slots) == 0 {
		t.Fatalf("timetable %d %v", len(slots), err)
	}
	staff, err := s.ListStaff()
	if err != nil || len(staff) < 6 {
		t.Fatalf("staff %d %v", len(staff), err)
	}
	if _, err := s.AbsenceReport(staff[0].ID, 2026, 11); err != nil {
		t.Fatal(err)
	}
}
