# SPEC-DORM-10: Violations

Учёт и управление нарушениями проживающих в общежитии: фиксация факта нарушения, тип, место, описание, протокол, рассмотрение и его результат.

Depends on: SPEC-CORE-02, SPEC-DORM-03

Status: IMPLEMENTED

## Acceptance Criteria

- AC-1: Admin, dormitory administrator, and commandant can create, edit, view, and delete violations
- AC-2: A violation has: resident (FK), violation type, date of occurrence, place, description, status
- AC-3: A violation can have an attached protocol file (PDF, JPEG, PNG — ≤10 MB)
- AC-4: Violation types are predefined: noise, property_damage, smoking, unauthorized_guests, regime_violation, unsanitary, other
- AC-5: Violation statuses: open → reviewed → closed
- AC-6: When status is reviewed or closed, reviewed_at and review_result are required
- AC-7: When status is changed from reviewed/closed back to open, reviewed_at and review_result must not be present
- AC-8: Date of occurrence must not be in the future
- AC-9: A violation can be soft-deleted (discarded)
- AC-10: The violations list is filterable by type and status
- AC-11: A commandant sees only violations of residents in their assigned buildings
- AC-12: All state changes are recorded in the audit log
- AC-13: Open violations are displayed on the dashboard alerts section
- AC-14: Resident's show page displays their violation history

## UI/UX Notes

- Violation index: table with resident name, type badge, date, status badge, description preview
- Filter by violation type and status (dropdown selectors)
- Violation show: card with all fields, protocol file link, audit events
- Violation form: resident selector, type dropdown, date picker, place text input, description textarea, status dropdown, protocol file upload, reviewed_at date picker, review_result textarea, commandant_comment textarea
- Dashboard: open violations count shown as alert with link to violations index filtered by open status

## Business Rules

- BR-1: Violation types: noise, property_damage, smoking, unauthorized_guests, regime_violation, unsanitary, other
- BR-2: Status values: open, reviewed, closed
- BR-3: Date of occurrence must not be in the future
- BR-4: Protocol file format: PDF, JPEG, PNG — maximum 10 MB
- BR-5: reviewed_at and review_result required when status is reviewed or closed
- BR-6: reviewed_at and review_result must be nil when status is open
- BR-7: Soft-delete via Discard (kept by default)
- BR-8: Commandant scope: violations of residents whose current room building is in commandant's assigned buildings, plus violations of unassigned residents

## Behavior

### Background
Given resident "Ivan Petrov" exists (settled, room 101, Building A)
And resident "Maria Ivanova" exists (not settled)

### Rule: CRUD (BR-1 through BR-7)

#### Scenario: Create violation with valid data
When a user creates a violation for Ivan with type "noise", date today, place "Room 101", description "Loud music after 23:00", status "open"
Then the violation is created
And the creation is recorded in the audit log

#### Scenario: Create violation with future date fails
When a user sets occurred_at to tomorrow
Then a validation error is raised (date must not be in the future)

#### Scenario: Create violation with invalid file format fails
When a user attaches a .doc file as protocol
Then a validation error is raised (invalid file format)

#### Scenario: Update violation status to reviewed
Given a violation with status "open" exists
When a user changes status to "reviewed" and sets reviewed_at and review_result
Then the violation is updated
And the update is recorded in the audit log

#### Scenario: Update violation status to reviewed without reviewed_at fails
When a user changes status to "reviewed" without setting reviewed_at
Then a validation error about required reviewed_at is raised

#### Scenario: Update violation status to closed
Given a violation with status "reviewed" exists
When a user changes status to "closed"
Then the violation is updated (reviewed_at and review_result from reviewed stage are preserved)

#### Scenario: Update violation status back to open
Given a violation with status "reviewed" (reviewed_at and review_result present)
When a user changes status back to "open"
Then a validation error is raised (reviewed_at and review_result must be cleared)

### Rule: Delete (BR-7)

#### Scenario: Soft-delete violation
Given a violation exists
When a user deletes the violation
Then the violation is soft-deleted
And the deletion is recorded in the audit log

### Rule: Commandant scope (BR-8)

#### Scenario: Commandant sees violations for assigned building
Given commandant is assigned to Building A
And Ivan is in Building A (room 101)
When the commandant views violations index
Then Ivan's violations are included

#### Scenario: Commandant sees violations for unassigned residents
Given Maria is not settled (no room)
When the commandant views violations index
Then Maria's violations are included

#### Scenario: Commandant does not see violations for other building
Given another resident in Building B
When the commandant views violations index
Then that resident's violations are excluded

### Rule: Dashboard alerts (AC-13)

#### Scenario: Open violations shown on dashboard
Given 3 violations exist (2 open, 1 closed)
When viewing the dashboard
Then the alerts section shows "2 открытых нарушений"
And clicking navigates to violations filtered by open status
