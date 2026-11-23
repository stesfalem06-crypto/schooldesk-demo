package engine

import (
	"math"
	"time"
)

const roomBlocked = "\x00blocked"

type task struct {
	lessonID     string
	instance     int
	classIndex   int
	subjectIndex int
	teacherIndex int
	duration     int
	fixedRoom    int
}

type rank struct {
	classClashes int
	unplaced     int
	otherClashes int
	extraHard    int
	soft         int
}

func (r rank) less(o rank) bool {
	if r.classClashes != o.classClashes {
		return r.classClashes < o.classClashes
	}
	if r.unplaced != o.unplaced {
		return r.unplaced < o.unplaced
	}
	if r.otherClashes != o.otherClashes {
		return r.otherClashes < o.otherClashes
	}
	if r.extraHard != o.extraHard {
		return r.extraHard < o.extraHard
	}
	return r.soft < o.soft
}

func worstRank() rank {
	return rank{math.MaxInt32, math.MaxInt32, math.MaxInt32, math.MaxInt32, math.MaxInt32}
}

type snapshot struct {
	start []int
	room  []int
}

type world struct {
	school       School
	dayCount     int
	periodCount  int
	breakAfter   *int
	classes      []SchoolClass
	subjects     []Subject
	teachers     []Teacher
	rooms        []Room
	classIndex   map[string]int
	subjectIndex map[string]int
	teacherIndex map[string]int
	roomIndex    map[string]int
	tasks        []task
	frozen       []bool
	initialSlot  []int
	initialRoom  []int
	legal        [][]int
}

func newWorld(school School, locks []Placement) *world {
	w := &world{
		school:       school,
		dayCount:     len(school.Days),
		periodCount:  school.Bell.PeriodCount,
		breakAfter:   school.Bell.EffectiveBreakAfter(),
		classes:      school.ClassesInOrder(),
		subjects:     school.Subjects,
		teachers:     school.Teachers,
		rooms:        school.Rooms,
		classIndex:   map[string]int{},
		subjectIndex: map[string]int{},
		teacherIndex: map[string]int{},
		roomIndex:    map[string]int{},
	}
	for i, c := range w.classes {
		w.classIndex[c.ID] = i
	}
	for i, s := range w.subjects {
		w.subjectIndex[s.ID] = i
	}
	for i, t := range w.teachers {
		w.teacherIndex[t.ID] = i
	}
	for i, r := range w.rooms {
		w.roomIndex[r.ID] = i
	}
	for _, lesson := range school.Lessons {
		classI, okC := w.classIndex[lesson.ClassID]
		subjectI, okS := w.subjectIndex[lesson.SubjectID]
		teacherI, okT := w.teacherIndex[lesson.TeacherID]
		if !okC || !okS || !okT {
			continue
		}
		if lesson.TimesPerWeek <= 0 || (lesson.Duration != 1 && lesson.Duration != 2) {
			continue
		}
		fixed := -1
		if lesson.RoomID != nil {
			if idx, ok := w.roomIndex[*lesson.RoomID]; ok {
				fixed = idx
			}
		}
		for instance := 0; instance < lesson.TimesPerWeek; instance++ {
			w.tasks = append(w.tasks, task{
				lessonID: lesson.ID, instance: instance,
				classIndex: classI, subjectIndex: subjectI, teacherIndex: teacherI,
				duration: lesson.Duration, fixedRoom: fixed,
			})
		}
	}
	n := len(w.tasks)
	w.frozen = make([]bool, n)
	w.initialSlot = make([]int, n)
	w.initialRoom = make([]int, n)
	for i := range w.initialSlot {
		w.initialSlot[i] = -1
		w.initialRoom[i] = -1
	}
	lockMap := map[[2]string]Placement{}
	for _, lock := range locks {
		if !lock.Locked {
			continue
		}
		lockMap[[2]string{lock.LessonID, itoa(lock.Instance)}] = lock
	}
	w.legal = make([][]int, n)
	for i := range w.tasks {
		w.legal[i] = w.legalStarts(w.tasks[i])
		lock, ok := lockMap[[2]string{w.tasks[i].lessonID, itoa(w.tasks[i].instance)}]
		if !ok {
			continue
		}
		if lock.Day < 0 || lock.Day >= w.dayCount || lock.Period < 0 || lock.Period >= w.periodCount {
			continue
		}
		if w.tasks[i].duration == 2 && lock.Period+1 >= w.periodCount {
			continue
		}
		w.frozen[i] = true
		w.initialSlot[i] = lock.Day*w.periodCount + lock.Period
		room := w.tasks[i].fixedRoom
		if lock.RoomID != nil {
			if idx, ok := w.roomIndex[*lock.RoomID]; ok {
				room = idx
			}
		}
		w.initialRoom[i] = room
	}
	return w
}

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	neg := n < 0
	if neg {
		n = -n
	}
	var b [16]byte
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

