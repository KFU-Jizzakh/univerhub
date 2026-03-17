# SPEC-DORM-03: Residents

Resident entity management with personal data, status lifecycle, photo upload, student ticket uniqueness, and search capabilities.

Depends on: SPEC-CORE-02, SPEC-DORM-02

Status: IMPLEMENTED

## Acceptance Criteria

- AC-1: Admin, dormitory administrator, and commandant can create, edit, and view residents
- AC-2: A resident has: last name, first name, middle name (optional), gender, date of birth, phone (optional), email (optional), student ticket number, photo (optional)
- AC-3: Name fields accept only letters, spaces, and hyphens (including Cyrillic and Latin characters)
- AC-4: Phone must be in international format (a "+" followed by 7 to 15 digits)
- AC-5: Email must be a valid email format (or left blank)
- AC-6: Student ticket number must be unique among non-deleted residents
- AC-7: Gender cannot be changed once a resident is settled (it is editable when not settled or already evicted)
- AC-8: Resident statuses: not settled → settled → temporarily absent → evicted
- AC-9: A resident can be deleted (soft-deleted) only if not settled and not temporarily absent
- AC-10: Residents can be searched by name (case-insensitive search on last name, first name, middle name)
- AC-11: The resident list is filterable by status and gender
- AC-12: Photo upload validates format (JPEG/PNG only) and size (maximum 10 MB)
- AC-13: A student ticket number can be checked for existence (returns the resident or "not found")
- AC-14: The resident list can be filtered by building for use in selection workflows (e.g., batch eviction)
- AC-15: A commandant sees only residents in their assigned buildings' rooms, plus residents who are not settled
- AC-16: All state changes are recorded in the audit log

## UI/UX Notes

- Resident index: searchable table with full name, student ticket, gender badge, status badge, current room, photo thumbnail
- Filter by status and gender (dropdown selectors)
- Resident show: card with all fields, photo, current room, accommodations history, audit events
- Resident form: text inputs for names, date picker for date of birth, selector for gender, phone and email inputs, student ticket, photo upload with preview
- Student ticket checker: auto-fill by ticket number in settlement forms
- Name format: Cyrillic and Latin letters, hyphens, spaces (no digits or special characters)

## Business Rules

- BR-1: Gender values: male, female
- BR-2: Status values: not settled, settled, temporarily absent, evicted
- BR-3: Full name is formed by joining last name, first name, and middle name (if present) with spaces
- BR-4: Date of birth must not be in the future
- BR-5: Student ticket number uniqueness applies only among non-deleted residents
- BR-6: Gender is locked (immutable) when the resident is settled or temporarily absent
- BR-7: Deletion is blocked if the resident status is settled or temporarily absent
- BR-8: Name search is case-insensitive and protected against injection attacks
- BR-9: The current room is set and cleared by accommodation operations, not directly by the user
- BR-10: A resident's active accommodation is their current non-completed, non-cancelled accommodation

## Behavior

### Background
Given resident "Ivan Petrov" exists (male, student ticket "ST-12345", not settled)
And resident "Maria Ivanova" exists (female, student ticket "ST-67890", settled, room 101)

### Rule: CRUD (BR-1 through BR-7)

#### Scenario: Create resident with valid data
When a user creates a resident with last name "Сидоров", first name "Петр", gender male, date of birth 2000-05-15, student ticket "ST-99999"
Then the resident is created with status "not settled"
And the creation is recorded in the audit log

#### Scenario: Create resident with invalid name characters
When a user sets last name to "Smith123"
Then a validation error is raised (invalid name format)

#### Scenario: Create resident with duplicate student ticket
Given a non-deleted resident with student ticket "ST-12345" exists
When a user tries to create another resident with student ticket "ST-12345"
Then a validation error about duplicate student ticket is raised

#### Scenario: Create resident with future date of birth
When a user sets date of birth to tomorrow
Then a validation error is raised (date of birth cannot be in the future)

#### Scenario: Update resident gender while not settled
Given Ivan is not settled
When a user changes Ivan's gender to female
Then the gender is updated successfully

#### Scenario: Update resident gender while settled fails
Given Maria is settled
When a user tries to change Maria's gender to male
Then an error is raised (gender is locked for settled residents)

### Rule: Delete (BR-7)

#### Scenario: Delete not-settled resident
Given Ivan is not settled
When a user deletes Ivan
Then Ivan is soft-deleted
And the deletion is recorded in the audit log

#### Scenario: Delete settled resident fails
Given Maria is settled
When a user tries to delete Maria
Then an error is raised (cannot delete a settled resident)

### Rule: Search (BR-8)

#### Scenario: Search by last name
When a user searches for "petrov"
Then Ivan Petrov is returned (case-insensitive match)

#### Scenario: Search by partial name
When a user searches for "iva"
Then both Ivan Petrov and Maria Ivanova are returned

#### Scenario: Search with injection attempt is safe
When a user searches for "'; DROP TABLE--"
Then the query is safely handled (no data loss or injection)

### Rule: Student Ticket Check

#### Scenario: Check existing ticket number
When a user checks ticket "ST-12345"
Then the system responds with: found = true, resident id, full name "Petrov Ivan"

#### Scenario: Check unknown ticket number
When a user checks ticket "ST-00000"
Then the system responds with: found = false
