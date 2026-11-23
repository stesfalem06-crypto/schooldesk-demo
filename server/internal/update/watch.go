package update

import (
	"os"
	"path/filepath"
	"strings"
	"time"
)

// Watch looks for a signed update file on a plugged-in disk.
// It remembers a file it already tried so it does not repeat it.
func Watch(dirs []string, apply func(path string) error, stop <-chan struct{}) {
	seen := map[string]struct{}{}
	tick := time.NewTicker(5 * time.Second)
	defer tick.Stop()
	for {
		select {
		case <-stop:
			return
		case <-tick.C:
			for _, dir := range dirs {
				filepath.WalkDir(dir, func(path string, d os.DirEntry, err error) error {
					if err != nil || d == nil || d.IsDir() {
						if d != nil && d.IsDir() && path != dir && strings.Count(path, string(os.PathSeparator)) > strings.Count(dir, string(os.PathSeparator))+1 {
							return filepath.SkipDir
						}
						return nil
					}
					if !strings.HasSuffix(strings.ToLower(d.Name()), ".smsu") {
						return nil
					}
					if _, ok := seen[path]; ok {
						return nil
					}
					seen[path] = struct{}{}
					_ = apply(path)
					return nil
				})
			}
		}
	}
}

func DefaultDisks() []string {
	var dirs []string
	for _, dir := range []string{"/media", "/mnt", "/run/media"} {
		if st, err := os.Stat(dir); err == nil && st.IsDir() {
			dirs = append(dirs, dir)
		}
	}
	return dirs
}
