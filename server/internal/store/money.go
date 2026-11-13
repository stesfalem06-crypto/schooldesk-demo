package store

import (
	"schooldesk/internal/domain"
)

func (s *Store) AddPayment(studentID, year, paidOn, userID string, amount float64) (Payment, error) {
	if amount <= 0 || !validMoney(amount) {
		return Payment{}, errStr("enter how much was paid")
	}
	if !validDate(paidOn) {
		return Payment{}, errStr("the date is not valid")
	}
	if year == "" {
		return Payment{}, errStr("the school year is missing")
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	settings := s.readSettings(s.db)
	var studentYear = year
	_ = studentYear
	var paid float64
	_ = s.db.QueryRow(`SELECT COALESCE(SUM(amount),0) FROM fee_payments WHERE student_id = ? AND academic_year = ?`, studentID, year).Scan(&paid)
	if err := domain.CanPay(settings.YearlyFee, paid, amount); err != nil {
		return Payment{}, err
	}
	var exists int
	if err := s.db.QueryRow(`SELECT COUNT(*) FROM students WHERE id = ?`, studentID).Scan(&exists); err != nil {
		return Payment{}, err
	}
	if exists == 0 {
		return Payment{}, ErrNotFound
	}
	p := Payment{ID: NewID(), StudentID: studentID, AcademicYear: year, Amount: domain.Round2(amount), PaidOn: paidOn}
	tx, err := s.db.Begin()
	if err != nil {
		return Payment{}, err
	}
	defer tx.Rollback()
	now := Now()
	_, err = tx.Exec(`INSERT INTO fee_payments (id, student_id, academic_year, amount, paid_on, recorded_by, created_at, updated_at) VALUES (?,?,?,?,?,?,?,?)`,
		p.ID, p.StudentID, p.AcademicYear, p.Amount, p.PaidOn, userID, now, now)
	if err != nil {
		return Payment{}, err
	}
	if err := s.logChange(tx, "fee_payments", p.ID, false, p); err != nil {
		return Payment{}, err
	}
	return p, tx.Commit()
}

func (s *Store) FeeRows(classID, year string) ([]FeeRow, error) {
	students, err := s.ListStudents(classID)
	if err != nil {
		return nil, err
	}
	settings, err := s.Settings()
	if err != nil {
		return nil, err
	}
	if year == "" {
		year = settings.AcademicYear
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	out := make([]FeeRow, 0, len(students))
	for _, st := range students {
		var paid float64
		if err := s.db.QueryRow(`SELECT COALESCE(SUM(amount),0) FROM fee_payments WHERE student_id = ? AND academic_year = ?`, st.ID, year).Scan(&paid); err != nil {
			return nil, err
		}
		acc, err := domain.Fee(settings.YearlyFee, []float64{paid})
		if err != nil {
			return nil, err
		}
		out = append(out, FeeRow{StudentID: st.ID, FullName: st.FullName, Sex: st.Sex, Due: acc.Due, Paid: acc.Paid, Remaining: acc.Remaining})
	}
	return out, nil
}

func (s *Store) SchoolFees() (collected, remaining float64, err error) {
	settings, err := s.Settings()
	if err != nil {
		return 0, 0, err
	}
	rows, err := s.FeeRows("", settings.AcademicYear)
	if err != nil {
		return 0, 0, err
	}
	for _, r := range rows {
		collected += r.Paid
		remaining += r.Remaining
	}
	return domain.Round2(collected), domain.Round2(remaining), nil
}

func (s *Store) AddIncome(in Income) (Income, error) {
	if in.Amount <= 0 || !validMoney(in.Amount) {
		return Income{}, errStr("enter the amount")
	}
	if err := requireText(in.Source, "where the money came from", 80); err != nil {
		return Income{}, err
	}
	if !validDate(in.ReceivedOn) {
		return Income{}, errStr("the date is not valid")
	}
	in.ID = NewID()
	in.Source = clean(in.Source)
	in.Amount = domain.Round2(in.Amount)
	return in, s.insertMoney(`INSERT INTO incomes (id, amount, source, received_on, note, created_at, updated_at) VALUES (?,?,?,?,?,?,?)`,
		"incomes", in, in.ID, in.Amount, in.Source, in.ReceivedOn, clean(in.Note), Now(), Now())
}

func (s *Store) ListIncomes() ([]Income, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	rows, err := s.db.Query(`SELECT id, amount, source, received_on, note FROM incomes ORDER BY received_on DESC, source`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Income
	for rows.Next() {
		var in Income
		if err := rows.Scan(&in.ID, &in.Amount, &in.Source, &in.ReceivedOn, &in.Note); err != nil {
			return nil, err
		}
		out = append(out, in)
	}
	return out, rows.Err()
}

func (s *Store) AddExpense(in Expense) (Expense, error) {
	if in.Amount <= 0 || !validMoney(in.Amount) {
		return Expense{}, errStr("enter the amount")
	}
	if err := requireText(in.Reason, "what the money was for", 120); err != nil {
		return Expense{}, err
	}
	if err := requireText(in.ReceiptNumber, "the receipt number", 40); err != nil {
		return Expense{}, err
	}
	if !validDate(in.SpentOn) {
		return Expense{}, errStr("the date is not valid")
	}
	in.ID = NewID()
	in.Amount = domain.Round2(in.Amount)
	in.Reason = clean(in.Reason)
	in.ReceiptNumber = clean(in.ReceiptNumber)
	in.ChequeNumber = clean(in.ChequeNumber)
	return in, s.insertMoney(`INSERT INTO expenses (id, amount, reason, spent_on, receipt_number, cheque_number, created_at, updated_at) VALUES (?,?,?,?,?,?,?,?)`,
		"expenses", in, in.ID, in.Amount, in.Reason, in.SpentOn, in.ReceiptNumber, in.ChequeNumber, Now(), Now())
}

func (s *Store) ListExpenses() ([]Expense, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	rows, err := s.db.Query(`SELECT id, amount, reason, spent_on, receipt_number, cheque_number FROM expenses ORDER BY spent_on DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Expense
	for rows.Next() {
		var e Expense
		if err := rows.Scan(&e.ID, &e.Amount, &e.Reason, &e.SpentOn, &e.ReceiptNumber, &e.ChequeNumber); err != nil {
			return nil, err
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

func (s *Store) AddWorkshop(in Workshop) (Workshop, error) {
	if in.Amount <= 0 || !validMoney(in.Amount) {
		return Workshop{}, errStr("enter the amount")
	}
	if in.AttendedOn == "" && in.Days <= 0 {
		return Workshop{}, errStr("enter the date or the number of days")
	}
	if in.AttendedOn != "" && !validDate(in.AttendedOn) {
		return Workshop{}, errStr("the date is not valid")
	}
	if in.Days < 0 {
		return Workshop{}, errStr("days cannot be negative")
	}
	in.ID = NewID()
	in.Amount = domain.Round2(in.Amount)
	in.Description = clean(in.Description)
	return in, s.insertMoney(`INSERT INTO workshop_expenses (id, amount, description, attended_on, days, created_at, updated_at) VALUES (?,?,?,?,?,?,?)`,
		"workshop_expenses", in, in.ID, in.Amount, in.Description, in.AttendedOn, in.Days, Now(), Now())
}

func (s *Store) ListWorkshops() ([]Workshop, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	rows, err := s.db.Query(`SELECT id, amount, description, attended_on, days FROM workshop_expenses ORDER BY attended_on DESC, id DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Workshop
	for rows.Next() {
		var w Workshop
		if err := rows.Scan(&w.ID, &w.Amount, &w.Description, &w.AttendedOn, &w.Days); err != nil {
			return nil, err
		}
		out = append(out, w)
	}
	return out, rows.Err()
}

func (s *Store) AddSports(in SportsExpense) (SportsExpense, error) {
	if in.Amount <= 0 || !validMoney(in.Amount) {
		return SportsExpense{}, errStr("enter the amount")
	}
	if err := requireText(in.Reason, "what the money was for", 120); err != nil {
		return SportsExpense{}, err
	}
	if !validDate(in.SpentOn) {
		return SportsExpense{}, errStr("the date is not valid")
	}
	in.ID = NewID()
	in.Amount = domain.Round2(in.Amount)
	in.Reason = clean(in.Reason)
	return in, s.insertMoney(`INSERT INTO sports_expenses (id, amount, reason, spent_on, created_at, updated_at) VALUES (?,?,?,?,?,?)`,
		"sports_expenses", in, in.ID, in.Amount, in.Reason, in.SpentOn, Now(), Now())
}

func (s *Store) ListSports() ([]SportsExpense, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	rows, err := s.db.Query(`SELECT id, amount, reason, spent_on FROM sports_expenses ORDER BY spent_on DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []SportsExpense
	for rows.Next() {
		var e SportsExpense
		if err := rows.Scan(&e.ID, &e.Amount, &e.Reason, &e.SpentOn); err != nil {
			return nil, err
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

func (s *Store) insertMoney(q, entity string, payload any, args ...any) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if _, err := tx.Exec(q, args...); err != nil {
		return err
	}
	id := args[0].(string)
	if err := s.logChange(tx, entity, id, false, payload); err != nil {
		return err
	}
	return tx.Commit()
}

func (s *Store) Finance() (FinanceSummary, error) {
	collected, remaining, err := s.SchoolFees()
	if err != nil {
		return FinanceSummary{}, err
	}
	incomes, err := s.ListIncomes()
	if err != nil {
		return FinanceSummary{}, err
	}
	expenses, err := s.ListExpenses()
	if err != nil {
		return FinanceSummary{}, err
	}
	workshops, err := s.ListWorkshops()
	if err != nil {
		return FinanceSummary{}, err
	}
	sports, err := s.ListSports()
	if err != nil {
		return FinanceSummary{}, err
	}
	settings, err := s.Settings()
	if err != nil {
		return FinanceSummary{}, err
	}
	var manual, exp, work, sport float64
	for _, r := range incomes {
		manual += r.Amount
	}
	for _, r := range expenses {
		exp += r.Amount
	}
	for _, r := range workshops {
		work += r.Amount
	}
	for _, r := range sports {
		sport += r.Amount
	}
	sum := FinanceSummary{
		FeesCollected: collected,
		FeesRemaining: remaining,
		ManualIncome:  domain.Round2(manual),
		Expenses:      domain.Round2(exp),
		Workshops:     domain.Round2(work),
		Sports:        domain.Round2(sport),
		UtilityFee:    settings.UtilityFee,
	}
	sum.TotalIncome = domain.Round2(sum.FeesCollected + sum.ManualIncome)
	sum.TotalExpense = domain.Round2(sum.Expenses + sum.Workshops + sum.Sports + sum.UtilityFee)
	sum.Balance = domain.Round2(sum.TotalIncome - sum.TotalExpense)
	return sum, nil
}
