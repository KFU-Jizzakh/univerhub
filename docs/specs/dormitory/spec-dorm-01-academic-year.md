# SPEC-DORM-01: Academic Year

Academic year entity with lifecycle `pending → active → closed`, unique active year constraint, and auto-assignment to new accommodations. Used as context for batch operations, exports, and reporting.

Depends on: SPEC-CORE-02

Status: IMPLEMENTED

## Acceptance Criteria

- AC-1: Admin/dormitory.admin can create academic year with `name`, `start_date`, `end_date`
- AC-2: New year starts in `pending` status
- AC-3: User can activate a pending year (transitions to `active`)
- AC-4: System guarantees at most one active year at a time (partial unique index + guard)
- AC-5: Attempt to activate a second year raises validation error `already_active`
- AC-6: Active year can be closed (transitions to `closed`, sets `closed_at`)
- AC-7: Closed year cannot be reopened (no reverse transition)
- AC-8: Closed year cannot be updated (raises validation error)
- AC-9: Only pending years can be discarded (soft-deleted)
- AC-10: New accommodation auto-assigns `academic_year_id` from the current active year
- AC-11: Creating accommodation without an active year raises error
- AC-12: `name` must be unique among kept (non-discarded) records
- AC-13: `start_date < end_date` is validated
- AC-14: Dashboard displays the current active year
- AC-15: Commandant can view (not manage) academic years
- AC-16: All state changes are tracked via OutboxEvent

## UI/UX Notes

- Index: table with name, date range, status badge (pending/active/closed), closed_at
- Show: year details, audit events list, "Activate" / "Close year" buttons with Turbo confirm
- New/Edit form: name, start_date, end_date fields
- Dashboard: info badge showing active year name
- Navigation: "Academic Years" link in dormitory sidebar (visible to admin/dormitory.admin/commandant)

## Business Rules

- BR-1: AASM lifecycle: `pending → (activate) → active → (close) → closed`
- BR-2: `do_activate!` guard checks no other active year exists
- BR-3: `do_close!` is blocked if any active accommodations exist for this year (`has_active_accommodations` error)
- BR-4: `do_close!` sets `closed_at = Time.current` and transitions status
- BR-5: `do_update!` is blocked if year is `closed`
- BR-6: `do_discard!` is blocked unless status is `pending`
- BR-7: `accommodation.before_validation :set_academic_year, on: :create` — sets `academic_year_id`
- BR-8: Scope `active` returns `where(status: :active)`
- BR-9: Scope `ordered` returns `order(start_date: :desc)`
- BR-10: Access: admin/dormitory.admin can manage; commandant can view only

## Behavior

### Background
Given year "2025/2026" exists with status `pending`

### Rule: Lifecycle (BR-1, BR-2)

#### Scenario: Activate first year
Given no active year exists
When admin activates "2025/2026"
Then status changes to `active`
And OutboxEvent `dormitory.academic_year.activated` is created

#### Scenario: Activate second year fails
Given "2025/2026" is already `active`
And year "2026/2027" is `pending`
When admin tries to activate "2026/2027"
Then error `already_active` is raised
And "2026/2027" remains `pending`

#### Scenario: Close year
Given "2025/2026" is `active`
And all accommodations for this year are completed/cancelled
When admin closes "2025/2026"
Then status changes to `closed`
And `closed_at` is set to current time
And OutboxEvent `dormitory.academic_year.closed` is created

#### Scenario: Close year with active accommodations fails
Given "2025/2026" is `active`
And there is 1 active accommodation linked to this year
When admin tries to close "2025/2026"
Then error `has_active_accommodations` is raised
And year remains `active`

### Rule: CRUD (BR-5, BR-6, BR-12)

#### Scenario: Create year
When admin creates year "2026/2027" with start_date=2026-09-01, end_date=2027-06-30
Then year is created with status `pending`
And OutboxEvent `dormitory.academic_year.created` is created

#### Scenario: Create year with end_date before start_date
When admin creates year with start_date=2026-09-01, end_date=2026-01-01
Then validation error `must_be_after_start_date` is raised

#### Scenario: Create year with duplicate name
Given kept year "2025/2026" exists
When admin creates another year with name "2025/2026"
Then validation error `taken` is raised

#### Scenario: Update pending year
Given "2025/2026" is `pending`
When admin updates the name to "2025/26"
Then name is updated
And OutboxEvent `dormitory.academic_year.updated` is created

#### Scenario: Update closed year fails
Given "2025/2026" is `closed`
When admin tries to update name
Then error is raised (closed year cannot be updated)

#### Scenario: Discard pending year
Given "2026/2027" is `pending`
When admin discards it
Then soft-delete is applied (discarded_at set)
And OutboxEvent `dormitory.academic_year.discarded` is created

#### Scenario: Discard active year fails
Given "2025/2026" is `active`
When admin tries to discard it
Then error `cannot_delete_not_pending` is raised

### Rule: Auto-assignment (BR-7)

#### Scenario: Auto-assign active year to new accommodation
Given year "2025/2026" is `active`
When a new accommodation is created
Then accommodation `academic_year_id` is set to "2025/2026".id

#### Scenario: No active year blocks accommodation creation
Given no active year exists
When a new accommodation is created
Then validation error is raised (cannot create accommodation without active year)
