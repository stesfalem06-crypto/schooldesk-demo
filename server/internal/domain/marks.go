package domain

import (
	"errors"
	"math"
)

type Component string

const (
	Classwork     Component = "classwork"
	Quizzes       Component = "quizzes"
	Tests         Component = "tests"
	Assignments   Component = "assignments"
	Participation Component = "participation"
	Homework      Component = "homework"
	Exam          Component = "exam"
)

func (c Component) CA() bool {
	switch c {
	case Classwork, Quizzes, Tests, Assignments, Participation, Homework:
		return true
	default:
		return false
	}
}

// Weights are the points each part contributes to the 60% continuous mark.
type Weights struct {
	Classwork     float64 `json:"classwork"`
	Quizzes       float64 `json:"quizzes"`
	Tests         float64 `json:"tests"`
	Assignments   float64 `json:"assignments"`
	Participation float64 `json:"participation"`
	Homework      float64 `json:"homework"`
}

func (w Weights) Of(c Component) float64 {
	switch c {
	case Classwork:
		return w.Classwork
	case Quizzes:
		return w.Quizzes
	case Tests:
		return w.Tests
	case Assignments:
		return w.Assignments
	case Participation:
		return w.Participation
	case Homework:
		return w.Homework
	default:
		return 0
	}
}

func (w Weights) Sum() float64 {
	return w.Classwork + w.Quizzes + w.Tests + w.Assignments + w.Participation + w.Homework
}

func (w Weights) Valid() bool {
	for _, n := range []float64{w.Classwork, w.Quizzes, w.Tests, w.Assignments, w.Participation, w.Homework} {
		if n < 0 || math.IsNaN(n) || math.IsInf(n, 0) {
			return false
		}
	}
	return Round2(w.Sum()) == 60
}

func DefaultWeights() Weights {
	return Weights{10, 10, 10, 10, 10, 10}
}

// Item is one collected mark. A nil Score has not been entered yet.
// Half is 1 for the first half (the mid result) and 2 for the second half.
type Item struct {
	Component Component
	Half      int
	Max       float64
	Score     *float64
}

type SubjectResult struct {
	Mid        float64 `json:"mid"`
	Continuous float64 `json:"continuous"`
	Exam       float64 `json:"exam"`
	Total      float64 `json:"total"`
	ExamSet    bool    `json:"exam_set"`
	Passed     bool    `json:"passed"`
}

// Summarize turns gradual marks into mid /30, continuous /60, exam /40 and total /100.
// Each component weight is split in half. The first half is the mid result.
// Entered marks in a half are points earned over points possible, times that half's weight.
// Marks that have not been entered yet are left out. A subject passes only above 50.
func Summarize(w Weights, items []Item) (SubjectResult, error) {
	if !w.Valid() {
		return SubjectResult{}, errors.New("the six parts must add up to 60")
	}
	type key struct {
		c    Component
		half int
	}
	type acc struct{ got, max float64 }
	got := map[key]acc{}
	var examGot, examMax float64
	examSet := false
	for _, it := range items {
		if it.Score == nil {
			continue
		}
		if math.IsNaN(*it.Score) || math.IsNaN(it.Max) {
			return SubjectResult{}, errors.New("a mark is not a number")
		}
		if it.Max <= 0 {
			return SubjectResult{}, errors.New("the full mark must be more than zero")
		}
		if *it.Score < 0 || *it.Score > it.Max {
			return SubjectResult{}, errors.New("a mark is outside the allowed range")
		}
		if it.Component == Exam {
			examGot += *it.Score
			examMax += it.Max
			examSet = true
			continue
		}
		if !it.Component.CA() || (it.Half != 1 && it.Half != 2) {
			return SubjectResult{}, errors.New("that mark does not belong to a known part")
		}
		k := key{it.Component, it.Half}
		a := got[k]
		a.got += *it.Score
		a.max += it.Max
		got[k] = a
	}
	var mid, second float64
	for _, c := range []Component{Classwork, Quizzes, Tests, Assignments, Participation, Homework} {
		halfW := w.Of(c) / 2
		for _, half := range []int{1, 2} {
			a, ok := got[key{c, half}]
			if !ok || a.max == 0 {
				continue
			}
			ratio := a.got / a.max
			if ratio > 1 {
				ratio = 1
			}
			part := Round2(ratio * halfW)
			if half == 1 {
				mid += part
			} else {
				second += part
			}
		}
	}
	mid = Round2(mid)
	if mid > 30 {
		mid = 30
	}
	cont := Round2(mid + second)
	if cont > 60 {
		cont = 60
	}
	var exam float64
	if examSet && examMax > 0 {
		exam = Round2(examGot / examMax * 40)
		if exam > 40 {
			exam = 40
		}
	}
	total := Round2(cont + exam)
	if total > 100 {
		total = 100
	}
	return SubjectResult{
		Mid:        mid,
		Continuous: cont,
		Exam:       exam,
		Total:      total,
		ExamSet:    examSet,
		Passed:     total > 50,
	}, nil
}

func Round2(x float64) float64 {
	if math.IsNaN(x) || math.IsInf(x, 0) {
		return 0
	}
	return math.Round(x*100) / 100
}

func F(v float64) *float64 { return &v }
