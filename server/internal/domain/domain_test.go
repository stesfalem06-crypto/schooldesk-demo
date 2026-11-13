package domain

import (
	"testing"
	"time"
)

func TestFullMarks(t *testing.T) {
	w := DefaultWeights()
	var items []Item
	for _, c := range []Component{Classwork, Quizzes, Tests, Assignments, Participation, Homework} {
		for _, half := range []int{1, 2} {
			items = append(items, Item{Component: c, Half: half, Max: 10, Score: F(10)})
		}
	}
	items = append(items, Item{Component: Exam, Max: 40, Score: F(40)})
	got, err := Summarize(w, items)
	if err != nil {
		t.Fatal(err)
	}
	if got.Mid != 30 || got.Continuous != 60 || got.Exam != 40 || got.Total != 100 || !got.Passed {
		t.Fatalf("%+v", got)
	}
}

func TestPartialAndIgnoredBlanks(t *testing.T) {
	w := DefaultWeights()
	items := []Item{
		{Component: Classwork, Half: 1, Max: 10, Score: F(8)},
		{Component: Quizzes, Half: 1, Max: 10, Score: F(10)},
		{Component: Classwork, Half: 2, Max: 10, Score: F(5)},
		{Component: Classwork, Half: 1, Max: 10, Score: nil},
		{Component: Exam, Max: 40, Score: F(30)},
	}
	got, err := Summarize(w, items)
	if err != nil {
		t.Fatal(err)
	}
	if got.Mid != 9 || got.Continuous != 11.5 || got.Exam != 30 || got.Total != 41.5 || got.Passed {
		t.Fatalf("%+v", got)
	}
}

func TestPassBoundary(t *testing.T) {
	w := DefaultWeights()
	var first []Item
	for _, c := range []Component{Classwork, Quizzes, Tests, Assignments, Participation, Homework} {
		first = append(first, Item{Component: c, Half: 1, Max: 10, Score: F(10)})
	}
	for _, c := range []Component{Classwork, Quizzes, Tests, Assignments} {
		first = append(first, Item{Component: c, Half: 2, Max: 10, Score: F(10)})
	}
	exact, err := Summarize(w, first)
	if err != nil {
		t.Fatal(err)
	}
	if exact.Total != 50 || exact.Passed {
		t.Fatalf("50 must fail: %+v", exact)
	}
	with := append(append([]Item{}, first...), Item{Component: Exam, Max: 40, Score: F(0.01)})
	over, err := Summarize(w, with)
	if err != nil {
		t.Fatal(err)
	}
	if over.Total != 50.01 || !over.Passed {
		t.Fatalf("50.01 must pass: %+v", over)
	}
}

func TestWeightsAndRange(t *testing.T) {
	w := DefaultWeights()
	w.Homework = 9
	if _, err := Summarize(w, nil); err == nil {
		t.Fatal("weights must add to 60")
	}
	bad := []Item{{Component: Classwork, Half: 1, Max: 10, Score: F(11)}}
	if _, err := Summarize(DefaultWeights(), bad); err == nil {
		t.Fatal("score above max accepted")
	}
}