func (w *world) legalStarts(task task) []int {
	classOff := w.classes[task.classIndex].Off
	subjectOff := w.subjects[task.subjectIndex].Off
	teacherOff := w.teachers[task.teacherIndex].Off
	found := make([]int, 0, w.dayCount*w.periodCount)
	for day := 0; day < w.dayCount; day++ {
		for period := 0; period < w.periodCount; period++ {
			if period+task.duration > w.periodCount {
				continue
			}
			if task.duration == 2 && w.breakAfter != nil && period == *w.breakAfter {
				continue
			}
			open := true
			for offset := 0; offset < task.duration; offset++ {
				at := period + offset
				if w.school.SchoolOff.Blocks(day, at) || classOff.Blocks(day, at) || subjectOff.Blocks(day, at) || teacherOff.Blocks(day, at) {
					open = false
					break
				}
				if task.fixedRoom >= 0 && w.rooms[task.fixedRoom].Off.Blocks(day, at) {
					open = false
					break
				}
			}
			if open {
				found = append(found, day*w.periodCount+period)
			}
		}
	}
	return found
}

func (w *world) roomChoices(task task, slot int, into []int) int {
	if task.fixedRoom >= 0 {
		into[0] = task.fixedRoom
		return 1
	}
	kind := w.subjects[task.subjectIndex].RoomKind
	if kind != RoomLab && kind != RoomICT {
		into[0] = -1
		return 1
	}
	day := slot / w.periodCount
	period := slot % w.periodCount
	count := 0
	for index := range w.rooms {
		if w.rooms[index].Kind != kind {
			continue
		}
		open := true
		for offset := 0; offset < task.duration; offset++ {
			if w.rooms[index].Off.Blocks(day, period+offset) {
				open = false
			}
		}
		if !open {
			continue
		}
		into[count] = index
		count++
	}
	if count == 0 {
		into[0] = -1
		return 1
	}
	return count
}

type live struct {
	world          *world
	n              int
	start          []int
	roomOf         []int
	classCount     [][][]int
	teacherCount   [][][]int
	roomCount      [][][]int
	meet           [][][]int
	load           [][]int
	bits           [][]int
	periodZero     [][]int
	homeToday      [][]bool
	homeroomOf     []int
	roomBuffer     []int
	classClashes   int
	teacherClashes int
	roomClashes    int
	unplaced       int
	soft           int
	extraHard      int
	scored         bool
}

