package engine

// JavaRandom is java.util.Random, the 48-bit linear congruential generator.
// The same seed walks the same search only when this generator is used.
type JavaRandom struct {
	seed int64
}

const (
	javaMultiplier = int64(0x5DEECE66D)
	javaAddend     = int64(0xB)
	javaMask       = (int64(1) << 48) - 1
)

func NewJavaRandom(seed int64) *JavaRandom {
	r := &JavaRandom{}
	r.seed = (seed ^ javaMultiplier) & javaMask
	return r
}

func (r *JavaRandom) next(bits int) int32 {
	r.seed = (r.seed*javaMultiplier + javaAddend) & javaMask
	return int32(r.seed >> (48 - bits))
}

// NextInt returns a value in [0, n).
func (r *JavaRandom) NextInt(n int) int {
	if n <= 0 {
		panic("NextInt bound must be positive")
	}
	if n&(n-1) == 0 {
		return int((int64(n) * int64(uint32(r.next(31)))) >> 31)
	}
	bits := int(r.next(31))
	val := bits % n
	for bits-val+(n-1) < 0 {
		bits = int(r.next(31))
		val = bits % n
	}
	return val
}

// NextDouble matches java.util.Random.nextDouble.
func (r *JavaRandom) NextDouble() float64 {
	hi := int64(r.next(26))
	lo := int64(r.next(27))
	return float64((hi<<27)+lo) / float64(int64(1)<<53)
}
