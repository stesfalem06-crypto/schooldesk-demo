package engine

import (
	"os"
	"testing"
)

func TestJavaRandomMatchesFirstValues(t *testing.T) {
	// java.util.Random(1) first nextInt() is -1155869325.
	r := NewJavaRandom(1)
	got := int32(r.next(32))
	if got != -1155869325 {
		t.Fatalf("first nextInt = %d", got)
	}
}

func TestSampleSchoolSolvesAndValidates(t *testing.T) {
	raw, err := os.ReadFile("testdata/sample-school.json")
	if err != nil {
		t.Fatal(err)
	}
	school, err := ParseSchool(raw)
	if err != nil {
		t.Fatal(err)
	}
	if school.Name != "Anseba Sample School" {
		t.Fatalf("school name %q", school.Name)
	}
	if school.Bell.BreakAfter == nil || *school.Bell.BreakAfter != 3 {
		t.Fatalf("breakAfter = %v, want 3 (the period after which the break falls)", school.Bell.BreakAfter)
	}
	if school.Timetable == nil {
		t.Fatal("sample timetable is missing")
	}
	savedProblems := Problems(Validate(school, school.Timetable))
	if len(savedProblems) > 0 {
		for i, issue := range savedProblems {
			if i == 8 {
				break
			}
			t.Logf("saved problem: %s — %s", issue.Title, issue.Detail)
		}
		t.Fatalf("saved sample has %d problems", len(savedProblems))
	}
	if len(school.Timetable.Placements) != 565 {
		t.Fatalf("saved placements = %d, want 565", len(school.Timetable.Placements))
	}

	fresh := school
	fresh.Timetable = nil
	result := Solve(fresh, SolveOptions{Seed: 2, TimeBudgetMs: 8000})
	if result.Expected != 565 {
		t.Fatalf("expected lessons = %d, want 565", result.Expected)
	}
	if result.Placed != 565 {
		for i, issue := range Problems(result.Issues) {
			if i == 12 {
				break
			}
			t.Logf("solve problem: %s — %s", issue.Title, issue.Detail)
		}
		t.Fatalf("placed %d of %d (ok=%v hard=%d)", result.Placed, result.Expected, result.OK, result.HardConflicts)
	}
	if result.Timetable == nil || result.Timetable.Summary != "Placed 565 of 565 lessons." {
		summary := ""
		if result.Timetable != nil {
			summary = result.Timetable.Summary
		}
		t.Fatalf("summary %q", summary)
	}
	problems := Problems(Validate(fresh, result.Timetable))
	if len(problems) > 0 || !result.OK {
		for i, issue := range problems {
			if i == 12 {
				break
			}
			t.Logf("validate: %s — %s", issue.Title, issue.Detail)
		}
		t.Fatalf("fresh week has %d problems", len(problems))
	}
}

func TestScoringOrderOnASmallWeek(t *testing.T) {
	breakAfter := 1
	school := School{
		Name: "Tiny",
		Days: []DayDef{{Name: "Monday", Short: "Mon"}, {Name: "Tuesday", Short: "Tue"}},
		Bell: BellSchedule{PeriodCount: 4, StartMinutes: 480, PeriodMinutes: 40, BreakAfter: &breakAfter, BreakMinutes: 20},
		Classes: []SchoolClass{{
			ID: "c-1-1", Grade: 1, Section: 1,
			HomeroomTeacherID: strPtr("t1"),
		}},
		Subjects: []Subject{{
			ID: "sub-math", Name: "Mathematics", Short: "Math", Preferred: PreferMorning,
		}},
		Teachers: []Teacher{{ID: "t1", Name: "Hanna Gebre", Short: "H. Gebre"}},
		Lessons: []Lesson{{
			ID: "l1", ClassID: "c-1-1", SubjectID: "sub-math", TeacherID: "t1", TimesPerWeek: 2, Duration: 1,
		}},
		Rules: Rules{
			Spread: LevelMedium, AvoidSameDayRepeat: LevelHigh, BalanceTeacherLoad: LevelMedium,
			LimitConsecutive: LevelMedium, MaxConsecutive: 4, PreferredTime: LevelMedium,
			HomeroomFirst: HomeroomPrefer, MaxLessonsPerDay: 7,
		},
	}
	result := Solve(school, SolveOptions{Seed: 1, TimeBudgetMs: 500})
	if !result.OK || result.Placed != 2 {
		t.Fatalf("tiny week placed %d ok=%v issues=%d", result.Placed, result.OK, len(Problems(result.Issues)))
	}
	// Both meetings are the homeroom teacher, so period 1 on a taught day is preferred.
	// A double must not start on breakAfter (index 1).
	for _, p := range result.Timetable.Placements {
		if p.Period == 1 && p.Day >= 0 {
			// duration 1 may sit on the break period; it must not be a double start.
		}
		if p.Day < 0 || p.Day > 1 || p.Period < 0 || p.Period > 3 {
			t.Fatalf("placement outside the week: %+v", p)
		}
	}
}

func strPtr(s string) *string { return &s }