func (w *world) newLive() *live {
	l := &live{world: w, n: len(w.tasks), unplaced: len(w.tasks)}
	l.start = make([]int, l.n)
	l.roomOf = make([]int, l.n)
	for i := range l.start {
		l.start[i] = -1
		l.roomOf[i] = -1
	}
	l.classCount = makeGrid(len(w.classes), w.dayCount, w.periodCount)
	l.teacherCount = makeGrid(len(w.teachers), w.dayCount, w.periodCount)
	if len(w.rooms) > 0 {
		l.roomCount = makeGrid(len(w.rooms), w.dayCount, w.periodCount)
	}
	subN := len(w.subjects)
	if subN < 1 {
		subN = 1
	}
	l.meet = make([][][]int, len(w.classes))
	for i := range l.meet {
		l.meet[i] = make([][]int, subN)
		for j := range l.meet[i] {
			l.meet[i][j] = make([]int, w.dayCount)
		}
	}
	tN := len(w.teachers)
	if tN < 1 {
		tN = 1
	}
	l.load = make([][]int, tN)
	l.bits = make([][]int, tN)
	for i := 0; i < tN; i++ {
		l.load[i] = make([]int, w.dayCount)
		l.bits[i] = make([]int, w.dayCount)
	}
	l.periodZero = make([][]int, len(w.classes))
	l.homeToday = make([][]bool, len(w.classes))
	l.homeroomOf = make([]int, len(w.classes))
	for i := range w.classes {
		l.periodZero[i] = make([]int, w.dayCount)
		for d := range l.periodZero[i] {
			l.periodZero[i][d] = -1
		}
		l.homeToday[i] = make([]bool, w.dayCount)
		l.homeroomOf[i] = -1
		if w.classes[i].HomeroomTeacherID != nil {
			if idx, ok := w.teacherIndex[*w.classes[i].HomeroomTeacherID]; ok {
				l.homeroomOf[i] = idx
			}
		}
	}
	buf := len(w.rooms) + 1
	if buf < 1 {
		buf = 1
	}
	l.roomBuffer = make([]int, buf)
	for index := range w.tasks {
		if w.frozen[index] {
			l.place(index, w.initialSlot[index], w.initialRoom[index])
		}
	}
	return l
}

func makeGrid(a, b, c int) [][][]int {
	if a < 0 {
		a = 0
	}
	out := make([][][]int, a)
	for i := range out {
		out[i] = make([][]int, b)
		for j := range out[i] {
			out[i][j] = make([]int, c)
		}
	}
	return out
}

func (l *live) resetMovable() {
	for index := 0; index < l.n; index++ {
		if !l.world.frozen[index] && l.start[index] >= 0 {
			l.remove(index)
		}
	}
}

func (l *live) place(index, slot, room int) {
	if l.start[index] >= 0 {
		l.remove(index)
	}
	task := l.world.tasks[index]
	day := slot / l.world.periodCount
	period := slot % l.world.periodCount
	l.start[index] = slot
	l.roomOf[index] = room
	l.unplaced--
	for offset := 0; offset < task.duration; offset++ {
		l.add(l.classCount[task.classIndex], day, period+offset, true)
		l.add(l.teacherCount[task.teacherIndex], day, period+offset, false)
		if room >= 0 && len(l.roomCount) > 0 {
			l.addRoom(room, day, period+offset)
		}
	}
	l.scored = false
}

func (l *live) remove(index int) {
	slot := l.start[index]
	if slot < 0 {
		return
	}
	task := l.world.tasks[index]
	day := slot / l.world.periodCount
	period := slot % l.world.periodCount
	room := l.roomOf[index]
	for offset := 0; offset < task.duration; offset++ {
		l.sub(l.classCount[task.classIndex], day, period+offset, true)
		l.sub(l.teacherCount[task.teacherIndex], day, period+offset, false)
		if room >= 0 && len(l.roomCount) > 0 {
			l.subRoom(room, day, period+offset)
		}
	}
	l.start[index] = -1
	l.roomOf[index] = -1
	l.unplaced++
	l.scored = false
}

func (l *live) greedy(rng *JavaRandom) {
	teacherLoad := make([]int, len(l.world.teachers))
	for _, task := range l.world.tasks {
		teacherLoad[task.teacherIndex] += task.duration
	}
	order := make([]int, 0, l.n)
	for i := 0; i < l.n; i++ {
		if !l.world.frozen[i] && l.start[i] < 0 {
			order = append(order, i)
		}
	}
	// Stable: fewest legal starts, then longer duration, then heavier teacher.
	for i := 1; i < len(order); i++ {
		item := order[i]
		j := i
		for j > 0 && taskLess(l.world, teacherLoad, item, order[j-1]) {
			order[j] = order[j-1]
			j--
		}
		order[j] = item
	}
	for _, index := range order {
		bestSlot := -1
		bestRoom := -1
		best := worstRank()
		slots := l.world.legal[index]
		for _, slot := range slots {
			rooms := l.world.roomChoices(l.world.tasks[index], slot, l.roomBuffer)
			for roomIndex := 0; roomIndex < rooms; roomIndex++ {
				l.place(index, slot, l.roomBuffer[roomIndex])
				next := l.rank(rng.NextInt(3))
				if next.less(best) {
					best = next
					bestSlot = slot
					bestRoom = l.roomBuffer[roomIndex]
				}
				l.remove(index)
			}
		}
		if bestSlot >= 0 {
			unplacedRank := l.rank(0)
			l.place(index, bestSlot, bestRoom)
			if l.rank(0).greater(unplacedRank) {
				l.remove(index)
			}
		}
	}
}

