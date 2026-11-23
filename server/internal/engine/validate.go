package engine

import "strings"

// Analyze reports problems that stop a solve before any placement.
func Analyze(school School) []Issue {
	var issues []Issue
	days := len(school.Days)
	periods := school.Bell.PeriodCount
	if days == 0 || periods == 0 {
		issues = append(issues, problem(
			"The week has no teaching time",
			"Choose at least one day and one period.",
			"Open the week setup and add days and periods.",
			nil, nil,
		))
		return issues
	}
	for _, cls := range school.ClassesInOrder() {
		var classLessons []Lesson
		demand := 0
		for _, lesson := range school.Lessons {
			if lesson.ClassID != cls.ID {
				continue
			}
			classLessons = append(classLessons, lesson)
			demand += lesson.TimesPerWeek * lesson.Duration
		}
		open := OpenSlotCount(days, periods, school.SchoolOff, cls.Off)
		if demand > open {
			biggest, subject := biggestLesson(school, classLessons)
			excess := demand - open
			step := 1
			if biggest != nil && biggest.Duration > 1 {
				step = biggest.Duration
			}
			reduceBy := (excess + step - 1) / step
			var fix *Fix
			if biggest != nil {
				times := biggest.TimesPerWeek - reduceBy
				if times < 0 {
					times = 0
				}
				fix = &Fix{Kind: FixReduceTimes, LessonID: biggest.ID, NewTimes: times}
			}
			if subject == "" {
				subject = "a subject"
			}
			issues = append(issues, problem(
				cls.Label()+" has too many lessons",
				sprintfDemand(cls.Label(), demand, open),
				"Lower "+subject+", clear a time off, or add a period to the day.",
				fix, nil,
			))
		}
	}
	byTeacher := map[string][]Lesson{}
	var teacherOrder []string
	for _, lesson := range school.Lessons {
		if _, ok := byTeacher[lesson.TeacherID]; !ok {
			teacherOrder = append(teacherOrder, lesson.TeacherID)
		}
		byTeacher[lesson.TeacherID] = append(byTeacher[lesson.TeacherID], lesson)
	}
	for _, teacherID := range teacherOrder {
		teacher := school.TeacherByID(teacherID)
		if teacher == nil {
			continue
		}
		lessons := byTeacher[teacherID]
		demand := 0
		for _, lesson := range lessons {
			demand += lesson.TimesPerWeek * lesson.Duration
		}
		open := OpenSlotCount(days, periods, school.SchoolOff, teacher.Off)
		if demand > open {
			biggest, subject := biggestLesson(school, lessons)
			cls := "a class"
			if biggest != nil {
				if c := school.ClassByID(biggest.ClassID); c != nil {
					cls = c.Label()
				}
			}
			if subject == "" {
				subject = "a subject"
			}
			excess := demand - open
			step := 1
			if biggest != nil && biggest.Duration > 1 {
				step = biggest.Duration
			}
			reduceBy := (excess + step - 1) / step
			var fix *Fix
			if len(teacher.Off.DaysOff) > 0 {
				day := teacher.Off.DaysOff[0]
				for _, d := range teacher.Off.DaysOff {
					if d < day {
						day = d
					}
				}
				fix = &Fix{Kind: FixClearTeacherDay, TeacherID: teacher.ID, Day: day}
			} else if biggest != nil {
				times := biggest.TimesPerWeek - reduceBy
				if times < 0 {
					times = 0
				}
				fix = &Fix{Kind: FixReduceTimes, LessonID: biggest.ID, NewTimes: times}
			}
			issues = append(issues, problem(
				teacher.Name+" is booked past their free time",
				teacher.Name+" has "+itoa(demand)+" periods, but only "+itoa(open)+" are open.",
				"Reassign "+subject+" for "+cls+", or clear some time off.",
				fix, nil,
			))
		}
	}
	for _, room := range school.Rooms {
		demand := 0
		for _, lesson := range school.Lessons {
			if lesson.RoomID != nil && *lesson.RoomID == room.ID {
				demand += lesson.TimesPerWeek * lesson.Duration
			}
		}
		open := OpenSlotCount(days, periods, school.SchoolOff, room.Off)
		if demand > open {
			issues = append(issues, problem(
				room.Name+" is overbooked",
				room.Name+" is asked for "+itoa(demand)+" periods, but only "+itoa(open)+" are open.",
				"Use another room, or clear time off for this room.",
				nil, nil,
			))
		}
	}
	for _, kind := range []string{RoomLab, RoomICT} {
		var pool []Room
		for _, room := range school.Rooms {
			if room.Kind == kind {
				pool = append(pool, room)
			}
		}
		if len(pool) == 0 {
			continue
		}
		var flexible []Lesson
		for _, lesson := range school.Lessons {
			if lesson.RoomID != nil {
				continue
			}
			subject := school.SubjectByID(lesson.SubjectID)
			if subject != nil && subject.RoomKind == kind {
				flexible = append(flexible, lesson)
			}
		}
		demand := 0
		for _, lesson := range flexible {
			demand += lesson.TimesPerWeek * lesson.Duration
		}
		supply := 0
		for _, room := range pool {
			fixed := 0
			for _, lesson := range school.Lessons {
				if lesson.RoomID != nil && *lesson.RoomID == room.ID {
					fixed += lesson.TimesPerWeek * lesson.Duration
				}
			}
			spare := OpenSlotCount(days, periods, school.SchoolOff, room.Off) - fixed
			if spare > 0 {
				supply += spare
			}
		}
		if demand > supply {
			bestID := ""
			bestN := -1
			seen := map[string]int{}
			for _, lesson := range flexible {
				seen[lesson.SubjectID] += lesson.TimesPerWeek * lesson.Duration
			}
			for id, n := range seen {
				if n > bestN {
					bestN = n
					bestID = id
				}
			}
			var subject *Subject
			if bestID != "" {
				subject = school.SubjectByID(bestID)
			}
			label := "lab"
			if kind == RoomICT {
				label = "ICT lab"
			}
			name := "one subject"
			var fix *Fix
			if subject != nil {
				name = subject.Name
				fix = &Fix{Kind: FixDropRoomNeed, SubjectID: subject.ID}
			}
			issues = append(issues, problem(
				"Not enough "+label+"s",
				"Lessons need "+itoa(demand)+" "+label+" periods, and the rooms only have "+itoa(supply)+" open.",
				"Add another "+label+", or stop requiring a special room for "+name+".",
				fix, nil,
			))
		}
	}
	for _, lesson := range school.Lessons {
		if strings.TrimSpace(lesson.TeacherID) == "" || school.TeacherByID(lesson.TeacherID) == nil {
			cls := "A class"
			if c := school.ClassByID(lesson.ClassID); c != nil {
				cls = c.Label()
			}
			subject := "a lesson"
			if s := school.SubjectByID(lesson.SubjectID); s != nil {
				subject = s.Name
			}
			issues = append(issues, problem(
				subject+" for "+cls+" has no teacher",
				"Every lesson needs exactly one teacher.",
				"Choose a teacher for this lesson.",
				nil, nil,
			))
		}
		if lesson.Duration == 2 && !hasDoubleSlot(school, lesson) {
			cls := "the class"
			if c := school.ClassByID(lesson.ClassID); c != nil {
				cls = c.Label()
			}
			subject := "This subject"
			if s := school.SubjectByID(lesson.SubjectID); s != nil {
				subject = s.Name
			}
			issues = append(issues, problem(
				subject+" for "+cls+" cannot be a double",
				"A double needs two periods in a row that are open and do not cross the break.",
				"Change it to single periods, or move the break.",
				&Fix{Kind: FixReduceTimes, LessonID: lesson.ID, NewTimes: lesson.TimesPerWeek},
				nil,
			))
		}
	}
	return issues
}

