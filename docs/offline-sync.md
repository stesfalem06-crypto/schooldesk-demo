# Offline marks and attendance

The Mac demo keeps the school on this computer. A later Android app will let a teacher write marks and attendance when the phone is away from the school, then send them when the phone is back on the school network.

Nothing in the Mac demo sends or receives those phone records yet. The records are shaped so that work can be added without changing the meaning of a mark or an absence.

## What each record carries

Every attendance row and every mark row stores:

- the class
- the student's roll number
- the student
- the date
- the time it was written (`updated_at`)
- the device that wrote it (`source_id`)

The Mac demo uses the source id `mac-demo`. A phone will use its own id.

Roll numbers in a class run 1, 2, 3 in A-to-Z order of the full name. A student who has left keeps that number. The homeroom teacher or the admin can set the numbers again with Renumber alphabetically.

## When two devices change the same thing

The school keeps one attendance row per student per date, and one mark per student per assessment.

If a second write arrives for that same student and date, or the same student and assessment, the later `updated_at` wins. An older write is kept in the audit list and does not replace the newer one. The audit list records who was changed, which device sent the write, and whether the write was saved or set aside.

The roll number is stored on the record so a phone can show the class list. The match itself uses the student and the date, or the student and the assessment, not the roll number. Renumbering the class does not create a second mark.