func taskLess(w *world, teacherLoad []int, a, b int) bool {
	la := len(w.legal[a])
	lb := len(w.legal[b])
	if la != lb {
		return la < lb
	}
	da := w.tasks[a].duration
	db := w.tasks[b].duration
	if da != db {
		return da > db
	}
	ta := teacherLoad[w.tasks[a].teacherIndex]
	tb := teacherLoad[w.tasks[b].teacherIndex]
	return ta > tb
}

func (r rank) greater(o rank) bool { return o.less(r) }

func (l *live) repair(rng *JavaRandom, deadline int64, anneal bool) {
	best := l.snapshot()
	bestRank := l.rank(0)
	idle := 0
	temperature := 6.0
	for time.Now().UnixNano() < deadline && idle < 1500 {
		pool := l.movablePool()
		if len(pool) == 0 {
			break
		}
		index := pool[rng.NextInt(len(pool))]
		oldSlot := l.start[index]
		oldRoom := l.roomOf[index]
		oldRank := l.rank(0)
		if oldSlot >= 0 {
			l.remove(index)
		}
		chosenSlot := -1
		chosenRoom := -1
		chosen := l.rank(0)
		slots := l.world.legal[index]
		order := make([]int, len(slots))
		for i := range order {
			order[i] = i
		}
		shuffle(order, rng)
		limit := len(order)
		if limit > 28 {
			limit = 28
		}
		for nth := 0; nth < limit; nth++ {
			slot := slots[order[nth]]
			rooms := l.world.roomChoices(l.world.tasks[index], slot, l.roomBuffer)
			for roomIndex := 0; roomIndex < rooms; roomIndex++ {
				l.place(index, slot, l.roomBuffer[roomIndex])
				noise := 0
				if anneal {
					noise = rng.NextInt(2)
				}
				next := l.rank(noise)
				if next.less(chosen) {
					chosen = next
					chosenSlot = slot
					chosenRoom = l.roomBuffer[roomIndex]
				}
				l.remove(index)
			}
		}
		if chosenSlot >= 0 {
			l.place(index, chosenSlot, chosenRoom)
		}
		newRank := l.rank(0)
		accept := false
		if newRank.less(oldRank) {
			accept = true
		} else if newRank.classClashes > oldRank.classClashes || newRank.unplaced > oldRank.unplaced || newRank.otherClashes > oldRank.otherClashes || newRank.extraHard > oldRank.extraHard {
			accept = false
		} else if anneal && temperature > 0.15 && newRank.soft > oldRank.soft && rng.NextDouble() < math.Exp(-float64(newRank.soft-oldRank.soft)/temperature) {
			accept = true
		}
		if !accept {
			if l.start[index] >= 0 {
				l.remove(index)
			}
			if oldSlot >= 0 {
				l.place(index, oldSlot, oldRoom)
			}
			idle++
		} else {
			idle = 0
			now := l.rank(0)
			if now.less(bestRank) {
				bestRank = now
				best = l.snapshot()
			}
		}
		temperature *= 0.997
		if bestRank.classClashes == 0 && bestRank.unplaced == 0 && bestRank.otherClashes == 0 && bestRank.extraHard == 0 && idle > 400 {
			break
		}
	}
	l.restore(best)
}

func (l *live) rank(noise int) rank {
	l.ensureScore()
	return rank{l.classClashes, l.unplaced, l.teacherClashes + l.roomClashes, l.extraHard, l.soft + noise}
}

