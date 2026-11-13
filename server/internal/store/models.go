package store

import "schooldesk/internal/domain"

type User struct {
	ID               string   `json:"id"`
	Username         string   `json:"username"`
	Role             string   `json:"role"`
	StaffID          string   `json:"staff_id"`
	DisplayName      string   `json:"display_name"`
	Active           bool     `json:"active"`
	HomeroomClassIDs []string `json:"homeroom_class_ids"`
	TeachingIDs      []string `json:"teaching_ids"`
}

func (u User) IsAdmin() bool    { return u.Role == "admin" }
func (u User) IsDirector() bool { return u.Role == "director" }
func (u User) SeesSchool() bool { return u.Role == "admin" || u.Role == "director" }

type Settings struct {
	AcademicYear string            `json:"academic_year"`
	Semester     int               `json:"semester"`
	SemesterEnd  string            `json:"semester_end"`
	YearlyFee    float64           `json:"yearly_fee"`
	UtilityFee   float64           `json:"utility_fee"`
	CALocked     bool              `json:"ca_locked"`
	Weights      domain.Weights    `json:"weights"`
	FailLimits   domain.FailLimits `json:"fail_limits"`
	BackupDir    string            `json:"backup_dir"`
	SampleData   bool              `json:"sample_data"`
}

type Staff struct {
	ID              string `json:"id"`
	FullName        string `json:"full_name"`
	Sex             string `json:"sex"`
	Village         string `json:"village"`
	IDNumber        string `json:"id_number"`
	EmployeeID      string `json:"employee_id"`
	Phone           string `json:"phone"`
	DateOfBirth     string `json:"date_of_birth"`
	Residence       string `json:"residence"`
	GraduationField string `json:"graduation_field"`
	Qualification   string `json:"qualification"`
	StaffType       string `json:"staff_type"`
}

type Class struct {
	ID              string `json:"id"`
	Name            string `json:"name"`
	Level           string `json:"level"`
	Grade           int    `json:"grade"`
	AcademicYear    string `json:"academic_year"`
	HomeroomStaffID string `json:"homeroom_staff_id"`
	HomeroomName    string `json:"homeroom_name"`
}

type Subject struct {
	ID   string `json:"id"`
	Name string `json:"name"`
	Code string `json:"code"`
}

type ClassSubject struct {
	ID             string         `json:"id"`
	ClassID        string         `json:"class_id"`
	ClassName      string         `json:"class_name"`
	SubjectID      string         `json:"subject_id"`
	SubjectName    string         `json:"subject_name"`
	TeacherStaffID string         `json:"teacher_staff_id"`
	TeacherName    string         `json:"teacher_name"`
	PeriodsPerWeek int            `json:"periods_per_week"`
	Semester       int            `json:"semester"`
	Weights        domain.Weights `json:"weights"`
	CanEdit        bool           `json:"can_edit"`
}

type Student struct {
	ID            string            `json:"id"`
	FullName      string            `json:"full_name"`
	Sex           string            `json:"sex"`
	MotherName    string            `json:"mother_name"`
	ClassID       string            `json:"class_id"`
	DroppedOut    bool              `json:"dropped_out"`
	DropoutReason string            `json:"dropout_reason"`
	DropoutDate   string            `json:"dropout_date"`
	Fields        map[string]string `json:"fields"`
}

type CustomField struct {
	ID        string `json:"id"`
	Name      string `json:"name"`
	SortOrder int    `json:"sort_order"`
}

type Assessment struct {
	ID             string  `json:"id"`
	ClassSubjectID string  `json:"class_subject_id"`
	Component      string  `json:"component"`
	Half           int     `json:"half"`
	Title          string  `json:"title"`
	MaxMarks       float64 `json:"max_marks"`
	AssessmentDate string  `json:"assessment_date"`
	Revision       int     `json:"revision"`
}

type Score struct {
	ID           string   `json:"id"`
	AssessmentID string   `json:"assessment_id"`
	StudentID    string   `json:"student_id"`
	Score        *float64 `json:"score"`
	Revision     int      `json:"revision"`
	UpdatedAt    string   `json:"updated_at"`
}

type SubjectColumn struct {
	ClassSubject ClassSubject         `json:"class_subject"`
	Result       domain.SubjectResult `json:"result"`
}

type StudentResult struct {
	Student  Student         `json:"student"`
	Subjects []SubjectColumn `json:"subjects"`
	Standing domain.Standing `json:"standing"`
}

type ClassResults struct {
	Class    Class           `json:"class"`
	Semester int             `json:"semester"`
	Students []StudentResult `json:"students"`
}

type Headcount struct {
	Students int `json:"students"`
	Male     int `json:"male"`
	Female   int `json:"female"`
	Active   int `json:"active"`
	ActiveM  int `json:"active_male"`
	ActiveF  int `json:"active_female"`
	Dropped  int `json:"dropped"`
	DroppedM int `json:"dropped_male"`
	DroppedF int `json:"dropped_female"`
}

