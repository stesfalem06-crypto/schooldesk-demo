package store

import (
	"strings"

	"schooldesk/internal/domain"
)

type FeeSection struct {
	ID        string  `json:"id"`
	Name      string  `json:"name"`
	Students  int     `json:"students"`
	Collected float64 `json:"collected"`
	Remaining float64 `json:"remaining"`
}

type GradeMoney struct {
	Grade     int          `json:"grade"`
	Name      string       `json:"name"`
	Classes   int          `json:"classes"`
	Students  int          `json:"students"`
	Collected float64      `json:"collected"`
	Remaining float64      `json:"remaining"`
	Sections  []FeeSection `json:"sections"`
}

type FeeSummary struct {
	Grades    []GradeMoney `json:"grades"`
	Students  int          `json:"students"`
	Collected float64      `json:"collected"`
	Remaining float64      `json:"remaining"`
}

type SectionStanding struct {
	ID       string `json:"id"`
	Name     string `json:"name"`
	Students int    `json:"students"`
	Promoted int    `json:"promoted"`
	Failed   int    `json:"failed"`
	Dropouts int    `json:"dropouts"`
}

type GradeStanding struct {
	Grade    int               `json:"grade"`
	Name     string            `json:"name"`
	Students int               `json:"students"`
	Promoted int               `json:"promoted"`
	Failed   int               `json:"failed"`
	Dropouts int               `json:"dropouts"`
	Sections []SectionStanding `json:"sections"`
}

type StandingSummary struct {
	Grades   []GradeStanding `json:"grades"`
	Students int             `json:"students"`
	Promoted int             `json:"promoted"`
	Failed   int             `json:"failed"`
	Dropouts int             `json:"dropouts"`
}

func (s *Store) FeeSummary() (FeeSummary, error) {
	classes, err := s.ListClasses()
	if err != nil {
		return FeeSummary{}, err
	}
	students, err := s.ListStudents("")
	if err != nil {
		return FeeSummary{}, err
	}
	settings, err := s.Settings()
	if err != nil {
		return FeeSummary{}, err
	}
	rows, err := s.FeeRows("", settings.AcademicYear)
	if err != nil {
		return FeeSummary{}, err
	}
	classGrade := map[string]int{}
	className := map[string]string{}
	classCount := map[int]int{}
	for _, c := range classes {
		classGrade[c.ID] = c.Grade
		className[c.ID] = c.Name
		classCount[c.Grade]++
	}
	studentClass := map[string]string{}
	for _, st := range students {
		studentClass[st.ID] = st.ClassID
	}
	labels := settings.GradeLabels
	by := map[int]*GradeMoney{}
	type secAt struct{ grade, index int }
	where := map[string]secAt{}
	var order []int
	var out FeeSummary
	for _, row := range rows {
		classID := studentClass[row.StudentID]
		grade := classGrade[classID]
		g := by[grade]
		if g == nil {
			g = &GradeMoney{Grade: grade, Name: gradeTitle(grade, labels), Classes: classCount[grade]}
			by[grade] = g
			order = append(order, grade)
		}
		at, ok := where[classID]
		if !ok {
			g.Sections = append(g.Sections, FeeSection{ID: classID, Name: className[classID]})
			at = secAt{grade, len(g.Sections) - 1}
			where[classID] = at
		}
		sec := &by[at.grade].Sections[at.index]
		sec.Students++
		sec.Collected = domain.Round2(sec.Collected + row.Paid)
		sec.Remaining = domain.Round2(sec.Remaining + row.Remaining)
		g.Students++
		g.Collected = domain.Round2(g.Collected + row.Paid)
		g.Remaining = domain.Round2(g.Remaining + row.Remaining)
		out.Students++
		out.Collected = domain.Round2(out.Collected + row.Paid)
		out.Remaining = domain.Round2(out.Remaining + row.Remaining)
	}
	for _, grade := range order {
		out.Grades = append(out.Grades, *by[grade])
	}
	if out.Grades == nil {
		out.Grades = []GradeMoney{}
	}
	return out, nil
}

func (s *Store) StandingSummary() (StandingSummary, error) {
	classes, err := s.ListClasses()
	if err != nil {
		return StandingSummary{}, err
	}
	settings, err := s.Settings()
	if err != nil {
		return StandingSummary{}, err
	}
	labels := settings.GradeLabels
	by := map[int]*GradeStanding{}
	var order []int
	var out StandingSummary
	for _, c := range classes {
		stat, err := s.Promotion(c.ID, settings.Semester)
		if err != nil {
			return StandingSummary{}, err
		}
		g := by[c.Grade]
		if g == nil {
			g = &GradeStanding{Grade: c.Grade, Name: gradeTitle(c.Grade, labels)}
			by[c.Grade] = g
			order = append(order, c.Grade)
		}
		section := SectionStanding{
			ID: c.ID, Name: c.Name, Students: stat.Head.Students,
			Promoted: stat.Promoted, Failed: stat.Failed, Dropouts: stat.Head.Dropped,
		}
		g.Sections = append(g.Sections, section)
		g.Students += section.Students
		g.Promoted += section.Promoted
		g.Failed += section.Failed
		g.Dropouts += section.Dropouts
		out.Students += section.Students
		out.Promoted += section.Promoted
		out.Failed += section.Failed
		out.Dropouts += section.Dropouts
	}
	for _, grade := range order {
		out.Grades = append(out.Grades, *by[grade])
	}
	if out.Grades == nil {
		out.Grades = []GradeStanding{}
	}
	return out, nil
}

func gradeTitle(grade int, labels string) string {
	for _, line := range strings.Split(labels, "\n") {
		parts := strings.SplitN(strings.TrimSpace(line), "=", 2)
		if len(parts) == 2 && parts[0] == itoaSmall(grade) {
			name := strings.TrimSpace(parts[1])
			if name != "" {
				return name
			}
		}
	}
	if grade <= 0 {
		return "Grade"
	}
	return "Grade " + itoaSmall(grade)
}

func itoaSmall(n int) string {
	if n < 10 {
		return string(rune('0' + n))
	}
	return string(rune('0'+n/10)) + string(rune('0'+n%10))
}
