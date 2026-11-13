package domain

import (
	"errors"
	"math"
)

type FeeAccount struct {
	Due       float64
	Paid      float64
	Remaining float64
}

// Fee adds payments against the yearly fee. There is no discount.
// A payment that would go past the fee is rejected.
func Fee(due float64, payments []float64) (FeeAccount, error) {
	if badNumber(due) || due < 0 {
		return FeeAccount{}, errors.New("the school fee is not valid")
	}
	var paid float64
	for _, p := range payments {
		if badNumber(p) || p < 0 {
			return FeeAccount{}, errors.New("a payment is not valid")
		}
		paid += p
	}
	due = Round2(due)
	paid = Round2(paid)
	if paid > due {
		return FeeAccount{}, errors.New("payments are more than the fee")
	}
	return FeeAccount{Due: due, Paid: paid, Remaining: Round2(due - paid)}, nil
}

// CanPay reports whether this amount can be recorded. Overpayment is refused.
func CanPay(due, already, amount float64) error {
	if badNumber(amount) || amount <= 0 {
		return errors.New("enter how much was paid")
	}
	if Round2(already+amount) > Round2(due) {
		return errors.New("that is more than the fee still owed")
	}
	return nil
}

func badNumber(n float64) bool {
	return math.IsNaN(n) || math.IsInf(n, 0)
}