func biggestLesson(school School, lessons []Lesson) (*Lesson, string) {
	var best *Lesson
	bestN := -1
	for i := range lessons {
		n := lessons[i].TimesPerWeek * lessons[i].Duration
		if n > bestN {
			bestN = n
			best = &lessons[i]
		}
	}
	if best == nil {
		return nil, ""
	}
	if s := school.SubjectByID(best.SubjectID); s != nil {
		return best, s.Name
	}
	return best, ""
}

func sprintfDemand(label string, demand, open int) string {
	return label + " needs " + itoa(demand) + " periods, but only " + itoa(open) + " are open."
}

func hasDoubleSlot(school School, lesson Lesson) bool {
	cls := school.ClassByID(lesson.ClassID)
	if cls == nil {
		return false
	}
	subject := school.SubjectByID(lesson.SubjectID)
	teacher := school.TeacherByID(lesson.TeacherID)
	breakAfter := school.Bell.EffectiveBreakAfter()
	for day := range school.Days {
		for period := 0; period < school.Bell.PeriodCount-1; period++ {
			if breakAfter != nil && period == *breakAfter {
				continue
			}
			open := true
			for offset := 0; offset < 2; offset++ {
				at := period + offset
				if school.SchoolOff.Blocks(day, at) || cls.Off.Blocks(day, at) {
					open = false
					break
				}
				if subject != nil && subject.Off.Blocks(day, at) {
					open = false
					break
				}
				if teacher != nil && teacher.Off.Blocks(day, at) {
					open = false
					break
				}
			}
			if open {
				return true
			}
		}
	}
	return false
}