func (l *live) softOnly() int {
	l.ensureScore()
	return l.soft
}

func (l *live) snapshot() snapshot {
	return snapshot{start: append([]int(nil), l.start...), room: append([]int(nil), l.roomOf...)}
}

func (l *live) restore(s snapshot) {
	for index := 0; index < l.n; index++ {
		if !l.world.frozen[index] && l.start[index] >= 0 {
			l.remove(index)
		}
	}
	for index := 0; index < l.n; index++ {
		if l.world.frozen[index] {
			continue
		}
		if s.start[index] >= 0 {
			l.place(index, s.start[index], s.room[index])
		}
	}
}

func (l *live) toTimetable(softScore int, now int64) Timetable {
	placements := make([]Placement, 0, l.n-l.unplaced)
	for index := 0; index < l.n; index++ {
		slot := l.start[index]
		if slot < 0 {
			continue
		}
		task := l.world.tasks[index]
		var roomID *string
		if l.roomOf[index] >= 0 {
			id := l.world.rooms[l.roomOf[index]].ID
			roomID = &id
		}
		placements = append(placements, Placement{
			LessonID: task.lessonID,
			Instance: task.instance,
			Day:      slot / l.world.periodCount,
			Period:   slot % l.world.periodCount,
			RoomID:   roomID,
			Locked:   l.world.frozen[index],
		})
	}
	placed := len(placements)
	return Timetable{
		Placements:         placements,
		SoftScore:          softScore,
		Summary:            sprintfPlaced(placed, l.n),
		GeneratedAtEpochMs: now,
	}
}

func sprintfPlaced(placed, n int) string {
	return "Placed " + itoa(placed) + " of " + itoa(n) + " lessons."
}

func (l *live) movablePool() []int {
	bad := make([]int, 0)
	for index := 0; index < l.n; index++ {
		if l.world.frozen[index] {
			continue
		}
		if l.start[index] < 0 || l.clashes(index) {
			bad = append(bad, index)
		}
	}
	if len(bad) > 0 {
		return bad
	}
	all := make([]int, 0, l.n)
	for index := 0; index < l.n; index++ {
		if !l.world.frozen[index] {
			all = append(all, index)
		}
	}
	return all
}

func (l *live) clashes(index int) bool {
	slot := l.start[index]
	if slot < 0 {
		return false
	}
	task := l.world.tasks[index]
	day := slot / l.world.periodCount
	period := slot % l.world.periodCount
	for offset := 0; offset < task.duration; offset++ {
		if l.classCount[task.classIndex][day][period+offset] > 1 {
			return true
		}
		if l.teacherCount[task.teacherIndex][day][period+offset] > 1 {
			return true
		}
		room := l.roomOf[index]
		if room >= 0 && len(l.roomCount) > 0 && l.roomCount[room][day][period+offset] > 1 {
			return true
		}
	}
	return false
}

