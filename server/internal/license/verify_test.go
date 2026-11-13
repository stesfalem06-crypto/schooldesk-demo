package license

import (
	"bytes"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"encoding/binary"
	"errors"
	"strings"
	"testing"
	"time"
)

const (
	prodMID  = "Y4MS-W8N9-QME2-0EE3"
	prodCode = "0421E-1C300-M0RJ3-FE1JJ-0GB3C-5J6AV-BSD27-FSFSJ-9XMNT-7PZY8-GG8Z1-05DSV-GH28T-2M9F3-NFJET-MWZVQ-934HS-7T4QJ-QRPWF-RTMKD-ZVEN5-8N1J2-A38ZY-FYH3D-WR1M9-6TFGQ-3EY08"
)

func TestProductionUnlockerVector(t *testing.T) {
	claims, err := VerifyCode(prodMID, prodCode)
	if err != nil {
		t.Fatal(err)
	}
	if claims.SchoolName != "Hope Academy" {
		t.Fatalf("school %q", claims.SchoolName)
	}
	if claims.IssueDate().Format("2006-01-02") != "2026-11-13" {
		t.Fatalf("issued %s day %d", claims.IssueDate().Format("2006-01-02"), claims.IssueDay)
	}
	exp, ok := claims.ExpiryDate()
	if !ok || exp.Format("2006-01-02") != "2027-11-12" {
		t.Fatalf("expiry ok=%v %s day %d", ok, exp.Format("2006-01-02"), claims.ExpiryDay)
	}
	if claims.MaxDevices != 40 || claims.UnlimitedDevices() || claims.NeverExpires() {
		t.Fatalf("devices %+v", claims)
	}
	if claims.IssueDay != 1047 || claims.ExpiryDay != 1411 {
		t.Fatalf("days %d %d", claims.IssueDay, claims.ExpiryDay)
	}
	now := time.Date(2026, 11, 13, 12, 0, 0, 0, time.UTC)
	if err := claims.ValidAt(now); err != nil {
		t.Fatal(err)
	}
	if err := claims.ValidAt(time.Date(2027, 11, 12, 23, 0, 0, 0, time.UTC)); err != nil {
		t.Fatal("expiry day should still be valid")
	}
	if err := claims.ValidAt(time.Date(2027, 11, 13, 0, 0, 0, 0, time.UTC)); err == nil {
		t.Fatal("day after expiry should fail")
	}

	// The same characters with the documented cleaning still verify.
	messy := strings.ToLower(prodCode)
	messy = strings.ReplaceAll(messy, "0", "O")
	messy = strings.ReplaceAll(messy, "1", "l")
	messy = strings.Join(strings.Split(messy, "-"), " ")
	if _, err := VerifyCode("y4ms-w8n9-qme2-oee3", messy); err != nil {
		t.Fatal(err)
	}
	plain := strings.ReplaceAll(prodMID, "-", "")
	if _, err := VerifyCode(plain, strings.ReplaceAll(prodCode, "-", "")); err != nil {
		t.Fatal(err)
	}
}

func TestProductionVectorRejectsOtherMachine(t *testing.T) {
	others := []string{
		"Y4MS-W8N9-QME2-0EE4",
		"Y4MS-W8N9-QME2-0EE2",
		"AAAA-BBBB-CCCC-DDDD",
		"Y4MS-W8N9-QME2-0EE3-EXTRA",
		"",
		"Y4MS-W8N9-QME2",
	}
	for _, mid := range others {
		if _, err := VerifyCode(mid, prodCode); err == nil {
			t.Fatalf("accepted other mid %q", mid)
		}
	}
}

func TestProductionKeyRejectsThrowawaySignature(t *testing.T) {
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	raw := bytes.Repeat([]byte{0x11}, machineBytes)
	code := signCode(priv, raw, 1, 10, 0, 0, "Night School")
	display := FormatMachineID(raw)
	if _, err := VerifyCode(display, code); err == nil {
		t.Fatal("production key accepted a throwaway signature")
	}
	claims, err := verifyWithKey(display, code, pub)
	if err != nil {
		t.Fatal(err)
	}
	if claims.SchoolName != "Night School" || claims.IssueDay != 10 {
		t.Fatalf("%+v", claims)
	}
	if !claims.NeverExpires() || !claims.UnlimitedDevices() {
		t.Fatal("expiry 0 and maxDevices 0 were not kept")
	}
	if _, ok := claims.ExpiryDate(); ok {
		t.Fatal("expiry 0 should not produce a date")
	}
	if err := claims.ValidAt(time.Date(2099, 1, 1, 0, 0, 0, 0, time.UTC)); err != nil {
		t.Fatal(err)
	}
}

func TestEmbeddedKeyMatchesPublished(t *testing.T) {
	pub, err := publicKey()
	if err != nil {
		t.Fatal(err)
	}
	want, err := base64.StdEncoding.DecodeString("ZkcJSxU7JEYxawOUEmoUgoUyxX5EUoGALz3o3DSgEtU=")
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(pub, want) {
		t.Fatalf("embedded key mismatch %x", pub)
	}
}

