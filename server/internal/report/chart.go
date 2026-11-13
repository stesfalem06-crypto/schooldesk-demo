package report

import (
	"bytes"
	"image"
	"image/color"
	"image/draw"
	"image/png"
	"math"
)

// Bars draws a simple bar chart. Labels stay short so they fit under the bars.
func Bars(title string, labels []string, values []float64) []byte {
	const w, h = 880, 460
	img := image.NewRGBA(image.Rect(0, 0, w, h))
	draw.Draw(img, img.Bounds(), &image.Uniform{color.RGBA{255, 255, 255, 255}}, image.Point{}, draw.Src)
	ink := color.RGBA{28, 36, 48, 255}
	green := color.RGBA{14, 124, 102, 255}
	grid := color.RGBA{226, 226, 220, 255}
	fillRect(img, 0, 0, w, 56, color.RGBA{14, 124, 102, 255})
	drawText(img, 24, 18, title, color.RGBA{255, 255, 255, 255})
	if len(labels) == 0 {
		return pngBytes(img)
	}
	maxV := 1.0
	for _, v := range values {
		if v > maxV {
			maxV = v
		}
	}
	left, right, top, bottom := 50, 30, 90, 70
	plotW := w - left - right
	plotH := h - top - bottom
	for i := 0; i <= 4; i++ {
		y := top + plotH*i/4
		fillRect(img, left, y, plotW, 1, grid)
	}
	n := len(labels)
	gap := 16
	barW := (plotW - gap*(n+1)) / n
	if barW < 8 {
		barW = 8
	}
	for i := 0; i < n; i++ {
		v := 0.0
		if i < len(values) {
			v = values[i]
		}
		bh := int(math.Round(float64(plotH-8) * v / maxV))
		x := left + gap + i*(barW+gap)
		y := top + plotH - bh
		fillRect(img, x, y, barW, bh, green)
		label := labels[i]
		if len(label) > 10 {
			label = label[:10]
		}
		drawText(img, x, top+plotH+12, label, ink)
		drawText(img, x, y-16, trimNum(v), ink)
	}
	return pngBytes(img)
}

func trimNum(v float64) string {
	if math.Abs(v-math.Round(v)) < 0.05 {
		return itoa(int(math.Round(v)))
	}
	tenths := int(math.Round(v * 10))
	whole := tenths / 10
	frac := tenths % 10
	if frac < 0 {
		frac = -frac
	}
	return itoa(whole) + "." + itoa(frac)
}

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	neg := n < 0
	if neg {
		n = -n
	}
	var b [12]byte
	i := len(b)
	for n > 0 {
		i--
		b[i] = byte('0' + n%10)
		n /= 10
	}
	if neg {
		i--
		b[i] = '-'
	}
	return string(b[i:])
}

func pngBytes(img image.Image) []byte {
	var buf bytes.Buffer
	_ = png.Encode(&buf, img)
	return buf.Bytes()
}

func fillRect(img *image.RGBA, x, y, w, h int, c color.RGBA) {
	if w <= 0 || h <= 0 {
		return
	}
	draw.Draw(img, image.Rect(x, y, x+w, y+h), &image.Uniform{c}, image.Point{}, draw.Src)
}

// drawText paints a tiny 5x7 glyph run. It is plain on purpose.
func drawText(img *image.RGBA, x, y int, text string, c color.RGBA) {
	col := 0
	for _, r := range text {
		if r >= 'a' && r <= 'z' {
			r = r - 'a' + 'A'
		}
		glyph(img, x+col*7, y, r, c)
		col++
	}
}

func glyph(img *image.RGBA, x, y int, r rune, c color.RGBA) {
	rows, ok := font5[r]
	if !ok {
		rows = font5[' ']
	}
	for row, bits := range rows {
		for col := 0; col < 5; col++ {
			if bits&(1<<uint(4-col)) != 0 {
				px(img, x+col, y+row, c)
			}
		}
	}
}

