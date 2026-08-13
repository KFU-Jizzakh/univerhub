# SPEC-DORM-12: Resident registration with manual place selection

When a resident is created, the registration form is prefilled with the next free place (bed label A/B/C… in a room) as a suggestion; the user confirms it or changes the room and bed manually and the pending accommodation is created for the chosen place. An admin or registrar later confirms (or an admin rejects) the pending accommodation. Rooms can restrict which courses they accept; the course at the moment of settling is snapshotted into the accommodation history.

Depends on: SPEC-DORM-02, SPEC-DORM-03, SPEC-DORM-04

Status: PLANNED

## Data Model

- `Dormitory::Resident#course` — integer, 1..6, required, immutable when settled/temporarily_absent or when a pending accommodation exists.
- `Dormitory::Room#allowed_courses` — integer array (nullable), each value 1..6. `nil` = no course restriction.
- `Dormitory::Accommodation#bed_label` — string (nullable), bed place letter within the room range (A…Z, AA…). Nil when room is overcrowded (force settle) or none chosen.
- `Dormitory::Accommodation#course` — integer snapshot (required, default 1), set once at registration/settle/transfer, immutable (`attr_readonly`), backfilled from `resident.course`.

## Acceptance Criteria

- AC-1: The resident registration form prefills the next free room (respecting building scope, gender restriction, course restriction) and the first free bed label of that room as a suggestion; the user may change the building, room, and bed before saving.
- AC-2: An admin or the registrar can confirm a pending accommodation — resident becomes `settled` with `current_room` set, accommodation becomes `active`, the reserved bed is kept.
- AC-3: An admin can edit a pending accommodation (including changing room/bed) and can reject it — the reservation is released (occupancy decremented, room status recalculated), accommodation becomes `cancelled`.
- AC-4: Every user with registration rights (admin, dormitory.admin, commandant, registrar) must explicitly choose a free room and a free bed label when placement is requested; the room and bed are never assigned automatically.
- AC-5: Documents (application_file, contract_file) are required when placement is requested.
- AC-6: If placement is requested but the user did not select a room or a bed, the resident is not created and the form shows an error.
- AC-7: Rooms can be restricted to one or more courses (`allowed_courses`); a room with no restriction accepts any course.
- AC-8: The accommodation history stores the course at the time of settling (snapshot), not the resident's current course.
- AC-9: When placement is enabled, the registration form shows an optional payment section: required amount for the accommodation (decimal ≥ 0, default 0), receipt amount (> 0), receipt paid date (default today), and a receipt file (PDF/JPEG/PNG, ≤ 10 MB).
- AC-10: The receipt is optional — leaving every receipt field empty creates no receipt and does not block registration.
- AC-11: If any receipt field is filled, the whole receipt must be valid (amount > 0, paid_at present, file attached); otherwise the resident is not created and the form shows the errors.
- AC-12: The receipt is created immediately on the pending accommodation during registration; if the pending accommodation is later rejected, the receipt remains as a financial fact (it is not discarded automatically).

## UI/UX Notes

- Residents new form: course select (1–6, required), a "Issue a place" checkbox (on by default), start date (today) and planned end date (+1 year) when enabled, and the document fields become required when enabled.
- When a validation error occurs, the form re-renders with the offending fields highlighted (Bootstrap `is-invalid` class on the control and the error message below it); the summary alert at the top of the form stays.
- When placement is enabled, a room selection block shows: building select, room select (free rooms filtered by building, gender and course, listing free bed labels), and bed label select (free beds of the chosen room). The selects are prefilled with the next free room and bed and are required.
- The suggestion (next free room and bed) is recalculated when gender or course changes; the user can always override it by choosing another building, room, or bed.
- Pending accommodations show a "Pending confirmation" badge and actions (Confirm / Reject / Edit) on show page; a "pending" filter is added to the accommodations index.
- Room forms (new/edit and batch rooms) include course restriction checkboxes.
- Bed labels appear in room show, accommodation show, and accommodations index.

## Business Rules

