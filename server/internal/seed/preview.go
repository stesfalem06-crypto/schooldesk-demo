package seed

import (
	"fmt"

	"schooldesk/internal/auth"
	"schooldesk/internal/domain"
	"schooldesk/internal/store"
)

// Preview loads a full sample school for the demo disk image.
// Production builds keep using Demo.
func Preview(s *store.Store) error {
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
	hanna, err := saveTeacher(s, "Hanna Berhe", "F", "Asmara", "ID1001", "E-01", "07110001", "1990-04-12", "Language", "degree")
	if err != nil {
		return err
	}
	samuel, err := saveTeacher(s, "Samuel Ghebremeskel", "M", "Keren", "ID1002", "E-02", "07110002", "1986-08-02", "Mathematics", "degree")
	if err != nil {
		return err
	}
	meron, err := saveTeacher(s, "Meron Tesfalem", "F", "Mendefera", "ID1003", "E-03", "07110003", "1994-01-19", "English", "diploma")
	if err != nil {
		return err
	}
	dawit, err := saveTeacher(s, "Dawit Okubay", "M", "Dekemhare", "ID1004", "E-04", "07110004", "1982-11-30", "Physics", "masters")
	if err != nil {
		return err
	}
	sara, err := saveTeacher(s, "Sara Mehari", "F", "Adi Keyih", "ID1005", "E-05", "07110005", "1992-07-21", "Science", "degree")
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
	g5, err := s.SaveClass(store.Class{Name: "Grade 5B", Level: "elementary", Grade: 5, AcademicYear: "2026-2027", HomeroomStaffID: sara.ID})
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

	names := []string{"Tigrinya", "English", "Mathematics", "Science", "Physics", "Social Studies"}
	sub := map[string]store.Subject{}
	for _, name := range names {
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
		{g3.ID, sub["Tigrinya"].ID, hanna.ID, 4},
		{g3.ID, sub["English"].ID, meron.ID, 3},
		{g3.ID, sub["Mathematics"].ID, samuel.ID, 4},
		{g3.ID, sub["Science"].ID, sara.ID, 3},
		{g5.ID, sub["English"].ID, meron.ID, 3},
		{g5.ID, sub["Mathematics"].ID, samuel.ID, 4},
		{g5.ID, sub["Science"].ID, sara.ID, 3},
		{g5.ID, sub["Social Studies"].ID, hanna.ID, 3},
		{g8.ID, sub["Mathematics"].ID, samuel.ID, 4},
		{g8.ID, sub["English"].ID, meron.ID, 3},
		{g8.ID, sub["Science"].ID, sara.ID, 3},
		{g8.ID, sub["Social Studies"].ID, hanna.ID, 2},
		{g11.ID, sub["Physics"].ID, dawit.ID, 4},
		{g11.ID, sub["Mathematics"].ID, samuel.ID, 4},
		{g11.ID, sub["English"].ID, meron.ID, 3},
	}
	var subjects []store.ClassSubject
	for _, link := range links {
		cs, err := s.AddClassSubject(link.class, link.subject, link.teacher, link.periods, 1, w)
		if err != nil {
			return err
		}
		subjects = append(subjects, cs)
	}

	field, err := s.AddCustomField("Father's name")
	if err != nil {
		return err
	}
	type kid struct {
		name, sex, mother, father, class string
		weak                             bool
		leave                            bool
	}
	pupils := []kid{
		{"Selam Berhe", "F", "Hanna", "Berhe", g3.ID, false, false},
		{"Aman Ghebremeskel", "M", "Senait", "Ghebremeskel", g3.ID, false, false},
		{"Naemi Kibrom", "F", "Luwam", "Kibrom", g3.ID, true, false},
		{"Robel Tesfay", "M", "Hiwet", "Tesfay", g3.ID, false, false},
		{"Yosef Mehari", "M", "Sara", "Mehari", g5.ID, false, false},
		{"Lidya Okbay", "F", "Rahwa", "Okbay", g5.ID, false, false},
		{"Hermon Dawit", "M", "Almaz", "Dawit", g5.ID, true, false},
		{"Saron Hailu", "F", "Helen", "Hailu", g5.ID, false, false},
		{"Abel Tesfay", "M", "Senait", "Tesfay", g8.ID, false, false},
		{"Bereket Hailu", "M", "Hiwet", "Hailu", g8.ID, false, false},
		{"Dawit Okbay", "M", "Rahwa", "Okbay", g8.ID, true, false},
		{"Hiwet Samuel", "F", "Meron", "Samuel", g8.ID, false, true},
		{"Ruth Dawit", "F", "Almaz", "Dawit", g11.ID, false, false},
		{"Nahom Tesfalem", "M", "Helen", "Tesfalem", g11.ID, false, false},
		{"Soliana Berhe", "F", "Hanna", "Berhe", g11.ID, true, false},
		{"Kibrom Aman", "M", "Luwam", "Aman", g11.ID, false, false},
	}
	byClass := map[string][]store.Student{}
	for _, p := range pupils {
		st, err := s.SaveStudent(store.Student{FullName: p.name, Sex: p.sex, MotherName: p.mother, ClassID: p.class, Fields: map[string]string{field.ID: p.father}})
		if err != nil {
			return err
		}
		if p.leave {
			if _, err := s.SetDropout(st.ID, true, "Moved away", "2026-10-02"); err != nil {
				return err
			}
			continue
		}
		byClass[p.class] = append(byClass[p.class], st)
	}
	for _, cs := range subjects {
		if err := scoreSubject(s, cs, byClass[cs.ClassID]); err != nil {
			return err
		}
	}

	students := append([]store.Student{}, byClass[g8.ID]...)
	if len(students) >= 2 {
		if _, err := s.AddPayment(students[0].ID, "2026-2027", "2026-09-10", "seed", 1500); err != nil {
			return err
		}
		if _, err := s.AddPayment(students[1].ID, "2026-2027", "2026-09-12", "seed", 600); err != nil {
			return err
		}
	}
	if g3students := byClass[g3.ID]; len(g3students) > 0 {
		if _, err := s.AddPayment(g3students[0].ID, "2026-2027", "2026-09-20", "seed", 1500); err != nil {
			return err
		}
	}
	if _, err := s.AddIncome(store.Income{Amount: 5000, Source: "Community support", ReceivedOn: "2026-09-15", Note: "Given at the office"}); err != nil {
		return err
	}
	if _, err := s.AddExpense(store.Expense{Amount: 800, Reason: "Exercise books", SpentOn: "2026-09-18", ReceiptNumber: "R-1001", ChequeNumber: "55"}); err != nil {
		return err
	}
	if _, err := s.AddExpense(store.Expense{Amount: 350, Reason: "Chalk and paper", SpentOn: "2026-10-12", ReceiptNumber: "R-1008"}); err != nil {
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
	_ = s.SetWeeklyPeriods(samuel.ID, []int{4, 4, 4, 4, 0, 0, 0})
	if err := s.AddAbsence(samuel.ID, "2026-11-02", "Family"); err != nil {
		return err
	}
	if err := s.AddAbsence(samuel.ID, "2026-11-03", ""); err != nil {
		return err
	}
	if err := s.AddAbsence(hanna.ID, "2026-11-06", "Clinic"); err != nil {
		return err
	}
	_ = s.AddMakeup(samuel.ID, "2026-11-07", "After school", 2)
	if _, err := s.SaveMeeting(store.Meeting{MeetingDate: "2026-10-20", Title: "Staff meeting", Attendees: "Hanna, Samuel, Meron, Dawit, Sara", Notes: "Term plan"}); err != nil {
		return err
	}
	if _, err := s.SaveMeeting(store.Meeting{MeetingDate: "2026-11-10", Title: "Parents meeting", Attendees: "Hanna, Samuel, parents of Grade 8A", Notes: "Mid marks and fees"}); err != nil {
		return err
	}
	if _, err := s.GenerateTimetable(1); err != nil {
		return err
	}

	users := []struct{ user, pass, role, staff, name string }{
		{"admin", "admin1850", "admin", "", "School admin"},
		{"director", "director1850", "director", "", "Director"},
		{"hanna", "hanna1850", "teacher", hanna.ID, "Hanna Berhe"},
		{"samuel", "samuel1850", "teacher", samuel.ID, "Samuel Ghebremeskel"},
		{"meron", "meron1850", "teacher", meron.ID, "Meron Tesfalem"},
		{"dawit", "dawit1850", "teacher", dawit.ID, "Dawit Okubay"},
		{"sara", "sara1850", "teacher", sara.ID, "Sara Mehari"},
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

func saveTeacher(s *store.Store, name, sex, village, idNumber, employee, phone, born, field, qualification string) (store.Staff, error) {
	return s.SaveStaff(store.Staff{
		FullName: name, Sex: sex, Village: village, IDNumber: idNumber, EmployeeID: employee,
		Phone: phone, DateOfBirth: born, Residence: "Asmara", GraduationField: field,
		Qualification: qualification, StaffType: "teaching",
	})
}

func scoreSubject(s *store.Store, cs store.ClassSubject, students []store.Student) error {
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
	if examID == "" {
		return fmt.Errorf("semester exam missing for %s", cs.SubjectName)
	}
	parts := []string{"classwork", "quizzes", "tests", "assignments", "participation", "homework"}
	for pi, comp := range parts {
		for _, half := range []int{1, 2} {
			a, err := s.AddAssessment(cs.ID, comp, half, comp, 10, "")
			if err != nil {
				return err
			}
			for i, st := range students {
				score := 8.0
				if i%4 == 2 {
					score = 4
				}
				if pi%2 == 1 && half == 2 {
					score -= 1
				}
				if score < 0 {
					score = 0
				}
				if _, _, err := s.SetScore("seed", a.ID, st.ID, domain.F(score), 0); err != nil {
					return err
				}
			}
		}
	}
	for i, st := range students {
		exam := 32.0
		if i%4 == 2 {
			exam = 12
		}
		if _, _, err := s.SetScore("seed", examID, st.ID, domain.F(exam), 0); err != nil {
			return err
		}
	}
	return nil
}
