package httpapi

import "encoding/json"

import "schooldesk/internal/engine"

func encodeSchool(school engine.School) ([]byte, error) {
	return json.MarshalIndent(school, "", "    ")
}
