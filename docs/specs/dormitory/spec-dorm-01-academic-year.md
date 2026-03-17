# SPEC-DORM-01: Academic Year

Academic year entity with lifecycle (pending → active → closed), a unique active year constraint, and auto-assignment to new accommodations. Used as context for batch operations, exports, and reporting.

Depends on: SPEC-CORE-02

Status: IMPLEMENTED

## Acceptance Criteria

- AC-1: Admin or dormitory administrator can create an academic year with a name, start date, and end date
- AC-2: A new year starts in the "pending" status
- AC-3: A user can activate a pending year, transitioning it to "active"
- AC-4: The system guarantees at most one active year at any time
- AC-5: Attempting to activate a second year raises a validation error
- AC-6: An active year can be closed (transitions to "closed" and records the closure timestamp)
- AC-7: A closed year cannot be reopened
- AC-8: A closed year cannot be edited
- AC-9: Only pending years can be deleted (soft-deleted)
- AC-10: New accommodations are automatically linked to the current active year
- AC-11: Creating an accommodation when no active year exists raises an error
- AC-12: The year name must be unique among non-deleted records
- AC-13: The start date must be before the end date
- AC-14: The dashboard displays the current active year
- AC-15: A commandant can view (but not manage) academic years
- AC-16: All state changes are recorded in the audit log

## UI/UX Notes

- Index: table with name, date range, status badge (pending/active/closed), closure timestamp
- Show: year details, audit events list, "Activate" and "Close year" buttons with confirmation
- New/Edit form: name, start date, end date fields
- Dashboard: info badge showing active year name
- Navigation: "Academic Years" link in dormitory sidebar (visible to admin, dormitory administrator, and commandant)

## Business Rules

- BR-1: Lifecycle: pending → activate → active → close → closed
- BR-2: Activation is blocked if another active year already exists
- BR-3: Closing is blocked if any active accommodations still reference this year
- BR-4: Closing records the closure timestamp and transitions the status
- BR-5: Editing is blocked once a year is closed
- BR-6: Deletion is blocked unless the year is pending
- BR-7: New accommodations are automatically assigned the current active year on creation
- BR-8: Active years can be queried by their "active" status
- BR-9: Years are ordered by start date (newest first) in listings
- BR-10: Access: admin and dormitory administrator can manage; commandant can view only

## Behavior

### Background
Given year "2025/2026" exists with status "pending"

### Rule: Lifecycle (BR-1, BR-2)

#### Scenario: Activate first year
Given no active year exists
When admin activates "2025/2026"
Then status changes to "active"
And the activation is recorded in the audit log

#### Scenario: Activate second year fails
Given "2025/2026" is already active
And year "2026/2027" is pending
When admin tries to activate "2026/2027"
Then an error is raised (only one active year allowed)
And "2026/2027" remains pending

#### Scenario: Close year
Given "2025/2026" is active
And all accommodations for this year are completed or cancelled
When admin closes "2025/2026"
Then status changes to "closed"
And the closure timestamp is set to the current time
And the closure is recorded in the audit log

#### Scenario: Close year with active accommodations fails
Given "2025/2026" is active
And there is 1 active accommodation linked to this year
When admin tries to close "2025/2026"
Then an error is raised (active accommodations exist)
And the year remains active

### Rule: CRUD (BR-5, BR-6)

#### Scenario: Create year
When admin creates year "2026/2027" with start date 2026-09-01, end date 2027-06-30
Then the year is created with status "pending"
And the creation is recorded in the audit log

#### Scenario: Create year with end date before start date
When admin creates a year with start date 2026-09-01, end date 2026-01-01
Then a validation error is raised (end must be after start)

#### Scenario: Create year with duplicate name
Given a non-deleted year "2025/2026" exists
When admin creates another year with name "2025/2026"
Then a validation error is raised (name must be unique)

#### Scenario: Update pending year
Given "2025/2026" is pending
When admin updates the name to "2025/26"
Then the name is updated
And the update is recorded in the audit log

#### Scenario: Update closed year fails
Given "2025/2026" is closed
When admin tries to update the name
Then an error is raised (closed year cannot be edited)

#### Scenario: Delete pending year
Given "2026/2027" is pending
When admin deletes it
Then it is soft-deleted (marked as deleted, not removed from the database)
And the deletion is recorded in the audit log

#### Scenario: Delete active year fails
Given "2025/2026" is active
When admin tries to delete it
Then an error is raised (only pending years can be deleted)

### Rule: Auto-assignment (BR-7)

#### Scenario: Auto-assign active year to new accommodation
Given year "2025/2026" is active
When a new accommodation is created
Then the accommodation is linked to "2025/2026"

#### Scenario: No active year blocks accommodation creation
Given no active year exists
When a new accommodation is created
Then a validation error is raised (cannot create accommodation without an active year)