func (l *live) ensureScore() {
	if l.scored {
		return
	}
	for classIndex := range l.meet {
		for subjectIndex := range l.meet[classIndex] {
			for day := range l.meet[classIndex][subjectIndex] {
				l.meet[classIndex][subjectIndex][day] = 0
			}
		}
	}
	for teacherIndex := range l.load {
		for day := range l.load[teacherIndex] {
			l.load[teacherIndex][day] = 0
			l.bits[teacherIndex][day] = 0
		}
	}
	for classIndex := range l.periodZero {
		for day := range l.periodZero[classIndex] {
			l.periodZero[classIndex][day] = -1
			l.homeToday[classIndex][day] = false
		}
	}
	for index := 0; index < l.n; index++ {
		slot := l.start[index]
		if slot < 0 {
			continue
		}
		task := l.world.tasks[index]
		day := slot / l.world.periodCount
		period := slot % l.world.periodCount
		if task.subjectIndex < len(l.meet[task.classIndex]) {
			l.meet[task.classIndex][task.subjectIndex][day]++
		}
		if l.homeroomOf[task.classIndex] == task.teacherIndex {
			l.homeToday[task.classIndex][day] = true
		}
		for offset := 0; offset < task.duration; offset++ {
			at := period + offset
			if task.teacherIndex < len(l.load) {
				l.load[task.teacherIndex][day]++
				l.bits[task.teacherIndex][day] |= 1 << at
			}
			if at == 0 {
				l.periodZero[task.classIndex][day] = task.teacherIndex
			}
		}
	}
	rules := l.world.school.Rules
	softScore := 0
	extra := 0
	spreadW := LevelWeight(rules.Spread)
	avoidW := LevelWeight(rules.AvoidSameDayRepeat)
	balanceW := LevelWeight(rules.BalanceTeacherLoad)
	runW := LevelWeight(rules.LimitConsecutive)
	preferW := LevelWeight(rules.PreferredTime)
	afternoon := l.world.periodCount / 2
	if l.world.breakAfter != nil {
		afternoon = *l.world.breakAfter + 1
	}
	for classIndex := range l.world.classes {
		for subjectIndex := range l.world.subjects {
			if subjectIndex >= len(l.meet[classIndex]) {
				continue
			}
			meetings := 0
			daysUsed := 0
			for day := 0; day < l.world.dayCount; day++ {
				count := l.meet[classIndex][subjectIndex][day]
				if count > 1 && avoidW > 0 {
					softScore += (count - 1) * avoidW
				}
				if count > 0 {
					meetings += count
					daysUsed++
				}
			}
			if meetings > 1 && spreadW > 0 {
				cap := meetings
				if l.world.dayCount < cap {
					cap = l.world.dayCount
				}
				softScore += (cap - daysUsed) * spreadW
			}
		}
	}
	for index := 0; index < l.n; index++ {
		slot := l.start[index]
		if slot < 0 || preferW == 0 {
			continue
		}
		period := slot % l.world.periodCount
		switch l.world.subjects[l.world.tasks[index].subjectIndex].Preferred {
		case PreferMorning:
			if period >= afternoon {
				softScore += preferW * l.world.tasks[index].duration
			}
		case PreferAfternoon:
			if period < afternoon {
				softScore += preferW * l.world.tasks[index].duration
			}
		}
	}
	cap := rules.MaxLessonsPerDay
	for teacherIndex := range l.world.teachers {
		maxLoad := 0
		minLoad := math.MaxInt32
		sum := 0
		for day := 0; day < l.world.dayCount; day++ {
			value := 0
			if teacherIndex < len(l.load) {
				value = l.load[teacherIndex][day]
			}
			sum += value
			if value > maxLoad {
				maxLoad = value
			}
			if value < minLoad {
				minLoad = value
			}
			if value > cap {
				if rules.MaxLessonsStrict {
					extra += value - cap
				} else {
					softScore += (value - cap) * 4
				}
			}
			if runW > 0 && teacherIndex < len(l.bits) {
				run := 0
				longest := 0
				for period := 0; period < l.world.periodCount; period++ {
					if l.bits[teacherIndex][day]&(1<<period) != 0 {
						run++
						if run > longest {
							longest = run
						}
					} else {
						run = 0
					}
					if l.world.breakAfter != nil && *l.world.breakAfter == period {
						run = 0
					}
				}
				if longest > rules.MaxConsecutive {
					softScore += (longest - rules.MaxConsecutive) * runW
				}
			}
		}
		if sum > 0 && balanceW > 0 && maxLoad > minLoad {
			softScore += (maxLoad - minLoad) * balanceW
		}
	}
	if rules.HomeroomFirst != HomeroomOff {
		for classIndex := range l.world.classes {
			teacherI := l.homeroomOf[classIndex]
			if teacherI < 0 {
				continue
			}
			for day := 0; day < l.world.dayCount; day++ {
				if !l.homeToday[classIndex][day] {
					continue
				}
				if l.world.school.SchoolOff.Blocks(day, 0) || l.world.classes[classIndex].Off.Blocks(day, 0) {
					continue
				}
				if l.periodZero[classIndex][day] != teacherI {
					if rules.HomeroomFirst == HomeroomRequire {
						extra += 3
					} else {
						softScore += 5
					}
				}
			}
		}
	}
	l.soft = softScore
	l.extraHard = extra
	l.scored = true
}

