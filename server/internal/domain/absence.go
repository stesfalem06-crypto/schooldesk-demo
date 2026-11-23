package domain

import (
	"errors"
	"time"
)

type MonthInput struct {
	Year          int
	Month         time.Month
	SchoolDays    []time.Weekday
	Periods       map[time.Weekday]int
	Absent        []time.Time
	MakeupClasses int
	MakeupPeriods int
}

type MonthReport struct {
	AbsentDays         int     `json:"absent_days"`
	Weeks              int     `json:"weeks"`
	AbsenteeismPerWeek float64 `json:"absenteeism_per_week"`
	Scheduled          int     `json:"scheduled"`
	MissedPeriods      int     `json:"missed_periods"`
	MakeupClasses      int     `json:"makeup_classes"`
	MakeupPeriods      int     `json:"makeup_periods"`
	LostPeriods        int     `json:"lost_periods"`
	LostPerWeek        float64 `json:"lost_per_week"`
	PercentLost        float64 `json:"percent_lost"`
}

// Absence counts a month from the teacher's weekly periods.
// Absenteeism per week is absent school days divided by school weeks.
// Lost periods are missed timetable periods minus make-up periods, and never below zero.
// The percentage is lost periods divided by scheduled periods.
func Absence(in MonthInput) (MonthReport, error) {
	if in.Year < 2000 || in.Month < 1 || in.Month > 12 {
		return MonthReport{}, errors.New("that month is not valid")
	}
	if in.MakeupClasses < 0 || in.MakeupPeriods < 0 {
		return MonthReport{}, errors.New("make-up classes cannot be negative")
	}
	school := map[time.Weekday]bool{}
	for _, d := range in.SchoolDays {
		school[d] = true
	}
	absent := map[string]bool{}
	for _, d := range in.Absent {
		absent[dayKey(d)] = true
	}
	var rep MonthReport
	rep.MakeupClasses = in.MakeupClasses
	rep.MakeupPeriods = in.MakeupPeriods
	weeks := map[[2]int]struct{}{}
	start := time.Date(in.Year, in.Month, 1, 0, 0, 0, 0, time.UTC)
	for d := start; d.Month() == in.Month; d = d.AddDate(0, 0, 1) {
		if !school[d.Weekday()] {
			continue
		}
		y, w := d.ISOWeek()
		weeks[[2]int{y, w}] = struct{}{}
		p := in.Periods[d.Weekday()]
		if p < 0 {
			p = 0
		}
		rep.Scheduled += p
		if absent[dayKey(d)] {
			rep.AbsentDays++
			rep.MissedPeriods += p
		}
	}
	rep.Weeks = len(weeks)
	rep.LostPeriods = rep.MissedPeriods - rep.MakeupPeriods
	if rep.LostPeriods < 0 {
		rep.LostPeriods = 0
	}
	if rep.Weeks > 0 {
		rep.AbsenteeismPerWeek = Round2(float64(rep.AbsentDays) / float64(rep.Weeks))
		rep.LostPerWeek = Round2(float64(rep.LostPeriods) / float64(rep.Weeks))
	}
	if rep.Scheduled > 0 {
		rep.PercentLost = Round2(float64(rep.LostPeriods) / float64(rep.Scheduled) * 100)
	}
	return rep, nil
}

func dayKey(t time.Time) string {
	t = t.UTC()
	return t.Format("2006-01-02")
}