// Validate checks a saved week. It does not trust the search.
func Validate(school School, timetable *Timetable) []Issue {
	if timetable == nil {
		return []Issue{problem("There is no timetable yet", "Generate the week first.", "Ask the admin to build the week.", nil, nil)}
	}
	var issues []Issue
	days := len(school.Days)
	periods := school.Bell.PeriodCount
	breakAfter := school.Bell.EffectiveBreakAfter()
	classCells := map[string][]seat{}
	teacherCells := map[string][]seat{}
	roomCells := map[string][]seat{}
	seen := map[string]bool{}
	for _, placement := range timetable.Placements {
		lesson := school.LessonByID(placement.LessonID)
		if lesson == nil {
			continue
		}
		key := placement.LessonID + "#" + itoa(placement.Instance)
		if seen[key] {
			issues = append(issues, problem(
				"A lesson is saved twice",
				"One weekly lesson was placed more than once.",
				"Generate again.",
				nil,
				[]Mark{{ClassID: lesson.ClassID, Day: placement.Day, Period: placement.Period}},
			))
		}
		seen[key] = true
		if placement.Instance < 0 || placement.Instance >= lesson.TimesPerWeek {
			continue
		}
		if placement.Day < 0 || placement.Day >= days || placement.Period < 0 || placement.Period >= periods {
			day := placement.Day
			period := placement.Period
			if day < 0 {
				day = 0
			}
			if period < 0 {
				period = 0
			}
			issues = append(issues, problem(
				"A lesson sits outside the week",
				"It uses a day or period that is no longer in the week.",
				"Generate again after changing the week.",
				nil,
				[]Mark{{ClassID: lesson.ClassID, Day: day, Period: period}},
			))
			continue
		}
		if lesson.Duration == 2 && breakAfter != nil && placement.Period <= *breakAfter && placement.Period+lesson.Duration-1 > *breakAfter {
			cls := "A class"
			if c := school.ClassByID(lesson.ClassID); c != nil {
				cls = c.Label()
			}
			subject := "A lesson"
			if s := school.SubjectByID(lesson.SubjectID); s != nil {
				subject = s.Name
			}
			issues = append(issues, problem(
				subject+" for "+cls+" crosses the break",
				"Double lessons have to stay on one side of the break.",
				"Move it, or change it to two single lessons.",
				nil,
				[]Mark{{ClassID: lesson.ClassID, Day: placement.Day, Period: placement.Period}},
			))
		}
		one := seat{placement, *lesson}
		for offset := 0; offset < lesson.Duration; offset++ {
			period := placement.Period + offset
			if period < 0 || period >= periods {
				continue
			}
			mark := Mark{ClassID: lesson.ClassID, Day: placement.Day, Period: period}
			cls := school.ClassByID(lesson.ClassID)
			subject := school.SubjectByID(lesson.SubjectID)
			teacher := school.TeacherByID(lesson.TeacherID)
			var room *Room
			if placement.RoomID != nil {
				room = school.RoomByID(*placement.RoomID)
			}
			offReason := ""
			switch {
			case school.SchoolOff.Blocks(placement.Day, period):
				offReason = "The whole school is off in " + school.DayName(placement.Day) + " period " + itoa(period+1) + "."
			case cls != nil && cls.Off.Blocks(placement.Day, period):
				offReason = cls.Label() + " is off in " + school.DayName(placement.Day) + " period " + itoa(period+1) + "."
			case subject != nil && subject.Off.Blocks(placement.Day, period):
				offReason = subject.Name + " is off in " + school.DayName(placement.Day) + " period " + itoa(period+1) + "."
			case teacher != nil && teacher.Off.Blocks(placement.Day, period):
				offReason = teacher.Name + " is off in " + school.DayName(placement.Day) + " period " + itoa(period+1) + "."
			case room != nil && room.Off.Blocks(placement.Day, period):
				offReason = room.Name + " is off in " + school.DayName(placement.Day) + " period " + itoa(period+1) + "."
			}
			if offReason != "" {
				issues = append(issues, problem(
					"A lesson is on a closed time",
					offReason,
					"Move it to an open period.",
					nil,
					[]Mark{mark},
				))
			}
			ck := lesson.ClassID + "|" + itoa(placement.Day) + "|" + itoa(period)
			classCells[ck] = append(classCells[ck], one)
			if lesson.TeacherID != "" {
				tk := lesson.TeacherID + "|" + itoa(placement.Day) + "|" + itoa(period)
				teacherCells[tk] = append(teacherCells[tk], one)
			}
			if placement.RoomID != nil {
				rk := *placement.RoomID + "|" + itoa(placement.Day) + "|" + itoa(period)
				roomCells[rk] = append(roomCells[rk], one)
			}
		}
	}
	issues = append(issues, clashIssues(school, classCells, func(id string) string {
		if c := school.ClassByID(id); c != nil {
			return c.Label() + " is double booked"
		}
		return "A class is double booked"
	}, func(seats []seat, day, period int) string {
		names := make([]string, len(seats))
		for i, s := range seats {
			names[i] = "a lesson"
			if sub := school.SubjectByID(s.lesson.SubjectID); sub != nil {
				names[i] = sub.Name
			}
		}
		return joinNames(names) + " both fall in " + school.DayName(day) + " period " + itoa(period+1) + "."
	})...)
	issues = append(issues, clashIssues(school, teacherCells, func(id string) string {
		if t := school.TeacherByID(id); t != nil {
			return t.Name + " is in two places"
		}
		return "A teacher is in two places"
	}, func(seats []seat, day, period int) string {
		parts := make([]string, len(seats))
		for i, s := range seats {
			cls := "a class"
			if c := school.ClassByID(s.lesson.ClassID); c != nil {
				cls = c.Label()
			}
			subject := "a lesson"
			if sub := school.SubjectByID(s.lesson.SubjectID); sub != nil {
				subject = sub.Name
			}
			parts[i] = cls + " " + subject
		}
		return joinNames(parts) + " overlap on " + school.DayName(day) + " period " + itoa(period+1) + "."
	})...)
	issues = append(issues, clashIssues(school, roomCells, func(id string) string {
		if r := school.RoomByID(id); r != nil {
			return r.Name + " is double booked"
		}
		return "A room is double booked"
	}, func(seats []seat, day, period int) string {
		parts := make([]string, len(seats))
		for i, s := range seats {
			parts[i] = "a class"
			if c := school.ClassByID(s.lesson.ClassID); c != nil {
				parts[i] = c.Label()
			}
		}
		return joinNames(parts) + " both use it on " + school.DayName(day) + " period " + itoa(period+1) + "."
	})...)

	for _, lesson := range school.Lessons {
		count := 0
		for _, placement := range timetable.Placements {
			if placement.LessonID == lesson.ID && placement.Instance >= 0 && placement.Instance < lesson.TimesPerWeek {
				count++
			}
		}
		if count < lesson.TimesPerWeek {
			cls := "A class"
			if c := school.ClassByID(lesson.ClassID); c != nil {
				cls = c.Label()
			}
			subject := "A subject"
			if s := school.SubjectByID(lesson.SubjectID); s != nil {
				subject = s.Name
			}
			missing := lesson.TimesPerWeek - count
			word := "lesson"
			if lesson.Duration == 2 {
				word = "double lesson"
			}
			if missing != 1 {
				word += "s"
			}
			teacher := "the teacher"
			if t := school.TeacherByID(lesson.TeacherID); t != nil {
				teacher = t.Name
			}
			issues = append(issues, problem(
				subject+" for "+cls+" is short by "+itoa(missing),
				"The week still needs "+itoa(missing)+" more "+word+".",
				"Generate again, or free a period for "+teacher+".",
				nil, nil,
			))
		}
	}
	if school.Rules.MaxLessonsStrict {
		load := teacherDailyLoad(school, timetable)
		for teacherID, daysLoad := range load {
			teacher := school.TeacherByID(teacherID)
			if teacher == nil {
				continue
			}
			for day, count := range daysLoad {
				if count > school.Rules.MaxLessonsPerDay {
					issues = append(issues, problem(
						teacher.Name+" has "+itoa(count)+" lessons on "+school.DayName(day),
						"The limit is "+itoa(school.Rules.MaxLessonsPerDay)+" lessons in a day.",
						"Move one lesson, or raise the daily limit.",
						&Fix{Kind: FixRaiseMaxLessons, NewMax: count},
						nil,
					))
				}
			}
		}
	}
	if school.Rules.HomeroomFirst == HomeroomRequire {
		issues = append(issues, homeroomIssues(school, timetable, SeverityProblem)...)
	}
	var suggestions []Issue
	if school.Rules.HomeroomFirst == HomeroomPrefer {
		suggestions = append(suggestions, homeroomIssues(school, timetable, SeveritySuggest)...)
	}
	if !school.Rules.MaxLessonsStrict {
		load := teacherDailyLoad(school, timetable)
		for teacherID, daysLoad := range load {
			teacher := school.TeacherByID(teacherID)
			if teacher == nil {
				continue
			}
			for day, count := range daysLoad {
				if count > school.Rules.MaxLessonsPerDay {
					suggestions = append(suggestions, suggestion(
						teacher.Name+" has a heavy "+school.DayName(day),
						itoa(count)+" lessons that day. The guide is "+itoa(school.Rules.MaxLessonsPerDay)+".",
						"Move one lesson to a lighter day, or raise the guide.",
						&Fix{Kind: FixRaiseMaxLessons, NewMax: count},
						nil,
					))
				}
			}
		}
	}
	suggestions = append(suggestions, distributionSuggestions(school, timetable)...)
	if len(suggestions) > 16 {
		suggestions = suggestions[:16]
	}
	return append(issues, suggestions...)
}

