// Package engine is the school timetable solver.
// Days and periods are 0-based. breakAfter is the 0-based period the single
// break follows. A user who says "period 1" or "break after period 4" means
// index 0 and breakAfter 3.
package engine

import (
	"encoding/json"
	"fmt"
	"sort"
	"strings"
)

const (
	PreferAny       = "ANY"
	PreferMorning   = "MORNING"
	PreferAfternoon = "AFTERNOON"
	RoomAny         = "ANY"
	RoomClassroom   = "CLASSROOM"
	RoomLab         = "LAB"
	RoomICT         = "ICT"
	LevelOff        = "OFF"
	LevelLow        = "LOW"
	LevelMedium     = "MEDIUM"
	LevelHigh       = "HIGH"
	HomeroomOff     = "OFF"
	HomeroomPrefer  = "PREFER"
	HomeroomRequire = "REQUIRE"
	StreamScience   = "SCIENCE"
	StreamArt       = "ART"
	SeverityProblem = "PROBLEM"
	SeveritySuggest = "SUGGESTION"
)

func LevelWeight(level string) int {
	switch level {
	case LevelLow:
		return 2
	case LevelMedium:
		return 6
	case LevelHigh:
		return 12
	default:
		return 0
	}
}

type DayDef struct {
	Name  string `json:"name"`
	Short string `json:"short"`
}

type Slot struct {
	Day    int `json:"day"`
	Period int `json:"period"`
}

type OffPattern struct {
	DaysOff    []int  `json:"daysOff"`
	PeriodsOff []int  `json:"periodsOff"`
	SlotsOff   []Slot `json:"slotsOff"`
}

func (o OffPattern) Blocks(day, period int) bool {
	for _, d := range o.DaysOff {
		if d == day {
			return true
		}
	}
	for _, p := range o.PeriodsOff {
		if p == period {
			return true
		}
	}
	for _, s := range o.SlotsOff {
		if s.Day == day && s.Period == period {
			return true
		}
	}
	return false
}

func (o OffPattern) WithoutSlot(slot Slot) OffPattern {
	next := o
	kept := make([]Slot, 0, len(o.SlotsOff))
	for _, s := range o.SlotsOff {
		if s != slot {
			kept = append(kept, s)
		}
	}
	next.SlotsOff = kept
	return next
}

func (o OffPattern) WithoutDay(day int) OffPattern {
	next := o
	days := make([]int, 0, len(o.DaysOff))
	for _, d := range o.DaysOff {
		if d != day {
			days = append(days, d)
		}
	}
	slots := make([]Slot, 0, len(o.SlotsOff))
	for _, s := range o.SlotsOff {
		if s.Day != day {
			slots = append(slots, s)
		}
	}
	next.DaysOff = days
	next.SlotsOff = slots
	return next
}

func OpenSlotCount(dayCount, periodCount int, offs ...OffPattern) int {
	open := 0
	for day := 0; day < dayCount; day++ {
		for period := 0; period < periodCount; period++ {
			blocked := false
			for _, off := range offs {
				if off.Blocks(day, period) {
					blocked = true
					break
				}
			}
			if !blocked {
				open++
			}
		}
	}
	return open
}

type BellSchedule struct {
	PeriodCount   int  `json:"periodCount"`
	StartMinutes  int  `json:"startMinutes"`
	PeriodMinutes int  `json:"periodMinutes"`
	BreakAfter    *int `json:"breakAfter"`
	BreakMinutes  int  `json:"breakMinutes"`
}

func (b BellSchedule) EffectiveBreakAfter() *int {
	if b.BreakAfter == nil {
		return nil
	}
	v := *b.BreakAfter
	if v >= 0 && v < b.PeriodCount-1 {
		return &v
	}
	return nil
}

type PeriodInfo struct {
	Index int
	Label string
	Start string
	End   string
}

func clock(minutes int) string {
	if minutes < 0 {
		minutes = 0
	}
	if minutes > 24*60-1 {
		minutes = 24*60 - 1
	}
	return fmt.Sprintf("%02d:%02d", minutes/60, minutes%60)
}

func (b BellSchedule) Periods() []PeriodInfo {
	cursor := b.StartMinutes
	split := b.EffectiveBreakAfter()
	out := make([]PeriodInfo, 0, b.PeriodCount)
	for index := 0; index < b.PeriodCount; index++ {
		start := cursor
		end := cursor + b.PeriodMinutes
		cursor = end
		if split != nil && *split == index {
			cursor += b.BreakMinutes
		}
		out = append(out, PeriodInfo{Index: index, Label: fmt.Sprintf("%d", index+1), Start: clock(start), End: clock(end)})
	}
	return out
}

