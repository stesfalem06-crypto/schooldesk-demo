package domain

import "testing"

func TestSolveEmptyWeek(t *testing.T) {
	got, err := Solve(Problem{Days: 5, PeriodsPerDay: 6})
	if err != nil || len(got) != 0 {
		t.Fatalf("%v %+v", err, got)
	}
}

func TestSolveOneClassAndMove(t *testing.T) {
	got, err := Solve(Problem{
		Days: 5, PeriodsPerDay: 6,
		Lessons: []LessonNeed{{ID: "math", ClassID: "c1", TeacherID: "t1", Periods: 4}},
	})
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 4 {
		t.Fatalf("placed %d", len(got))
	}
	if msgs := ClashMessages(got, Placement{ClassID: "c1", TeacherID: "t1", LessonID: "math", Day: got[0].Day, Period: got[0].Period}, nil, 6); len(msgs) != 0 {
		t.Fatal(msgs)
	}
	empty := Placement{ClassID: "c1", TeacherID: "t1", LessonID: "math", Day: 4, Period: 5}
	busy := false
	for _, p := range got {
		if p.Day == empty.Day && p.Period == empty.Period {
			busy = true
		}
	}
	if busy {
		t.Fatal("expected a free Friday cell")
	}
	if msgs := ClashMessages(got, empty, nil, 6); len(msgs) != 0 {
		t.Fatal(msgs)
	}
}

func TestSolveSchoolWeekHasNoClashes(t *testing.T) {
	lessons := []LessonNeed{
		{"tig", "g3", "hanna", 4},
		{"en3", "g3", "meron", 3},
		{"ma3", "g3", "samuel", 4},
		{"sc3", "g3", "sara", 3},
		{"en5", "g5", "meron", 3},
		{"ma5", "g5", "samuel", 4},
		{"sc5", "g5", "sara", 3},
		{"so5", "g5", "hanna", 3},
		{"ma8", "g8", "samuel", 4},
		{"en8", "g8", "meron", 3},
		{"sc8", "g8", "sara", 3},
		{"so8", "g8", "hanna", 2},
		{"ph", "g11", "dawit", 4},
		{"ma11", "g11", "samuel", 4},
		{"en11", "g11", "meron", 3},
	}
	got, err := Solve(Problem{Days: 5, PeriodsPerDay: 6, Lessons: lessons})
	if err != nil {
		t.Fatal(err)
	}
	classSlot := map[string]bool{}
	teacherSlot := map[string]bool{}
	for _, p := range got {
		ck := p.ClassID + ":" + slotKey(p.Day) + ":" + slotKey(p.Period)
		tk := p.TeacherID + ":" + slotKey(p.Day) + ":" + slotKey(p.Period)
		if classSlot[ck] || teacherSlot[tk] {
			t.Fatalf("clash %+v", p)
		}
		classSlot[ck] = true
		teacherSlot[tk] = true
	}
	if len(got) != 50 {
		t.Fatalf("placed %d", len(got))
	}
}

func TestSolveTooManyPeriods(t *testing.T) {
	_, err := Solve(Problem{Days: 1, PeriodsPerDay: 1, Lessons: []LessonNeed{{ID: "a", ClassID: "c", TeacherID: "t", Periods: 2}}})
	if err == nil {
		t.Fatal("expected a clear error")
	}
}

func slotKey(n int) string {
	return string(rune('0' + n))
}