func clashIssues(school School, cells map[string][]seat, title func(string) string, detail func([]seat, int, int) string) []Issue {
	var issues []Issue
	for key, seats := range cells {
		unique := make([]seat, 0, len(seats))
		seen := map[string]bool{}
		for _, s := range seats {
			id := s.placement.LessonID + "#" + itoa(s.placement.Instance)
			if seen[id] {
				continue
			}
			seen[id] = true
			unique = append(unique, s)
		}
		if len(unique) < 2 {
			continue
		}
		parts := strings.Split(key, "|")
		day, period := 0, 0
		if len(parts) == 3 {
			day = atoi(parts[1])
			period = atoi(parts[2])
		}
		issues = append(issues, problem(title(parts[0]), detail(unique, day, period), "Move one of them to a free period.", nil, marksOf(unique, day, period)))
	}
	return issues
}

type seat struct {
	placement Placement
	lesson    Lesson
}

func marksOf(seats []seat, day, period int) []Mark {
	out := make([]Mark, len(seats))
	for i, s := range seats {
		out[i] = Mark{ClassID: s.lesson.ClassID, Day: day, Period: period}
	}
	return out
}

func atoi(s string) int {
	n := 0
	for _, c := range s {
		if c < '0' || c > '9' {
			return 0
		}
		n = n*10 + int(c-'0')
	}
	return n
}