type SchoolClass struct {
	ID                string     `json:"id"`
	Grade             int        `json:"grade"`
	Section           int        `json:"section"`
	HomeroomTeacherID *string    `json:"homeroomTeacherId"`
	Stream            *string    `json:"stream"`
	Off               OffPattern `json:"off"`
}

func (c SchoolClass) Label() string { return fmt.Sprintf("%d-%d", c.Grade, c.Section) }

func (c SchoolClass) TimetableName() string {
	if c.Stream == nil || *c.Stream == "" {
		return c.Label()
	}
	title := "Science"
	if *c.Stream == StreamArt {
		title = "Art"
	}
	return c.Label() + " (" + title + ")"
}

type Subject struct {
	ID        string     `json:"id"`
	Name      string     `json:"name"`
	Short     string     `json:"short"`
	Color     int        `json:"color"`
	Preferred string     `json:"preferred"`
	RoomKind  string     `json:"roomKind"`
	Off       OffPattern `json:"off"`
}

type Teacher struct {
	ID    string     `json:"id"`
	Name  string     `json:"name"`
	Short string     `json:"short"`
	Off   OffPattern `json:"off"`
}

type Room struct {
	ID   string     `json:"id"`
	Name string     `json:"name"`
	Kind string     `json:"kind"`
	Off  OffPattern `json:"off"`
}

type Lesson struct {
	ID           string  `json:"id"`
	ClassID      string  `json:"classId"`
	SubjectID    string  `json:"subjectId"`
	TeacherID    string  `json:"teacherId"`
	RoomID       *string `json:"roomId"`
	TimesPerWeek int     `json:"timesPerWeek"`
	Duration     int     `json:"duration"`
}

type Curriculum struct {
	Grade     int     `json:"grade"`
	SubjectID string  `json:"subjectId"`
	Singles   int     `json:"singles"`
	Doubles   int     `json:"doubles"`
	Stream    *string `json:"stream"`
}

type Rules struct {
	Spread             string `json:"spread"`
	AvoidSameDayRepeat string `json:"avoidSameDayRepeat"`
	BalanceTeacherLoad string `json:"balanceTeacherLoad"`
	LimitConsecutive   string `json:"limitConsecutive"`
	MaxConsecutive     int    `json:"maxConsecutive"`
	PreferredTime      string `json:"preferredTime"`
	HomeroomFirst      string `json:"homeroomFirst"`
	MaxLessonsPerDay   int    `json:"maxLessonsPerDay"`
	MaxLessonsStrict   bool   `json:"maxLessonsStrict"`
}

type Placement struct {
	LessonID string  `json:"lessonId"`
	Instance int     `json:"instance"`
	Day      int     `json:"day"`
	Period   int     `json:"period"`
	RoomID   *string `json:"roomId"`
	Locked   bool    `json:"locked"`
}

type Timetable struct {
	Placements         []Placement `json:"placements"`
	SoftScore          int         `json:"softScore"`
	Summary            string      `json:"summary"`
	GeneratedAtEpochMs int64       `json:"generatedAtEpochMs"`
}

type LevelGroups struct {
	Elementary []int `json:"elementary"`
	Junior     []int `json:"junior"`
	High       []int `json:"high"`
}

type School struct {
	Name                      string        `json:"name"`
	Days                      []DayDef      `json:"days"`
	Bell                      BellSchedule  `json:"bell"`
	SchoolOff                 OffPattern    `json:"schoolOff"`
	Classes                   []SchoolClass `json:"classes"`
	Subjects                  []Subject     `json:"subjects"`
	Teachers                  []Teacher     `json:"teachers"`
	Rooms                     []Room        `json:"rooms"`
	Curriculum                []Curriculum  `json:"curriculum"`
	Lessons                   []Lesson      `json:"lessons"`
	Rules                     Rules         `json:"rules"`
	Timetable                 *Timetable    `json:"timetable"`
	SetupComplete             bool          `json:"setupComplete"`
	Levels                    LevelGroups   `json:"levels"`
	ShareMathAcrossStreams    *bool         `json:"shareMathAcrossStreams"`
	ShareEnglishAcrossStreams *bool         `json:"shareEnglishAcrossStreams"`
	SharedMathTeacherName     *string       `json:"sharedMathTeacherName"`
	SharedEnglishTeacherName  *string       `json:"sharedEnglishTeacherName"`
}

func ParseSchool(raw []byte) (School, error) {
	var school School
	if err := json.Unmarshal(raw, &school); err != nil {
		return School{}, err
	}
	return school, nil
}

