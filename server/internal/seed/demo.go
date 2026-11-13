package seed

import (
	"schooldesk/internal/auth"
	"schooldesk/internal/domain"
	"schooldesk/internal/store"
)

// Demo loads a small sample school the first time the server starts.
func Demo(s *store.Store) error {
	settings := store.Settings{
		AcademicYear: "2026-2027",
		Semester:     1,
		SemesterEnd:  "2027-01-20",
		YearlyFee:    1500,
		UtilityFee:   2000,
		Weights:      domain.DefaultWeights(),
		FailLimits:   domain.DefaultFailLimits(),
		SampleData:   true,
	}
	if err := s.SaveSettings(settings); err != nil {
		return err
	}
	hanna, err := s.SaveStaff(store.Staff{FullName: "Hanna Berhe", Sex: "F", Village: "Asmara", IDNumber: "ID1001", EmployeeID: "E-01", Phone: "07110001", DateOfBirth: "1990-04-12", Residence: "Asmara", GraduationField: "Language", Qualification: "degree", StaffType: "teaching"})
	if err != nil {
		return err
	}
	samuel, err := s.SaveStaff(store.Staff{FullName: "Samuel Ghebremeskel", Sex: "M", Village: "Keren", IDNumber: "ID1002", EmployeeID: "E-02", Phone: "07110002", DateOfBirth: "1986-08-02", Residence: "Asmara", GraduationField: "Mathematics", Qualification: "degree", StaffType: "teaching"})
	if err != nil {
		return err
	}
	meron, err := s.SaveStaff(store.Staff{FullName: "Meron Tesfalem", Sex: "F", Village: "Mendefera", IDNumber: "ID1003", EmployeeID: "E-03", Phone: "07110003", DateOfBirth: "1994-01-19", Residence: "Asmara", GraduationField: "English", Qualification: "diploma", StaffType: "teaching"})
	if err != nil {
		return err
	}
	dawit, err := s.SaveStaff(store.Staff{FullName: "Dawit Okubay", Sex: "M", Village: "Dekemhare", IDNumber: "ID1004", EmployeeID: "E-04", Phone: "07110004", DateOfBirth: "1982-11-30", Residence: "Asmara", GraduationField: "Physics", Qualification: "masters", StaffType: "teaching"})
	if err != nil {
		return err
	}
	if _, err := s.SaveStaff(store.Staff{FullName: "Senait Abraham", Sex: "F", Village: "Asmara", IDNumber: "ID2001", EmployeeID: "E-11", Phone: "07120001", DateOfBirth: "1988-06-06", Residence: "Asmara", GraduationField: "Management", Qualification: "diploma", StaffType: "non-teaching"}); err != nil {
		return err
	}
	if _, err := s.SaveStaff(store.Staff{FullName: "Kibrom Hailu", Sex: "M", Village: "Adi Quala", IDNumber: "ID2002", EmployeeID: "E-12", Phone: "07120002", DateOfBirth: "1979-02-14", Residence: "Asmara", Qualification: "12+certificate", StaffType: "non-teaching"}); err != nil {
		return err
	}
	g3, err := s.SaveClass(store.Class{Name: "Grade 3A", Level: "elementary", Grade: 3, AcademicYear: "2026-2027", HomeroomStaffID: hanna.ID})
	if err != nil {
		return err
	}
	g8, err := s.SaveClass(store.Class{Name: "Grade 8A", Level: "junior", Grade: 8, AcademicYear: "2026-2027", HomeroomStaffID: samuel.ID})
	if err != nil {
		return err
	}
	g11, err := s.SaveClass(store.Class{Name: "Grade 11A", Level: "high", Grade: 11, AcademicYear: "2026-2027", HomeroomStaffID: dawit.ID})
	if err != nil {
		return err
	}
	sub := map[string]store.Subject{}
	for _, name := range []string{"Tigrinya", "English", "Mathematics", "Science", "Physics"} {
		got, err := s.SaveSubject(store.Subject{Name: name})
		if err != nil {
			return err
		}
		sub[name] = got
	}
	w := domain.DefaultWeights()
	links := []struct {
		class, subject, teacher string
		periods                 int
	}{
		{g3.ID, sub["Tigrinya"].ID, hanna.ID, 5},
		{g3.ID, sub["English"].ID, meron.ID, 4},
		{g3.ID, sub["Mathematics"].ID, samuel.ID, 5},
		{g8.ID, sub["Mathematics"].ID, samuel.ID, 5},
		{g8.ID, sub["English"].ID, meron.ID, 4},
		{g8.ID, sub["Science"].ID, dawit.ID, 4},
		{g11.ID, sub["Physics"].ID, dawit.ID, 4},
		{g11.ID, sub["Mathematics"].ID, samuel.ID, 5},
		{g11.ID, sub["English"].ID, meron.ID, 3},
	}
	var grade8 []store.ClassSubject
	for _, link := range links {
		cs, err := s.AddClassSubject(link.class, link.subject, link.teacher, link.periods, 1, w)
		if err != nil {
			return err
		}
		if link.class == g8.ID && (cs.SubjectName == "Mathematics" || cs.SubjectName == "English") {
			grade8 = append(grade8, cs)
		}
	}
	field, err := s.AddCustomField("Father's name")
	if err != nil {
		return err
	}
	type pupil struct {
		name, sex, mother, father, class string
		exam                              float64
		full                              bool
	}
	pupils := []pupil{
		{"Abel Tesfay", "M", "Senait", "Tesfay", g8.ID, 40, true},
		{"Bereket Hailu", "M", "Hiwet", "Hailu", g8.ID, 30, true},
		{"Dawit Okbay", "M", "Rahwa", "Okbay", g8.ID, 30, true},
		{"Yonatan Kibrom", "M", "Lidya", "Kibrom", g8.ID, 10, false},
		{"Hiwet Samuel", "F", "Meron", "Samuel", g8.ID, 0, false},
		{"Selam Berhe", "F", "Hanna", "Berhe", g3.ID, 0, false},
		{"Aman Ghebremeskel", "M", "Senait", "Ghebremeskel", g3.ID, 0, false},
		{"Ruth Dawit", "F", "Almaz", "Dawit", g11.ID, 0, false},
		{"Nahom Tesfalem", "M", "Helen", "Tesfalem", g11.ID, 0, false},
	}
	var grade8Students []store.Student
	for _, p := range pupils {
		st, err := s.SaveStudent(store.Student{FullName: p.name, Sex: p.sex, MotherName: p.mother, ClassID: p.class, Fields: map[string]string{field.ID: p.father}})
		if err != nil {
			return err
		}
		if p.class == g8.ID {
			grade8Students = append(grade8Students, st)
		}
	}
	if _, err := s.SetDropout(grade8Students[4].ID, true, "Moved away", "2026-10-02"); err != nil {
		return err
	}
	for _, cs := range grade8 {
		assessments, err := s.ListAssessments(cs.ID)
		if err != nil {
			return err
		}
		var examID string
		for _, a := range assessments {
			if a.Component == "exam" {
				examID = a.ID
			}
		}
		for _, comp := range []string{"classwork", "quizzes", "tests", "assignments", "participation", "homework"} {
			for _, half := range []int{1, 2} {
				a, err := s.AddAssessment(cs.ID, comp, half, comp, 10, "")
				if err != nil {
					return err
				}
				for i, st := range grade8Students {
					if st.FullName == "Hiwet Samuel" {
						continue
					}
					score := 10.0
					if pupils[i].exam == 10 {
						score = 5
					}
					if _, _, err := s.SetScore("seed", a.ID, st.ID, domain.F(score), 0); err != nil {
						return err
					}
				}
			}
		}
		for i, st := range grade8Students {
			if pupils[i].exam == 0 {
				continue
			}
			if _, _, err := s.SetScore("seed", examID, st.ID, domain.F(pupils[i].exam), 0); err != nil {
				return err
			}
		}
	}
	if _, err := s.AddPayment(grade8Students[0].ID, "2026-2027", "2026-09-10", "seed", 1500); err != nil {
		return err
	}
	if _, err := s.AddPayment(grade8Students[1].ID, "2026-2027", "2026-09-12", "seed", 600); err != nil {
		return err
	}
	if _, err := s.AddIncome(store.Income{Amount: 5000, Source: "Community support", ReceivedOn: "2026-09-15", Note: "Given at the office"}); err != nil {
		return err
	}
	if _, err := s.AddExpense(store.Expense{Amount: 800, Reason: "Exercise books", SpentOn: "2026-09-18", ReceiptNumber: "R-1001", ChequeNumber: "55"}); err != nil {
		return err
	}
	if _, err := s.AddWorkshop(store.Workshop{Amount: 1200, Description: "Mathematics workshop", AttendedOn: "2026-10-05", Days: 2}); err != nil {
		return err
	}
	if _, err := s.AddSports(store.SportsExpense{Amount: 450, Reason: "Balls and vests", SpentOn: "2026-10-08"}); err != nil {
		return err
	}
	if err := s.SaveBell(store.Bell{Days: 5, PeriodsPerDay: 6}); err != nil {
		return err
	}
	_ = s.SetWeeklyPeriods(samuel.ID, []int{4, 3, 2, 4, 2, 0, 0})
	_ = s.AddAbsence(samuel.ID, "2026-11-02", "")
	_ = s.AddAbsence(samuel.ID, "2026-11-03", "")
	_ = s.AddMakeup(samuel.ID, "2026-11-07", "After school", 2)
	if _, err := s.SaveMeeting(store.Meeting{MeetingDate: "2026-10-20", Title: "Staff meeting", Attendees: "Hanna, Samuel, Meron, Dawit", Notes: "Term plan"}); err != nil {
		return err
	}
	_, _ = s.GenerateTimetable(1)
	users := []struct{ user, pass, role, staff, name string }{
		{"admin", "admin1850", "admin", "", "School admin"},
		{"director", "director1850", "director", "", "Director"},
		{"hanna", "hanna1850", "teacher", hanna.ID, "Hanna Berhe"},
		{"samuel", "samuel1850", "teacher", samuel.ID, "Samuel Ghebremeskel"},
		{"meron", "meron1850", "teacher", meron.ID, "Meron Tesfalem"},
		{"dawit", "dawit1850", "teacher", dawit.ID, "Dawit Okubay"},
	}
	for _, u := range users {
		hash, err := auth.Hash(u.pass)
		if err != nil {
			return err
		}
		if _, err := s.CreateUser(u.user, hash, u.role, u.staff, u.name); err != nil {
			return err
		}
	}
	return nil
}
