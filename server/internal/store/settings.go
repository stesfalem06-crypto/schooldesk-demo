package store

import (
	"strconv"
	"strings"

	"schooldesk/internal/domain"
)

func (s *Store) Settings() (Settings, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.readSettings(s.db), nil
}

func (s *Store) readSettings(q queryer) Settings {
	w := domain.DefaultWeights()
	if raw := s.setting(q, "weights", ""); raw != "" {
		parts := strings.Split(raw, ",")
		if len(parts) == 6 {
			nums := make([]float64, 6)
			ok := true
			for i, p := range parts {
				n, err := strconv.ParseFloat(p, 64)
				if err != nil {
					ok = false
					break
				}
				nums[i] = n
			}
			if ok {
				w = domain.Weights{Classwork: nums[0], Quizzes: nums[1], Tests: nums[2], Assignments: nums[3], Participation: nums[4], Homework: nums[5]}
			}
		}
	}
	sem, _ := strconv.Atoi(s.setting(q, "semester", "1"))
	if sem != 2 {
		sem = 1
	}
	fee, _ := strconv.ParseFloat(s.setting(q, "yearly_fee", "0"), 64)
	util, _ := strconv.ParseFloat(s.setting(q, "utility_fee", "0"), 64)
	fe, _ := strconv.Atoi(s.setting(q, "fail_elementary", "2"))
	fj, _ := strconv.Atoi(s.setting(q, "fail_junior", "3"))
	fh, _ := strconv.Atoi(s.setting(q, "fail_high", "3"))
	return Settings{
		AcademicYear: s.setting(q, "academic_year", ""),
		Semester:     sem,
		SemesterEnd:  s.setting(q, "semester_end", ""),
		YearlyFee:    fee,
		UtilityFee:   util,
		CALocked:     s.setting(q, "ca_locked", "0") == "1",
		Weights:      w,
		FailLimits:   domain.FailLimits{Elementary: fe, Junior: fj, High: fh},
		BackupDir:    s.setting(q, "backup_dir", ""),
		SampleData:   s.setting(q, "sample_data", "0") == "1",
		GradeLabels:  s.setting(q, "grade_labels", ""),
	}
}

func (s *Store) SaveSettings(in Settings) error {
	if in.Semester != 1 && in.Semester != 2 {
		return errStr("semester must be 1 or 2")
	}
	if in.YearlyFee < 0 || in.UtilityFee < 0 {
		return errStr("fees cannot be negative")
	}
	if !in.Weights.Valid() {
		return errStr("the six parts must add up to 60")
	}
	if in.FailLimits.Elementary < 0 || in.FailLimits.Junior < 0 || in.FailLimits.High < 0 {
		return errStr("the fail limit cannot be negative")
	}
	if in.SemesterEnd != "" && !validDate(in.SemesterEnd) {
		return errStr("the semester end date is not valid")
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	w := in.Weights
	weights := strings.Join([]string{
		ftoa(w.Classwork), ftoa(w.Quizzes), ftoa(w.Tests), ftoa(w.Assignments), ftoa(w.Participation), ftoa(w.Homework),
	}, ",")
	pairs := [][2]string{
		{"academic_year", strings.TrimSpace(in.AcademicYear)},
		{"semester", strconv.Itoa(in.Semester)},
		{"semester_end", in.SemesterEnd},
		{"yearly_fee", ftoa(in.YearlyFee)},
		{"utility_fee", ftoa(in.UtilityFee)},
		{"ca_locked", bool01(in.CALocked)},
		{"weights", weights},
		{"fail_elementary", strconv.Itoa(in.FailLimits.Elementary)},
		{"fail_junior", strconv.Itoa(in.FailLimits.Junior)},
		{"fail_high", strconv.Itoa(in.FailLimits.High)},
		{"backup_dir", strings.TrimSpace(in.BackupDir)},
		{"sample_data", bool01(in.SampleData)},
		{"grade_labels", strings.TrimSpace(in.GradeLabels)},
	}
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	for _, p := range pairs {
		if err := s.putSetting(tx, p[0], p[1]); err != nil {
			return err
		}
	}
	return tx.Commit()
}

func (s *Store) MarkReportGenerated(key string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.putSetting(s.db, "semester_report_for", key)
}

func (s *Store) ReportGeneratedFor() (string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.setting(s.db, "semester_report_for", ""), nil
}