func (s School) ClassByID(id string) *SchoolClass {
	for i := range s.Classes {
		if s.Classes[i].ID == id {
			return &s.Classes[i]
		}
	}
	return nil
}

func (s School) SubjectByID(id string) *Subject {
	for i := range s.Subjects {
		if s.Subjects[i].ID == id {
			return &s.Subjects[i]
		}
	}
	return nil
}

func (s School) TeacherByID(id string) *Teacher {
	for i := range s.Teachers {
		if s.Teachers[i].ID == id {
			return &s.Teachers[i]
		}
	}
	return nil
}

func (s School) RoomByID(id string) *Room {
	for i := range s.Rooms {
		if s.Rooms[i].ID == id {
			return &s.Rooms[i]
		}
	}
	return nil
}

func (s School) LessonByID(id string) *Lesson {
	for i := range s.Lessons {
		if s.Lessons[i].ID == id {
			return &s.Lessons[i]
		}
	}
	return nil
}

func (s School) ClassesInOrder() []SchoolClass {
	out := append([]SchoolClass(nil), s.Classes...)
	sort.SliceStable(out, func(i, j int) bool {
		if out[i].Grade != out[j].Grade {
			return out[i].Grade < out[j].Grade
		}
		return out[i].Section < out[j].Section
	})
	return out
}

func (s School) DayName(day int) string {
	if day >= 0 && day < len(s.Days) {
		return s.Days[day].Name
	}
	return "that day"
}

type Mark struct {
	ClassID string `json:"classId"`
	Day     int    `json:"day"`
	Period  int    `json:"period"`
}

type Fix struct {
	Kind          string  `json:"kind"`
	LessonID      string  `json:"lessonId,omitempty"`
	Instance      int     `json:"instance,omitempty"`
	Day           int     `json:"day,omitempty"`
	Period        int     `json:"period,omitempty"`
	RoomID        *string `json:"roomId,omitempty"`
	OtherLessonID string  `json:"otherLessonId,omitempty"`
	OtherInstance int     `json:"otherInstance,omitempty"`
	NewTimes      int     `json:"newTimes,omitempty"`
	Slot          *Slot   `json:"slot,omitempty"`
	TeacherID     string  `json:"teacherId,omitempty"`
	ClassID       string  `json:"classId,omitempty"`
	SubjectID     string  `json:"subjectId,omitempty"`
	NewMax        int     `json:"newMax,omitempty"`
	Strict        bool    `json:"strict,omitempty"`
}

const (
	FixMove             = "Move"
	FixSwap             = "Swap"
	FixReduceTimes      = "ReduceTimes"
	FixClearSchoolSlot  = "ClearSchoolSlot"
	FixClearTeacherDay  = "ClearTeacherDay"
	FixClearTeacherSlot = "ClearTeacherSlot"
	FixClearClassSlot   = "ClearClassSlot"
	FixClearSubjectSlot = "ClearSubjectSlot"
	FixClearRoomSlot    = "ClearRoomSlot"
	FixDropRoomNeed     = "DropRoomNeed"
	FixRaiseMaxLessons  = "RaiseMaxLessons"
	FixSetMaxStrict     = "SetMaxStrict"
)

type Issue struct {
	Severity   string `json:"severity"`
	Title      string `json:"title"`
	Detail     string `json:"detail"`
	Suggestion string `json:"suggestion"`
	Fix        *Fix   `json:"fix,omitempty"`
	Marks      []Mark `json:"marks,omitempty"`
}

type SolveOptions struct {
	Seed         int64
	TimeBudgetMs int64
	Locks        []Placement
}

func (o SolveOptions) withDefaults() SolveOptions {
	if o.Seed == 0 {
		o.Seed = 1
	}
	if o.TimeBudgetMs == 0 {
		o.TimeBudgetMs = 3500
	}
	return o
}

type SolveResult struct {
	OK            bool
	Timetable     *Timetable
	Issues        []Issue
	Placed        int
	Expected      int
	HardConflicts int
	SoftScore     int
}

type MovePreview struct {
	Allowed      bool
	Reason       string
	RoomID       *string
	SwapLessonID string
	SwapInstance int
	HasSwap      bool
}

func problem(title, detail, suggestion string, fix *Fix, marks []Mark) Issue {
	return Issue{Severity: SeverityProblem, Title: title, Detail: detail, Suggestion: suggestion, Fix: fix, Marks: marks}
}

func suggestion(title, detail, suggestionText string, fix *Fix, marks []Mark) Issue {
	return Issue{Severity: SeveritySuggest, Title: title, Detail: detail, Suggestion: suggestionText, Fix: fix, Marks: marks}
}

func joinNames(parts []string) string {
	return strings.Join(parts, " and ")
}
