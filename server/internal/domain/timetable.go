package domain

import (
	"errors"
	"math/rand"
	"sort"
	"time"
)

type LessonNeed struct {
	ID        string
	ClassID   string
	TeacherID string
	Periods   int
}

type Problem struct {
	Days          int
	PeriodsPerDay int
	Lessons       []LessonNeed
	// Unavailable[teacher][day*PeriodsPerDay+period] = true
	Unavailable map[string]map[int]bool
}

type Placement struct {
	ClassID   string
	TeacherID string
	LessonID  string
	Day       int
	Period    int
}

type unit struct {
	lesson, classID, teacher string
}

// Solve builds a clash-free week. A teacher is in one class at a time,
// a class has one lesson at a time, and unavailable periods stay empty.
func Solve(p Problem) ([]Placement, error) {
	if p.Days < 1 || p.Days > 7 || p.PeriodsPerDay < 1 || p.PeriodsPerDay > 16 {
		return nil, errors.New("check the days and the periods in a day")
	}
	slots := p.Days * p.PeriodsPerDay
	classLoad := map[string]int{}
	teacherLoad := map[string]int{}
	var units []unit
	for _, ls := range p.Lessons {
		if ls.Periods < 1 {
			return nil, errors.New("each subject needs at least one period a week")
		}
		if ls.ClassID == "" || ls.TeacherID == "" || ls.ID == "" {
			return nil, errors.New("a lesson is missing its class or teacher")
		}
		classLoad[ls.ClassID] += ls.Periods
		teacherLoad[ls.TeacherID] += ls.Periods
		for i := 0; i < ls.Periods; i++ {
			units = append(units, unit{ls.ID, ls.ClassID, ls.TeacherID})
		}
	}
	for _, n := range classLoad {
		if n > slots {
			return nil, errors.New("a class has more periods than the week has")
		}
	}
	freeCount := map[string]int{}
	for teacher, n := range teacherLoad {
		free := 0
		for slot := 0; slot < slots; slot++ {
			if !blocked(p, teacher, slot) {
				free++
			}
		}
		if n > free {
			return nil, errors.New("a teacher has more lessons than free periods")
		}
		freeCount[teacher] = free
	}
	sort.SliceStable(units, func(i, j int) bool {
		if freeCount[units[i].teacher] != freeCount[units[j].teacher] {
			return freeCount[units[i].teacher] < freeCount[units[j].teacher]
		}
		if classLoad[units[i].classID] != classLoad[units[j].classID] {
			return classLoad[units[i].classID] > classLoad[units[j].classID]
		}
		if units[i].lesson != units[j].lesson {
			return units[i].lesson < units[j].lesson
		}
		return units[i].teacher < units[j].teacher
	})
	rng := rand.New(rand.NewSource(1))
	deadline := time.Now().Add(2 * time.Second)
	for attempt := 0; attempt < 24; attempt++ {
		if time.Now().After(deadline) {
			break
		}
		order := append([]unit(nil), units...)
		if attempt > 0 {
			rng.Shuffle(len(order), func(i, j int) { order[i], order[j] = order[j], order[i] })
		}
		if got, ok := search(p, order, rng, 200000, deadline); ok {
			return got, nil
		}
	}
	return nil, errors.New("no clash-free timetable was found. Free a teacher or lower the periods")
}

func blocked(p Problem, teacher string, slot int) bool {
	if p.Unavailable == nil {
		return false
	}
	return p.Unavailable[teacher][slot]
}

type cand struct {
	day, period, slot, score int
}

func search(p Problem, order []unit, rng *rand.Rand, limit int, deadline time.Time) ([]Placement, bool) {
	classBusy := map[string]map[int]bool{}
	teacherBusy := map[string]map[int]bool{}
	lessonDay := map[string]map[int]int{}
	nodes := 0
	place := make([]Placement, 0, len(order))
	var bt func(i int) bool
	bt = func(i int) bool {
		if i == len(order) {
			return true
		}
		nodes++
		if nodes > limit || time.Now().After(deadline) {
			return false
		}
		u := order[i]
		cands := make([]cand, 0, p.Days*p.PeriodsPerDay)
		for day := 0; day < p.Days; day++ {
			for period := 0; period < p.PeriodsPerDay; period++ {
				slot := day*p.PeriodsPerDay + period
				if classBusy[u.classID][slot] || teacherBusy[u.teacher][slot] || blocked(p, u.teacher, slot) {
					continue
				}
				score := 0
				if lessonDay[u.lesson][day] == 0 {
					score += 10
				}
				score -= lessonDay[u.lesson][day] * 3
				score = score*4 + rng.Intn(3)
				cands = append(cands, cand{day, period, slot, score})
			}
		}
		sort.Slice(cands, func(a, b int) bool { return cands[a].score > cands[b].score })
		if classBusy[u.classID] == nil {
			classBusy[u.classID] = map[int]bool{}
		}
		if teacherBusy[u.teacher] == nil {
			teacherBusy[u.teacher] = map[int]bool{}
		}
		if lessonDay[u.lesson] == nil {
			lessonDay[u.lesson] = map[int]int{}
		}
		for _, c := range cands {
			classBusy[u.classID][c.slot] = true
			teacherBusy[u.teacher][c.slot] = true
			lessonDay[u.lesson][c.day]++
			place = append(place, Placement{
				ClassID: u.classID, TeacherID: u.teacher, LessonID: u.lesson, Day: c.day, Period: c.period,
			})
			if bt(i + 1) {
				return true
			}
			place = place[:len(place)-1]
			delete(classBusy[u.classID], c.slot)
			delete(teacherBusy[u.teacher], c.slot)
			lessonDay[u.lesson][c.day]--
		}
		return false
	}
	if bt(0) {
		return place, true
	}
	return nil, false
}

// ClashMessages describes why a hand edit cannot sit in that cell.
func ClashMessages(existing []Placement, add Placement, unavailable map[string]map[int]bool, periodsPerDay int) []string {
	var msgs []string
	slot := add.Day*periodsPerDay + add.Period
	if unavailable[add.TeacherID][slot] {
		msgs = append(msgs, "This teacher is not available then")
	}
	for _, p := range existing {
		if p.ClassID == add.ClassID && p.Day == add.Day && p.Period == add.Period && p.LessonID != add.LessonID {
			msgs = append(msgs, "This class already has a lesson then")
		}
		if p.TeacherID == add.TeacherID && p.Day == add.Day && p.Period == add.Period && !(p.ClassID == add.ClassID && p.LessonID == add.LessonID) {
			msgs = append(msgs, "This teacher is already in another class then")
		}
	}
	return msgs
}