- BR-1: Bed labels are generated from `capacity` in Excel-style order: A, B, …, Z, AA, AB, …
- BR-2: A bed is free when no kept accommodation with status `active` or `pending` in the same room uses that label.
- BR-3: The prefilled suggestion order: partially occupied first, then free; then by building, floor, room number. Within a room the lowest free bed label wins.
- BR-4: Gender restriction and course restriction are always enforced on registration, confirmation does not re-check them (room was already validated), but transfer and pending-edit room changes re-check both.
- BR-5: `allowed_courses` cannot be bypassed by users (the check lives in the model layer, used by all settlement/transfer paths).
- BR-6: The accommodation course snapshot is set from `resident.course` at registration and transfer time and never changes afterwards.
- BR-7: A resident can have at most one kept accommodation in `active` or `pending` status (enforced by validation).
- BR-8: Rejecting a pending accommodation decrements room occupancy and recalcs room status; rejecting does not change the resident's status.
- BR-9: A force settlement into a full room leaves `bed_label` empty unless a bed label was explicitly requested; an explicitly requested label is kept even on a full/overcrowded room, and a taken or out-of-range label surfaces as an error.
- BR-10: `bed_label` must belong to the room's label range and must not be taken by another kept accommodation in the same room with status `active`/`pending`.
- BR-11: A room at or above capacity reports no free bed labels, even when some residents have an empty `bed_label` (overcrowded force-settle).
- BR-12: Placement is never automatic: when enabled, a room and a bed label chosen by the user are required. Missing room or bed is a form error and the resident is not created.
- BR-13: The chosen room and bed are used verbatim (no retry on a capacity race) — a failure surfaces as a form error.
- BR-14: An already-overcrowded room accepts further force settlements: occupancy increments and the room status stays `overcrowded`.
- BR-15: The `dormitory.accommodation.created` audit payload records the final assigned bed label, not the requested parameter.
- BR-16: The chosen room must belong to the user's room scope (commandant — assigned buildings only); an out-of-scope or unknown room is a form error.
- BR-17: The suggestion is restricted to the user's room scope and is always overridable; it is only a prefill, never a reservation.
- BR-18: `required_amount` on the accommodation is a non-negative decimal, default 0; a negative value is a form error.
- BR-19: The receipt attached at registration is created via `do_create!` (audit event `dormitory.receipt.created`) inside the same transaction as the resident and the pending accommodation.
- BR-20: The presence of any receipt field (file, amount, or paid date) marks the receipt as requested; a requested receipt must pass all Receipt validations or the whole registration fails.
- BR-20a: When a receipt is requested but the paid date is blank, it defaults to today at creation. The registration form never pre-fills the paid date, so an untouched form does not request a receipt.
- BR-21: A receipt requested at registration is kept when the pending accommodation is later rejected — it documents money actually received.

## Behavior

### Background

Given the following rooms in Building A:
- Room 201 (capacity 4, gender none, allowed_courses [1, 2], occupancy 2, partially_occupied)
- Room 101 (capacity 3, gender none, allowed_courses nil, occupancy 0, free)
- Room 102 (capacity 2, gender female, allowed_courses nil, occupancy 0, free)
And a registrar user with access to Building A.

### Rule: Manual place selection on resident creation (AC-4, AC-6, BR-12)

#### Scenario: Happy path — prefilled suggestion submitted as is

When a registrar creates a resident with course 1, gender male, placement enabled
And the form is prefilled with Room 201 and the first free label of Room 201
And the registrar submits the form without changes
Then the pending accommodation is placed in Room 201
And `bed_label` equals the first free label of Room 201
And the resident status stays `not_settled`

#### Scenario: Registrar changes the room and bed

When a registrar creates a resident with placement enabled
And chooses Room 101 with bed label "B" instead of the prefilled suggestion
Then the pending accommodation is placed in Room 101 with `bed_label` "B"

#### Scenario: Placement without a chosen room

When a registrar creates a resident with placement enabled but no room selected
Then the resident is not created
And the form shows the "select a room" error

#### Scenario: Placement without a chosen bed

When a registrar creates a resident with placement enabled and a room selected but no bed chosen
Then the resident is not created
And the form shows the "select a bed" error

#### Scenario: Room outside the user's scope

Given a commandant assigned only to Building A
When the commandant creates a resident with placement enabled and selects a room from Building B
Then the resident is not created
And the form shows the "select a room" error

#### Scenario: Taken bed label errors

Given Room 201 with labels [A, B, C, D] and bed "A" occupied
When a registrar creates a resident with placement enabled and selects bed label "A" in Room 201
Then the registration fails with a `taken_in_room` error

### Rule: Suggestion recalculates on gender and course change (BR-3, BR-17)

#### Scenario: Course restriction narrows the suggestion

When a registrar selects course 3 in the form
Then Room 201 is not offered (allowed_courses [1, 2])
And the suggestion becomes Room 101

#### Scenario: Gender restriction applies

When a registrar selects gender male
Then Room 102 (gender female) is not offered

#### Scenario: No free room to suggest

Given all compatible rooms are fully occupied
When a registrar enables placement
Then the room select offers no rooms
And submitting the form fails with the "select a room" error

### Rule: Documents required (AC-5)

#### Scenario: Placement without documents

When a resident is created with placement enabled but no application/contract files
Then creation fails with "files required"
And no resident is persisted

### Rule: Admin / registrar confirm, admin reject (AC-2, AC-3, BR-7, BR-8)

#### Scenario: Confirm

When an admin or registrar confirms the pending accommodation
Then the accommodation becomes `active`
And the resident becomes `settled` with `current_room` = the reserved room
And the bed reservation is kept

#### Scenario: Reject

When an admin rejects the pending accommodation
Then the accommodation becomes `cancelled`
And room occupancy is decremented and room status recalculated
And the resident stays `not_settled`

#### Scenario: Registrar cannot reject

