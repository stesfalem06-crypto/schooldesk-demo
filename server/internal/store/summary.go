package store

import "schooldesk/internal/domain"

type GradeMoney struct {
	Grade     int     `json:"grade"`
	Name      string  `json:"name"`
	Classes   int     `json:"classes"`
	Students  int     `json:"students"`
	Collected float64 `json:"collected"`
	Remaining float64 `json:"remaining"`
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
	classCount := map[int]int{}
	for _, c := range classes {
		classGrade[c.ID] = c.Grade
		classCount[c.Grade]++
	}
	studentGrade := map[string]int{}
	for _, st := range students {
		studentGrade[st.ID] = classGrade[st.ClassID]
	}
	by := map[int]*GradeMoney{}
	var order []int
	var out FeeSummary
	for _, row := range rows {
		grade := studentGrade[row.StudentID]
		g := by[grade]
		if g == nil {
			g = &GradeMoney{Grade: grade, Name: gradeName(grade), Classes: classCount[grade]}
			by[grade] = g
			order = append(order, grade)
		}
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
			g = &GradeStanding{Grade: c.Grade, Name: gradeName(c.Grade)}
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

func gradeName(grade int) string {
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