type ReasonCount struct {
	Reason string `json:"reason"`
	Total  int    `json:"total"`
	Male   int    `json:"male"`
	Female int    `json:"female"`
}

type FeeRow struct {
	StudentID string  `json:"student_id"`
	FullName  string  `json:"full_name"`
	Sex       string  `json:"sex"`
	Due       float64 `json:"due"`
	Paid      float64 `json:"paid"`
	Remaining float64 `json:"remaining"`
}

type Payment struct {
	ID           string  `json:"id"`
	StudentID    string  `json:"student_id"`
	AcademicYear string  `json:"academic_year"`
	Amount       float64 `json:"amount"`
	PaidOn       string  `json:"paid_on"`
}

type Income struct {
	ID         string  `json:"id"`
	Amount     float64 `json:"amount"`
	Source     string  `json:"source"`
	ReceivedOn string  `json:"received_on"`
	Note       string  `json:"note"`
}

type Expense struct {
	ID            string  `json:"id"`
	Amount        float64 `json:"amount"`
	Reason        string  `json:"reason"`
	SpentOn       string  `json:"spent_on"`
	ReceiptNumber string  `json:"receipt_number"`
	ChequeNumber  string  `json:"cheque_number"`
}

type Workshop struct {
	ID          string  `json:"id"`
	Amount      float64 `json:"amount"`
	Description string  `json:"description"`
	AttendedOn  string  `json:"attended_on"`
	Days        int     `json:"days"`
}

type SportsExpense struct {
	ID      string  `json:"id"`
	Amount  float64 `json:"amount"`
	Reason  string  `json:"reason"`
	SpentOn string  `json:"spent_on"`
}

type FinanceSummary struct {
	FeesCollected float64 `json:"fees_collected"`
	FeesRemaining float64 `json:"fees_remaining"`
	ManualIncome  float64 `json:"manual_income"`
	TotalIncome   float64 `json:"total_income"`
	Expenses      float64 `json:"expenses"`
	Workshops     float64 `json:"workshops"`
	Sports        float64 `json:"sports"`
	UtilityFee    float64 `json:"utility_fee"`
	TotalExpense  float64 `json:"total_expense"`
	Balance       float64 `json:"balance"`
}

type QualCount struct {
	Qualification string `json:"qualification"`
	Male          int    `json:"male"`
	Female        int    `json:"female"`
}

type StaffStats struct {
	TeachingMale      int         `json:"teaching_male"`
	TeachingFemale    int         `json:"teaching_female"`
	NonTeachingMale   int         `json:"non_teaching_male"`
	NonTeachingFemale int         `json:"non_teaching_female"`
	ByQualification   []QualCount `json:"by_qualification"`
}

type Meeting struct {
	ID          string `json:"id"`
	MeetingDate string `json:"meeting_date"`
	Title       string `json:"title"`
	Attendees   string `json:"attendees"`
	Notes       string `json:"notes"`
}

type Slot struct {
	ID             string `json:"id"`
	ClassID        string `json:"class_id"`
	Day            int    `json:"day"`
	Period         int    `json:"period"`
	ClassSubjectID string `json:"class_subject_id"`
	TeacherStaffID string `json:"teacher_staff_id"`
	SubjectName    string `json:"subject_name"`
	TeacherName    string `json:"teacher_name"`
	ClassName      string `json:"class_name"`
}

type Bell struct {
	Days          int `json:"days"`
	PeriodsPerDay int `json:"periods_per_day"`
}

type Device struct {
	ID         string `json:"id"`
	Name       string `json:"name"`
	Platform   string `json:"platform"`
	CreatedAt  string `json:"created_at"`
	LastSeenAt string `json:"last_seen_at"`
}

type Change struct {
	Seq       int64  `json:"seq"`
	Entity    string `json:"entity"`
	EntityID  string `json:"entity_id"`
	Deleted   bool   `json:"deleted"`
	Payload   string `json:"payload"`
	UpdatedAt string `json:"updated_at"`
}

type SavedReport struct {
	ID           string `json:"id"`
	AcademicYear string `json:"academic_year"`
	Semester     int    `json:"semester"`
	ClassID      string `json:"class_id"`
	Title        string `json:"title"`
	GeneratedAt  string `json:"generated_at"`
}

type PromotionStat struct {
	ClassID     string    `json:"class_id"`
	ClassName   string    `json:"class_name"`
	Level       string    `json:"level"`
	Head        Headcount `json:"head"`
	Promoted    int       `json:"promoted"`
	PromotedM   int       `json:"promoted_male"`
	PromotedF   int       `json:"promoted_female"`
	Failed      int       `json:"failed"`
	FailedM     int       `json:"failed_male"`
	FailedF     int       `json:"failed_female"`
	PromotedPct float64   `json:"promoted_pct"`
	FailedPct   float64   `json:"failed_pct"`
	DropoutPct  float64   `json:"dropout_pct"`
}