func teacherDailyLoad(school School, timetable *Timetable) map[string][]int {
	load := map[string][]int{}
	for _, placement := range timetable.Placements {
		lesson := school.LessonByID(placement.LessonID)
		if lesson == nil || placement.Day < 0 || placement.Day >= len(school.Days) {
			continue
		}
		row := load[lesson.TeacherID]
		if row == nil {
			row = make([]int, len(school.Days))
			load[lesson.TeacherID] = row
		}
		row[placement.Day] += lesson.Duration
	}
	return load
}

func homeroomIssues(school School, timetable *Timetable, severity string) []Issue {
	var out []Issue
	for _, cls := range school.ClassesInOrder() {
		if cls.HomeroomTeacherID == nil {
			continue
		}
		teacher := school.TeacherByID(*cls.HomeroomTeacherID)
		if teacher == nil {
			continue
		}
		for day := range school.Days {
			if school.SchoolOff.Blocks(day, 0) || cls.Off.Blocks(day, 0) {
				continue
			}
			teachingToday := false
			var first *Placement
			for i := range timetable.Placements {
				placement := &timetable.Placements[i]
				lesson := school.LessonByID(placement.LessonID)
				if lesson == nil || lesson.ClassID != cls.ID || placement.Day != day {
					continue
				}
				if lesson.TeacherID == teacher.ID {
					teachingToday = true
				}
				if placement.Period == 0 && first == nil {
					cp := *placement
					first = &cp
				}
			}
			if !teachingToday {
				continue
			}
			if first != nil {
				if lesson := school.LessonByID(first.LessonID); lesson != nil && lesson.TeacherID == teacher.ID {
					continue
				}
			}
			issue := Issue{
				Severity:   severity,
				Title:      cls.Label() + " does not start with the homeroom teacher",
				Detail:     teacher.Name + " teaches " + cls.Label() + " on " + school.DayName(day) + ", but not in period 1.",
				Suggestion: "Swap one of their lessons into period 1.",
				Marks:      []Mark{{ClassID: cls.ID, Day: day, Period: 0}},
			}
			out = append(out, issue)
		}
	}
	return out
}

