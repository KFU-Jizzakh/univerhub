# SPEC-DORM-03: Residents

Resident entity management with personal data, status lifecycle, photo upload, student ticket uniqueness, and search capabilities.

Depends on: SPEC-CORE-02, SPEC-DORM-02

Status: IMPLEMENTED

## Acceptance Criteria

- AC-1: Admin/dormitory.admin/commandant can create/edit/view residents
- AC-2: Resident has: last_name, first_name, middle_name (optional), gender, date_of_birth, phone (optional), email (optional), student_ticket_number, photo (optional)
- AC-3: Name fields accept only letters, spaces, and hyphens (Unicode-aware regex)
- AC-4: Phone must be in international format (`+` followed by 7-15 digits)
- AC-5: Email must be valid email format (or blank)
- AC-6: Student ticket number must be unique among kept (non-discarded) residents
- AC-7: Gender cannot be changed once resident is settled (mutable when not_settled or evicted)
- AC-8: Resident statuses: not_settled → settled → temporarily_absent → evicted
- AC-9: Resident can be soft-deleted (discarded) only if not settled/temporarily_absent
- AC-10: Residents can be searched by name (ILIKE search on last_name, first_name, middle_name)
- AC-11: Resident list is filterable by status and gender
- AC-12: Photo upload validates format (JPEG/PNG only) and size (max 10 MB)
- AC-13: Student ticket number can be checked via `/check_ticket` endpoint (returns resident or not found)
- AC-14: Residents index returns JSON for building-filtered selection (used in batch eviction wizard)
- AC-15: Commandant sees only residents in their assigned buildings' rooms (or not settled)
- AC-16: All state changes tracked via OutboxEvent

## UI/UX Notes

- Resident index: searchable table with full_name, student_ticket, gender badge, status badge, current room, photo thumbnail
- Filter by status and gender (dropdowns)
- Resident show: card with all fields, photo, current room, accommodations history, audit events
- Resident form: text inputs for names, date picker for DOB, select for gender, phone/email inputs, student ticket, photo upload with preview
- Student ticket checker: Stimulus controller in settlement forms for auto-fill by ticket number
- Name format: Cyrillic + Latin letters, hyphens, spaces (no digits or special chars)

## Business Rules

- BR-1: Gender enum: `male=0`, `female=1`
- BR-2: Status enum: `not_settled=0`, `settled=1`, `temporarily_absent=2`, `evicted=3`
- BR-3: `full_name` = `[last_name, first_name, middle_name].compact_blank.join(" ")`
- BR-4: `date_of_birth` must not be in the future
- BR-5: `student_ticket_number_unique_among_kept` — partial index for uniqueness among non-discarded
- BR-6: `gender_immutable_when_settled` — gender freeze only when `settled? || temporarily_absent?`
- BR-7: `do_discard!` guard: raises error if status is `settled` or `temporarily_absent`
- BR-8: `search_by_name(query)` — ILIKE query sanitized via `sanitize_sql_like`
- BR-9: `current_room` is set/cleared by Accommodation operations, not directly by user
- BR-10: `active_accommodation` scope: `where(status: :active)` — returns the current active accommodation

## Behavior

### Background
Given resident "Ivan Petrov" exists (male, student_ticket "ST-12345", not_settled)
And resident "Maria Ivanova" exists (female, student_ticket "ST-67890", settled, room 101)

### Rule: CRUD (BR-1 through BR-7)

#### Scenario: Create resident with valid data
When user creates resident with last_name="Сидоров", first_name="Петр", gender=male, date_of_birth=2000-05-15, student_ticket_number="ST-99999"
Then resident is created with status `not_settled`
And OutboxEvent `dormitory.resident.created` is logged

#### Scenario: Create resident with invalid name characters
When user sets last_name="Smith123"
Then validation error `invalid_format` is raised

#### Scenario: Create resident with duplicate student ticket
Given kept resident with student_ticket "ST-12345" exists
When user tries to create another resident with student_ticket "ST-12345"
Then validation error about duplicate student ticket is raised

#### Scenario: Create resident with future date of birth
When user sets date_of_birth to tomorrow
Then validation error `date_of_birth_not_in_future` is raised

#### Scenario: Update resident gender while not settled
Given Ivan is not_settled
When user changes Ivan's gender to female
Then gender is updated successfully

#### Scenario: Update resident gender while settled fails
Given Maria is settled
When user tries to change Maria's gender to male
Then error `gender_immutable_when_settled` is raised

### Rule: Discard (BR-7)

#### Scenario: Discard not_settled resident
Given Ivan is not_settled
When user discards Ivan
Then Ivan is soft-deleted
And OutboxEvent `dormitory.resident.discarded` is logged

#### Scenario: Discard settled resident fails
Given Maria is settled
When user tries to discard Maria
Then error `cannot_delete_settled` is raised

### Rule: Search (BR-8)

#### Scenario: Search by last name
When user searches "petrov"
Then Ivan Petrov is returned (case-insensitive match)

#### Scenario: Search by partial name
When user searches "iva"
Then Ivan Petrov and Maria Ivanova are both returned

#### Scenario: Search with SQL injection attempt
When user searches "'; DROP TABLE--"
Then query is sanitized (no SQL injection)

### Rule: Student Ticket Check (BR-5)

#### Scenario: Check existing ticket number
When user checks ticket "ST-12345" via `/dormitory/residents/check_ticket`
Then JSON response: `{ found: true, id: ..., full_name: "Petrov Ivan" }`

#### Scenario: Check unknown ticket number
When user checks ticket "ST-00000"
Then JSON response: `{ found: false }`