func px(img *image.RGBA, x, y int, c color.RGBA) {
	if x < 0 || y < 0 || x >= img.Bounds().Dx() || y >= img.Bounds().Dy() {
		return
	}
	img.SetRGBA(x, y, c)
}

// Digits, letters, space, percent and a few marks used on charts.
var font5 = map[rune][7]uint8{
	' ': {0, 0, 0, 0, 0, 0, 0},
	'%': {0b11001, 0b11010, 0b00100, 0b01000, 0b10110, 0b00110, 0},
	'-': {0, 0, 0, 0b11111, 0, 0, 0},
	'.': {0, 0, 0, 0, 0, 0b00100, 0},
	'0': {0b01110, 0b10001, 0b10011, 0b10101, 0b11001, 0b10001, 0b01110},
	'1': {0b00100, 0b01100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110},
	'2': {0b01110, 0b10001, 0b00001, 0b00010, 0b00100, 0b01000, 0b11111},
	'3': {0b11110, 0b00001, 0b00001, 0b01110, 0b00001, 0b00001, 0b11110},
	'4': {0b00010, 0b00110, 0b01010, 0b10010, 0b11111, 0b00010, 0b00010},
	'5': {0b11111, 0b10000, 0b11110, 0b00001, 0b00001, 0b10001, 0b01110},
	'6': {0b00110, 0b01000, 0b10000, 0b11110, 0b10001, 0b10001, 0b01110},
	'7': {0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b01000, 0b01000},
	'8': {0b01110, 0b10001, 0b10001, 0b01110, 0b10001, 0b10001, 0b01110},
	'9': {0b01110, 0b10001, 0b10001, 0b01111, 0b00001, 0b00010, 0b01100},
	'A': {0b01110, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001},
	'B': {0b11110, 0b10001, 0b10001, 0b11110, 0b10001, 0b10001, 0b11110},
	'C': {0b01110, 0b10001, 0b10000, 0b10000, 0b10000, 0b10001, 0b01110},
	'D': {0b11110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b11110},
	'E': {0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b11111},
	'F': {0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b10000},
	'G': {0b01110, 0b10001, 0b10000, 0b10111, 0b10001, 0b10001, 0b01110},
	'H': {0b10001, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001},
	'I': {0b01110, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110},
	'J': {0b00111, 0b00010, 0b00010, 0b00010, 0b00010, 0b10010, 0b01100},
	'K': {0b10001, 0b10010, 0b10100, 0b11000, 0b10100, 0b10010, 0b10001},
	'L': {0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b11111},
	'M': {0b10001, 0b11011, 0b10101, 0b10101, 0b10001, 0b10001, 0b10001},
	'N': {0b10001, 0b11001, 0b10101, 0b10011, 0b10001, 0b10001, 0b10001},
	'O': {0b01110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110},
	'P': {0b11110, 0b10001, 0b10001, 0b11110, 0b10000, 0b10000, 0b10000},
	'Q': {0b01110, 0b10001, 0b10001, 0b10001, 0b10101, 0b10010, 0b01101},
	'X': {0b10001, 0b10001, 0b01010, 0b00100, 0b01010, 0b10001, 0b10001},
	'Z': {0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b10000, 0b11111},
	'R': {0b11110, 0b10001, 0b10001, 0b11110, 0b10100, 0b10010, 0b10001},
	'S': {0b01111, 0b10000, 0b10000, 0b01110, 0b00001, 0b00001, 0b11110},
	'T': {0b11111, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100},
	'U': {0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110},
	'V': {0b10001, 0b10001, 0b10001, 0b10001, 0b01010, 0b01010, 0b00100},
	'W': {0b10001, 0b10001, 0b10001, 0b10101, 0b10101, 0b10101, 0b01010},
	'Y': {0b10001, 0b10001, 0b01010, 0b00100, 0b00100, 0b00100, 0b00100},
}