func distributionSuggestions(school School, timetable *Timetable) []Issue {
	if school.Rules.AvoidSameDayRepeat == LevelOff && school.Rules.Spread == LevelOff {
		return nil
	}
	var out []Issue
	for _, cls := range school.ClassesInOrder() {
		bySubject := map[string]map[int]int{}
		var order []string
		for _, placement := range timetable.Placements {
			lesson := school.LessonByID(placement.LessonID)
			if lesson == nil || lesson.ClassID != cls.ID || placement.Day < 0 || placement.Day >= len(school.Days) {
				continue
			}
			if _, ok := bySubject[lesson.SubjectID]; !ok {
				bySubject[lesson.SubjectID] = map[int]int{}
				order = append(order, lesson.SubjectID)
			}
			bySubject[lesson.SubjectID][placement.Day]++
		}
		for _, subjectID := range order {
			subject := school.SubjectByID(subjectID)
			if subject == nil {
				continue
			}
			days := bySubject[subjectID]
			crowdedDay := -1
			for day, value := range days {
				if value > 1 {
					crowdedDay = day
					break
				}
			}
			if crowdedDay < 0 {
				continue
			}
			out = append(out, suggestion(
				subject.Name+" sits twice on "+school.DayName(crowdedDay)+" for "+cls.Label(),
				"Spreading it through the week is easier on the class.",
				"Move one of them to another day.",
				nil,
				[]Mark{{ClassID: cls.ID, Day: crowdedDay, Period: 0}},
			))
			if len(out) >= 8 {
				return out
			}
		}
	}
	return out
}

func Problems(issues []Issue) []Issue {
	var out []Issue
	for _, issue := range issues {
		if issue.Severity == SeverityProblem {
			out = append(out, issue)
		}
	}
	return out
}