When a registrar rejects the pending accommodation
Then the request is denied
And the accommodation stays `pending`

#### Scenario: Reject — validation failure

Given the pending accommodation has a start date in the future
When an admin rejects the pending accommodation
Then the rejection fails (the cancellation is not persisted)
And room occupancy is NOT decremented and the place is not released
And no `rejected` event is recorded
And the accommodation stays `pending`

#### Scenario: Confirm — persistence failure

Given the pending accommodation already has an `actual_end_date` set (fails the no-end-date-when-active validation on save)
When an admin confirms the pending accommodation
Then the confirmation fails (the activation is not persisted)
And the resident stays `not_settled` with no `current_room`
And the accommodation stays `pending`

#### Scenario: Edit — change room and bed

When an admin edits the pending accommodation to another compatible room and bed
Then the old room is released (occupancy decremented) and the new room reserves the bed
And the accommodation course snapshot stays at the resident's course

#### Scenario: Edit — course-conflicting room

When an admin edits the pending accommodation to a room that does not allow the resident's course
Then the edit fails with a course conflict error

#### Scenario: Edit — gender-conflicting room

Given the pending accommodation's resident is male
And the target room has gender restriction female
When an admin edits the pending accommodation to the target room
Then the edit fails with a gender conflict error
And the old room keeps its occupancy (the place is not released)

### Rule: Course snapshot (AC-8, BR-6)

#### Scenario: Snapshot at settle and transfer

Given a resident with course 2
When the pending accommodation is confirmed
Then the accommodation's `course` equals 2
And when the resident's course later changes to 3 (while settled), the accommodation `course` stays 2

### Rule: Overcrowded force settle (BR-9)

#### Scenario: Force settle with no free bed

When an admin force-settles a resident into a fully occupied room
Then the accommodation is created with `bed_label` empty
And room occupancy increments beyond capacity (overcrowded)

#### Scenario: Explicit bed label kept on force settle (BR-9)

Given a full room with capacity 2 and occupancy 2, whose residents hold labels [A, nil]
When an admin force-settles a resident with an explicitly requested `bed_label` "B"
Then the accommodation is created with `bed_label` "B"
And room occupancy increments beyond capacity (overcrowded)

#### Scenario: Taken bed label errors on force settle (BR-9)

Given a full room with capacity 2 and occupancy 2, whose residents hold labels [A, nil]
When an admin force-settles a resident with an explicitly requested `bed_label` "A"
Then the registration fails with a `taken_in_room` error

#### Scenario: Force settle into an already overcrowded room (BR-14)

Given an overcrowded room with capacity 2 and occupancy 3 (status `overcrowded`)
When an admin force-registers a resident
Then the pending accommodation is created
And room occupancy increments to 4
And the room status stays `overcrowded`

#### Scenario: No phantom free beds in an overcrowded room (BR-11)

Given an overcrowded room with capacity 2 and occupancy 3, whose residents hold labels [A, nil, nil]
When the free bed labels are requested
Then the result is empty

#### Scenario: Audit records the assigned bed label (BR-15)

When a resident is registered with a chosen bed label
Then the `dormitory.accommodation.created` audit payload `bed_label` equals the chosen label

### Rule: Room course restriction definition (AC-7, BR-5)

#### Scenario: Restrict rooms in batch

When an admin creates rooms in batch with allowed_courses [1, 3]
Then each room persists `allowed_courses = [1, 3]`
And a resident of course 2 cannot be placed there (registration fails or room is not offered)

### Rule: Receipt and required amount at registration (AC-9, AC-10, AC-11, AC-12, BR-18, BR-19, BR-20, BR-21)

#### Scenario: Register with amount and receipt

When a registrar creates a resident with placement enabled, required_amount = 12000,
  and a receipt: amount = 5000, paid_at = today, file = receipt1.pdf
Then the resident is created
And the pending accommodation has required_amount = 12000
And a receipt is created on the pending accommodation with amount = 5000 and the file attached
And the `dormitory.receipt.created` audit event is recorded
And the accommodation `total_paid` = 5000 and `balance` = -7000

#### Scenario: Receipt without amount

When a registrar creates a resident with placement enabled and fills a receipt amount but no file
Then the resident is not created
And the form shows the receipt file error

#### Scenario: Amount without receipt file

When a registrar creates a resident with placement enabled and attaches a receipt file but leaves the amount empty
Then the resident is not created
And the form shows the receipt amount error

#### Scenario: Empty payment section

When a registrar creates a resident with placement enabled and leaves the payment section empty
Then the resident is created
And the pending accommodation has required_amount = 0
And no receipt is created

#### Scenario: Negative required amount

When a registrar creates a resident with placement enabled and required_amount = -100
Then the resident is not created
And the form shows the required amount error

#### Scenario: Receipt survives a later rejection

Given a resident registered with a receipt on the pending accommodation
When an admin rejects the pending accommodation
Then the accommodation becomes `cancelled`
And the receipt stays attached with the same amount and file