func (l *live) add(table [][]int, day, period int, isClass bool) {
	before := table[day][period]
	table[day][period] = before + 1
	if before >= 1 {
		if isClass {
			l.classClashes++
		} else {
			l.teacherClashes++
		}
	}
}

func (l *live) sub(table [][]int, day, period int, isClass bool) {
	table[day][period]--
	if table[day][period] >= 1 {
		if isClass {
			l.classClashes--
		} else {
			l.teacherClashes--
		}
	}
}

func (l *live) addRoom(room, day, period int) {
	before := l.roomCount[room][day][period]
	l.roomCount[room][day][period] = before + 1
	if before >= 1 {
		l.roomClashes++
	}
}

func (l *live) subRoom(room, day, period int) {
	l.roomCount[room][day][period]--
	if l.roomCount[room][day][period] >= 1 {
		l.roomClashes--
	}
}

func shuffle(order []int, rng *JavaRandom) {
	for index := len(order) - 1; index >= 1; index-- {
		swap := rng.NextInt(index + 1)
		order[index], order[swap] = order[swap], order[index]
	}
}

// Solve places every lesson it can. The checker, not the search score, decides
// whether the week is acceptable. Rank order is class clashes, unplaced,
// teacher clashes plus room clashes, extra hard points, then soft points.
func Solve(school School, options SolveOptions) SolveResult {
	options = options.withDefaults()
	blockers := Analyze(school)
	expected := 0
	for _, lesson := range school.Lessons {
		if lesson.TimesPerWeek > 0 {
			expected += lesson.TimesPerWeek
		}
	}
	if len(blockers) > 0 {
		return SolveResult{OK: false, Issues: blockers, Expected: expected, HardConflicts: len(blockers)}
	}
	if expected == 0 {
		issue := problem("There are no lessons yet", "Add lessons, or create a starter plan from your classes and subjects.", "Open Lessons and add what each class is taught.", nil, nil)
		return SolveResult{OK: false, Issues: []Issue{issue}}
	}
	w := newWorld(school, options.Locks)
	live := w.newLive()
	deadline := time.Now().UnixNano() + options.TimeBudgetMs*int64(time.Millisecond)
	const restarts = 4
	best := live.snapshot()
	bestRank := live.rank(0)
	slice := (deadline - time.Now().UnixNano()) / restarts
	if slice < 50*int64(time.Millisecond) {
		slice = 50 * int64(time.Millisecond)
	}
	for restart := 0; restart < restarts; restart++ {
		if time.Now().UnixNano() > deadline {
			break
		}
		live.resetMovable()
		live.greedy(NewJavaRandom(options.Seed + int64(restart)*31))
		repairUntil := deadline
		if now := time.Now().UnixNano(); now+slice < repairUntil {
			repairUntil = now + slice
		}
		live.repair(NewJavaRandom(options.Seed+100+int64(restart)), repairUntil, false)
		got := live.rank(0)
		if got.less(bestRank) {
			bestRank = got
			best = live.snapshot()
		}
		if bestRank.classClashes == 0 && bestRank.unplaced == 0 && bestRank.otherClashes == 0 && bestRank.extraHard == 0 {
			break
		}
	}
	live.restore(best)
	if time.Now().UnixNano() < deadline {
		live.repair(NewJavaRandom(options.Seed+999), deadline, true)
		if live.rank(0).less(bestRank) {
			best = live.snapshot()
		}
		live.restore(best)
	}
	soft := live.softOnly()
	table := live.toTimetable(soft, time.Now().UnixMilli())
	issues := Validate(school, &table)
	ok := true
	hard := 0
	for _, issue := range issues {
		if issue.Severity == SeverityProblem {
			ok = false
			hard++
		}
	}
	return SolveResult{
		OK:            ok,
		Timetable:     &table,
		Issues:        issues,
		Placed:        len(table.Placements),
		Expected:      len(w.tasks),
		HardConflicts: hard,
		SoftScore:     soft,
	}
}