func TestCompetitionRankingAndPromotion(t *testing.T) {
	students := []StudentMarks{
		{ID: "a", Level: "high", Totals: []float64{90, 90}},
		{ID: "b", Level: "high", Totals: []float64{80, 80}},
		{ID: "c", Level: "high", Totals: []float64{80, 80}},
		{ID: "d", Level: "high", Totals: []float64{70, 70}},
		{ID: "e", Level: "high", Dropout: true, Totals: []float64{99}},
		{ID: "f", Level: "high"},
		{ID: "g", Level: "high", Totals: []float64{40, 40}},
		{ID: "h", Level: "high", Totals: []float64{80, 40}},
		{ID: "i", Level: "elementary", Totals: []float64{80, 40, 40}},
	}
	limits := FailLimits{Elementary: 2, Junior: 3, High: 2}
	got := Standings(students, limits)
	byID := map[string]Standing{}
	for _, s := range got {
		byID[s.ID] = s
	}
	if byID["a"].Rank != 1 || byID["a"].Average != 90 || byID["a"].Status != "promoted" {
		t.Fatalf("a %+v", byID["a"])
	}
	if byID["b"].Rank != 2 || byID["c"].Rank != 2 {
		t.Fatalf("tie ranks b=%d c=%d", byID["b"].Rank, byID["c"].Rank)
	}
	if byID["d"].Rank != 4 || byID["d"].Status != "promoted" {
		t.Fatalf("d %+v", byID["d"])
	}
	if byID["e"].Status != "dropout" || byID["e"].Rank != 0 {
		t.Fatalf("dropout %+v", byID["e"])
	}
	if byID["f"].Status != "incomplete" || byID["f"].Rank != 0 {
		t.Fatalf("incomplete %+v", byID["f"])
	}
	if byID["g"].Status != "failed" || byID["g"].Average != 40 {
		t.Fatalf("low average %+v", byID["g"])
	}
	// Average 60, one failed subject, high-school limit 2: still promoted.
	if byID["h"].Average != 60 || byID["h"].FailedSubjects != 1 || byID["h"].Status != "promoted" {
		t.Fatalf("h %+v", byID["h"])
	}
	// Elementary limit 2, two failed subjects: failed even though average can be above 50.
	if byID["i"].FailedSubjects != 2 || byID["i"].Status != "failed" {
		t.Fatalf("i %+v", byID["i"])
	}
	// Average exactly 50 is failed.
	edge := Standings([]StudentMarks{{ID: "z", Level: "junior", Totals: []float64{50, 50}}}, DefaultFailLimits())
	if edge[0].Status != "failed" || edge[0].Average != 50 {
		t.Fatalf("%+v", edge[0])
	}
}

func TestThreeWayTie(t *testing.T) {
	got := Standings([]StudentMarks{
		{ID: "a", Level: "junior", Totals: []float64{70}},
		{ID: "b", Level: "junior", Totals: []float64{70}},
		{ID: "c", Level: "junior", Totals: []float64{70}},
	}, DefaultFailLimits())
	for _, s := range got {
		if s.Rank != 1 || s.Status != "promoted" {
			t.Fatalf("%+v", s)
		}
	}
}

func TestFeesNoDiscount(t *testing.T) {
	got, err := Fee(1000, []float64{400, 250})
	if err != nil {
		t.Fatal(err)
	}
	if got.Paid != 650 || got.Remaining != 350 || got.Due != 1000 {
		t.Fatalf("%+v", got)
	}
	if err := CanPay(1000, 650, 350); err != nil {
		t.Fatal(err)
	}
	if err := CanPay(1000, 650, 350.01); err == nil {
		t.Fatal("overpayment accepted")
	}
	if err := CanPay(1000, 650, 0); err == nil {
		t.Fatal("zero payment accepted")
	}
	full, err := Fee(1000, []float64{1000})
	if err != nil || full.Remaining != 0 {
		t.Fatalf("%+v %v", full, err)
	}
	if _, err := Fee(1000, []float64{1001}); err == nil {
		t.Fatal("stored overpayment accepted")
	}
	if _, err := Fee(-1, nil); err == nil {
		t.Fatal("negative fee accepted")
	}
}

