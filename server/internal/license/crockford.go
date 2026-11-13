package license

import "strings"

// Crockford alphabet. I, L, O and U are omitted.
const alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"

// Clean uppercases, maps O to 0 and I/L to 1, and drops everything else.
func Clean(s string) string {
	var b strings.Builder
	b.Grow(len(s))
	for _, r := range s {
		if r >= 'a' && r <= 'z' {
			r = r - 'a' + 'A'
		}
		switch r {
		case 'O':
			r = '0'
		case 'I', 'L':
			r = '1'
		}
		if (r >= '0' && r <= '9') || (r >= 'A' && r <= 'Z') {
			b.WriteRune(r)
		}
	}
	return b.String()
}

func symbol(c byte) (uint32, bool) {
	if c >= '0' && c <= '9' {
		return uint32(c - '0'), true
	}
	i := strings.IndexByte(alphabet, c)
	if i < 0 {
		return 0, false
	}
	return uint32(i), true
}

// decodeStrict decodes Crockford base32. Leftover padding bits must be zero
// and the character count must be the exact unpadded length for those bytes.
func decodeStrict(cleaned string) ([]byte, error) {
	if cleaned == "" {
		return nil, errLayout
	}
	var bits uint32
	nbits := 0
	out := make([]byte, 0, len(cleaned)*5/8)
	for i := 0; i < len(cleaned); i++ {
		v, ok := symbol(cleaned[i])
		if !ok {
			return nil, errLayout
		}
		bits = (bits << 5) | v
		nbits += 5
		if nbits >= 8 {
			nbits -= 8
			out = append(out, byte(bits>>uint(nbits)))
			bits &= (1 << uint(nbits)) - 1
		}
	}
	if bits != 0 {
		return nil, errLayout
	}
	if len(cleaned) != encodedLen(len(out)) {
		return nil, errLayout
	}
	return out, nil
}

func encodedLen(nBytes int) int {
	return (nBytes*8 + 4) / 5
}

func encode(data []byte) string {
	var bits uint64
	nbits := 0
	out := make([]byte, 0, encodedLen(len(data)))
	for _, b := range data {
		bits = (bits << 8) | uint64(b)
		nbits += 8
		for nbits >= 5 {
			nbits -= 5
			out = append(out, alphabet[(bits>>uint(nbits))&31])
			bits &= (1 << uint(nbits)) - 1
		}
	}
	if nbits > 0 {
		out = append(out, alphabet[(bits<<uint(5-nbits))&31])
	}
	return string(out)
}

// FormatMachineID groups 10 raw bytes as XXXX-XXXX-XXXX-XXXX.
func FormatMachineID(raw []byte) string {
	s := encode(raw)
	if len(s) < 16 {
		return s
	}
	return s[0:4] + "-" + s[4:8] + "-" + s[8:12] + "-" + s[12:16]
}

// FormatCode groups a code in fives: XXXXX-XXXXX-...
func FormatCode(raw []byte) string {
	s := encode(raw)
	var b strings.Builder
	for i := 0; i < len(s); i++ {
		if i > 0 && i%5 == 0 {
			b.WriteByte('-')
		}
		b.WriteByte(s[i])
	}
	return b.String()
}
