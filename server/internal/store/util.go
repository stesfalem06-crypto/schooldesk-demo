package store

import (
	"errors"
	"strconv"
	"strings"
	"time"
)

func errStr(s string) error { return errors.New(s) }

func bool01(v bool) string {
	if v {
		return "1"
	}
	return "0"
}

func ftoa(n float64) string {
	return strconv.FormatFloat(n, 'f', -1, 64)
}

func validDate(s string) bool {
	_, err := time.Parse("2006-01-02", s)
	return err == nil
}

func validSex(s string) bool { return s == "M" || s == "F" }

func validLevel(s string) bool {
	return s == "elementary" || s == "junior" || s == "high"
}

func validQual(s string) bool {
	switch s {
	case "", "12+certificate", "diploma", "degree", "masters":
		return true
	default:
		return false
	}
}

func validMoney(n float64) bool { return n >= 0 && n < 1e12 && !domainBad(n) }

func domainBad(n float64) bool {
	return n != n // NaN
}

func clean(s string) string { return strings.TrimSpace(s) }