func TestAbsenceMarch2026(t *testing.T) {
	got, err := Absence(MonthInput{
		Year:       2026,
		Month:      time.March,
		SchoolDays: []time.Weekday{time.Monday, time.Tuesday, time.Wednesday, time.Thursday, time.Friday},
		Periods: map[time.Weekday]int{
			time.Monday: 3, time.Tuesday: 2, time.Wednesday: 0, time.Thursday: 4, time.Friday: 1,
		},
		Absent: []time.Time{
			time.Date(2026, 3, 2, 15, 0, 0, 0, time.UTC),
			time.Date(2026, 3, 3, 0, 0, 0, 0, time.UTC),
			time.Date(2026, 3, 9, 0, 0, 0, 0, time.UTC),
		},
		MakeupClasses: 1,
		MakeupPeriods: 2,
	})
	if err != nil {
		t.Fatal(err)
	}
	if got.AbsentDays != 3 || got.Weeks != 5 || got.Scheduled != 45 || got.MissedPeriods != 8 {
		t.Fatalf("%+v", got)
	}
	if got.LostPeriods != 6 || got.MakeupClasses != 1 || got.MakeupPeriods != 2 {
		t.Fatalf("%+v", got)
	}
	if got.AbsenteeismPerWeek != 0.6 || got.LostPerWeek != 1.2 || got.PercentLost != 13.33 {
		t.Fatalf("%+v", got)
	}
	// Make-up larger than the miss does not go negative.
	over, err := Absence(MonthInput{
		Year: 2026, Month: time.March,
		SchoolDays:    []time.Weekday{time.Monday},
		Periods:       map[time.Weekday]int{time.Monday: 1},
		Absent:        []time.Time{time.Date(2026, 3, 2, 0, 0, 0, 0, time.UTC)},
		MakeupPeriods: 5,
	})
	if err != nil || over.LostPeriods != 0 || over.PercentLost != 0 {
		t.Fatalf("%+v %v", over, err)
	}
}

func TestTimetableNoClashes(t *testing.T) {
	p := Problem{
		Days: 5, PeriodsPerDay: 2,
		Lessons: []LessonNeed{
			{ID: "A-math", ClassID: "A", TeacherID: "T1", Periods: 3},
			{ID: "A-eng", ClassID: "A", TeacherID: "T2", Periods: 2},
			{ID: "B-math", ClassID: "B", TeacherID: "T1", Periods: 2},
			{ID: "B-eng", ClassID: "B", TeacherID: "T2", Periods: 3},
		},
		Unavailable: map[string]map[int]bool{"T1": {0: true}},
	}
	got, err := Solve(p)
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 10 {
		t.Fatalf("placements %d", len(got))
	}
	classSlot := map[string]bool{}
	teacherSlot := map[string]bool{}
	counts := map[string]int{}
	for _, pl := range got {
		ck := pl.ClassID + ":" + itoa(pl.Day) + ":" + itoa(pl.Period)
		tk := pl.TeacherID + ":" + itoa(pl.Day) + ":" + itoa(pl.Period)
		if classSlot[ck] || teacherSlot[tk] {
			t.Fatalf("clash %+v", pl)
		}
		classSlot[ck] = true
		teacherSlot[tk] = true
		counts[pl.LessonID]++
		if pl.TeacherID == "T1" && pl.Day == 0 && pl.Period == 0 {
			t.Fatal("teacher placed in an unavailable period")
		}
	}
	if counts["A-math"] != 3 || counts["A-eng"] != 2 || counts["B-math"] != 2 || counts["B-eng"] != 3 {
		t.Fatalf("counts %v", counts)
	}
	msgs := ClashMessages(got[:1], Placement{
		ClassID: "B", TeacherID: got[0].TeacherID, LessonID: "other", Day: got[0].Day, Period: got[0].Period,
	}, nil, 2)
	if len(msgs) == 0 {
		t.Fatal("expected a clash warning")
	}
}

func TestTimetableImpossible(t *testing.T) {
	_, err := Solve(Problem{
		Days: 5, PeriodsPerDay: 1,
		Lessons: []LessonNeed{
			{ID: "a", ClassID: "A", TeacherID: "T", Periods: 5},
			{ID: "b", ClassID: "B", TeacherID: "T", Periods: 5},
			{ID: "c", ClassID: "C", TeacherID: "T", Periods: 5},
		},
	})
	if err == nil {
		t.Fatal("overloaded teacher was accepted")
	}
}

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	var b [8]byte
	i := len(b)
	for n > 0 {
		i--
		b[i] = byte('0' + n%10)
		n /= 10
	}
	return string(b[i:])
}
