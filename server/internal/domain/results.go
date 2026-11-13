package domain

import "sort"

// FailLimits is how many failed subjects make a student failed even when
// the average is above 50. Keys are elementary, junior and high.
type FailLimits struct {
	Elementary int `json:"elementary"`
	Junior     int `json:"junior"`
	High       int `json:"high"`
}

func (f FailLimits) For(level string) int {
	switch level {
	case "elementary":
		return f.Elementary
	case "junior":
		return f.Junior
	case "high":
		return f.High
	default:
		return f.High
	}
}

func DefaultFailLimits() FailLimits {
	return FailLimits{Elementary: 2, Junior: 3, High: 3}
}

type StudentMarks struct {
	ID      string
	Level   string
	Sex     string
	Dropout bool
	Totals  []float64
}

type Standing struct {
	ID             string  `json:"id"`
	Average        float64 `json:"average"`
	Rank           int     `json:"rank"`
	FailedSubjects int     `json:"failed_subjects"`
	PassedSubjects int     `json:"passed_subjects"`
	Status         string  `json:"status"`
}

// Standings ranks by average with competition ranking (1, 2, 2, 4).
// Average is the sum of subject totals divided by the number of subjects,
// rounded to two decimals. Dropouts and students with no subjects are not ranked.
// A student is promoted only when the average is above 50 and the number of
// failed subjects is below the limit for their level.
func Standings(students []StudentMarks, limits FailLimits) []Standing {
	out := make([]Standing, len(students))
	type row struct {
		i   int
		avg float64
	}
	var ranked []row
	for i, s := range students {
		st := Standing{ID: s.ID}
		switch {
		case s.Dropout:
			st.Status = "dropout"
		case len(s.Totals) == 0:
			st.Status = "incomplete"
		default:
			sum := 0.0
			for _, total := range s.Totals {
				sum += total
				if total > 50 {
					st.PassedSubjects++
				} else {
					st.FailedSubjects++
				}
			}
			st.Average = Round2(sum / float64(len(s.Totals)))
			if st.Average > 50 && st.FailedSubjects < limits.For(s.Level) {
				st.Status = "promoted"
			} else {
				st.Status = "failed"
			}
			ranked = append(ranked, row{i: i, avg: st.Average})
		}
		out[i] = st
	}
	sort.Slice(ranked, func(a, b int) bool {
		if ranked[a].avg == ranked[b].avg {
			return out[ranked[a].i].ID < out[ranked[b].i].ID
		}
		return ranked[a].avg > ranked[b].avg
	})
	for n, r := range ranked {
		rank := n + 1
		if n > 0 && ranked[n].avg == ranked[n-1].avg {
			rank = out[ranked[n-1].i].Rank
		}
		out[r.i].Rank = rank
	}
	return out
}