func TestRejectsLayoutThatIsNotSCH1(t *testing.T) {
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	raw := bytes.Repeat([]byte{0x22}, machineBytes)
	display := FormatMachineID(raw)

	valid := signCode(priv, raw, 1, 3, 0, 1, "Ok")
	if _, err := verifyWithKey(display, valid, pub); err != nil {
		t.Fatal(err)
	}

	cases := []string{
		"",
		"!!!!",
		"SCH1",
		valid[:len(valid)-1],
		valid + "-00000",
		strings.ReplaceAll(valid, "-", "") + "U",
	}
	// Flip the last symbol of a valid code.
	flat := Clean(valid)
	mut := []byte(flat)
	mut[len(mut)-1] = '0'
	if mut[len(mut)-1] == flat[len(flat)-1] {
		mut[len(mut)-1] = '1'
	}
	cases = append(cases, string(mut))

	for _, code := range cases {
		if _, err := verifyWithKey(display, code, pub); err == nil {
			t.Fatalf("accepted bad code %q", code)
		}
	}

	// Signed, but version, name length, or UTF-8 is outside the layout.
	badVersion := signCode(priv, raw, 2, 3, 0, 1, "Ok")
	if _, err := verifyWithKey(display, badVersion, pub); err == nil {
		t.Fatal("accepted version 2")
	}
	longName := strings.Repeat("a", 61)
	if _, err := verifyWithKey(display, signCode(priv, raw, 1, 1, 0, 0, longName), pub); err == nil {
		t.Fatal("accepted 61-byte name")
	}
	exact60 := strings.Repeat("b", 60)
	if _, err := verifyWithKey(display, signCode(priv, raw, 1, 1, 0, 0, exact60), pub); err != nil {
		t.Fatal(err)
	}
	if _, err := verifyWithKey(display, signInvalidUTF8(priv, raw), pub); err == nil {
		t.Fatal("accepted invalid utf-8 name")
	}
	if _, err := verifyWithKey(display, signPadded(priv, raw), pub); err == nil {
		t.Fatal("accepted non-zero padding bits")
	}
	if _, err := verifyWithKey(display, signExtraByte(priv, raw), pub); err == nil {
		t.Fatal("accepted extra byte")
	}
}

func TestMachineIDGolden(t *testing.T) {
	raw, display := MachineID(Parts{Board: "BOARD", CPU: "CPU", Disk: "DISK"})
	if hex := fmtHex(raw); hex != "16ab9f18ecab4e5307ab" {
		t.Fatalf("raw %s", hex)
	}
	if display != "2TNS-Y67C-ND75-61XB" {
		t.Fatalf("display %s", display)
	}
	again, againDisplay := MachineID(Parts{Board: "BOARD", CPU: "CPU", Disk: "DISK"})
	if !bytes.Equal(raw, again) || againDisplay != display {
		t.Fatal("machine id is not stable")
	}
	parsed, err := decodeStrict(Clean(display))
	if err != nil || !bytes.Equal(parsed, raw) {
		t.Fatalf("round trip %x %v", parsed, err)
	}
}

func TestFillMissing(t *testing.T) {
	p := FillMissing("", "cpu", "0000", "guid")
	if p.Board != "G:guid" || p.CPU != "cpu" || p.Disk != "G:guid" {
		t.Fatalf("%+v", p)
	}
}

func signCode(priv ed25519.PrivateKey, machineRaw []byte, ver byte, issue, expiry, maxDev int, name string) string {
	body := makeBody(ver, issue, expiry, maxDev, []byte(name))
	msg := append([]byte("SCH1"), machineRaw...)
	msg = append(msg, body...)
	sig := ed25519.Sign(priv, msg)
	return FormatCode(append(body, sig...))
}

func makeBody(ver byte, issue, expiry, maxDev int, name []byte) []byte {
	body := make([]byte, 8+len(name))
	body[0] = ver
	binary.BigEndian.PutUint16(body[1:3], uint16(issue))
	binary.BigEndian.PutUint16(body[3:5], uint16(expiry))
	binary.BigEndian.PutUint16(body[5:7], uint16(maxDev))
	body[7] = byte(len(name))
	copy(body[8:], name)
	return body
}

func signInvalidUTF8(priv ed25519.PrivateKey, machineRaw []byte) string {
	body := makeBody(1, 1, 0, 0, []byte{0xff, 0xfe})
	msg := append([]byte("SCH1"), machineRaw...)
	msg = append(msg, body...)
	sig := ed25519.Sign(priv, msg)
	return FormatCode(append(body, sig...))
}

func signPadded(priv ed25519.PrivateKey, machineRaw []byte) string {
	body := makeBody(1, 1, 0, 0, []byte("A"))
	msg := append([]byte("SCH1"), machineRaw...)
	msg = append(msg, body...)
	sig := ed25519.Sign(priv, msg)
	blob := append(body, sig...)
	enc := encode(blob)
	// Move the last symbol off zero-padding / data without keeping a valid code.
	b := []byte(enc)
	b[len(b)-1] = 'W'
	if enc[len(enc)-1] == 'W' {
		b[len(b)-1] = 'X'
	}
	return string(b)
}

func signExtraByte(priv ed25519.PrivateKey, machineRaw []byte) string {
	body := makeBody(1, 1, 0, 0, []byte("A"))
	msg := append([]byte("SCH1"), machineRaw...)
	msg = append(msg, body...)
	sig := ed25519.Sign(priv, msg)
	blob := append(append(body, sig...), 0x00)
	return FormatCode(blob)
}

func fmtHex(b []byte) string {
	const hexdigits = "0123456789abcdef"
	out := make([]byte, len(b)*2)
	for i, v := range b {
		out[i*2] = hexdigits[v>>4]
		out[i*2+1] = hexdigits[v&0x0f]
	}
	return string(out)
}

func TestErrorKinds(t *testing.T) {
	_, err := VerifyCode(prodMID, "AAAAA-BBBBB")
	if err == nil || !errors.Is(err, errLayout) && !errors.Is(err, errSignature) {
		// short garbage is a layout failure
		if err == nil {
			t.Fatal("expected error")
		}
	}
}
