//go:build schooldeskdemo

package buildinfo

// IsDemo reports whether this binary was built with -tags schooldeskdemo.
func IsDemo() bool { return true }
