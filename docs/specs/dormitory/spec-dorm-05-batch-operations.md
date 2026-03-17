# SPEC-DORM-05: Batch Operations & Year-End Close

Mass eviction of residents via a wizard-like flow with best-effort (per-resident independent) execution. Batch operations are recorded with error tracking for audit and reporting.

Depends on: SPEC-CORE-02, SPEC-DORM-01, SPEC-DORM-02, SPEC-DORM-04

Status: IMPLEMENTED

## Acceptance Criteria

- AC-1: Admin/dormitory.admin/commandant can initiate a batch eviction
- AC-2: Wizard shows 3 steps: building selection → residents selection → reason + parameters
- AC-3: If launched from academic year show page, year is pre-selected
- AC-4: Commandant sees only their assigned buildings
- AC-5: Resident selection shows only settled and temporarily_absent residents of the chosen building
- AC-6: At least one resident must be selected
- AC-7: Eviction reason is required, from `EVICTION_REASONS` excluding `transfer`
- AC-8: Comment is required when reason is `"other"`
- AC-9: Each resident is evicted independently (best-effort) — one failure does not block others
- AC-10: Successful evictions increment `success_count`, failures create `BatchOperationError`
- AC-11: Batch operation status: pending → completed (all success) or partial (some errors)
- AC-12: Batch operation records: total_count, success_count, error_count, timestamps
- AC-13: Results page shows summary (N of M succeeded) and error table
- AC-14: Batch operation history is available as a list
- AC-15: No active academic year blocks batch eviction initiation
- AC-16: Invalid resident IDs raise validation error before processing

## UI/UX Notes

- Batch evictions index: table of past operations (year, building, reason, counts, status, date)
- New batch eviction: wizard with step indicators
- Step 1: building dropdown (or card selection)
- Step 2: resident table with checkboxes, "select all"/"deselect all", counter
- Step 3: reason dropdown, comment textarea, submit button ("Execute")
- Results: summary stats bar, error table (resident name, error), link to batch detail
- Batch show: full details, error list, performed_by, timestamps

## Business Rules

- BR-1: `BatchOperation` belongs to `academic_year`, `building`, `performed_by` (User, optional)
- BR-2: `operation_type` must be `"mass_eviction"`
- BR-3: `BatchOperation` statuses: `"pending"`, `"completed"`, `"partial"`
- BR-4: `do_start!(resident_count)` — initializes counters to 0, sets started_at
- BR-5: `record_success!` — increments success_count
- BR-6: `record_error!(resident:, accommodation:, error_message:)` — increments error_count and creates BatchOperationError
- BR-7: `do_complete!(status:)` — sets completed_at and final status
- BR-8: `BatchEvictionService` validates all inputs before creating the batch
- BR-9: Validation errors (no year, no building, no residents, invalid reason, missing comment) raise `ArgumentError`
- BR-10: Unknown resident IDs raise `ArgumentError` with IDs listed in message
- BR-11: Each eviction uses `accommodation.do_evict!` — same invariants as individual eviction
- BR-12: Resident must have an active accommodation in the selected building
- BR-13: `finish!` in ensure block sets status based on error_count presence

## Behavior

### Background
Given academic year "2025/2026" is active
And building "Building A" has room 101 with resident "Ivan Petrov" (settled) and room 102 with resident "Maria Ivanova" (settled)
And admin user "Admin" exists

### Rule: Validation (BR-8, BR-9, BR-10)

#### Scenario: No active year blocks initiation
Given no active academic year
When admin visits new batch eviction page
Then redirect to dashboard with "no active year" alert

#### Scenario: No residents selected
When admin submits with empty resident list
Then `ArgumentError` "select at least one resident" is raised

#### Scenario: Invalid eviction reason
When admin submits with reason="transfer"
Then `ArgumentError` "invalid reason" is raised (transfer is excluded)

#### Scenario: Reason "other" without comment
When admin submits with reason="other" and comment=""
Then `ArgumentError` "comment required" is raised

#### Scenario: Unknown resident IDs
When admin submits with resident_ids including non-existent ID 999
Then `ArgumentError` with "unknown residents: 999" is raised

### Rule: Successful Batch Eviction (BR-11, BR-12)

#### Scenario: All evictions succeed
When admin evicts Ivan and Maria with reason="graduation"
Then BatchOperation is created with total_count=2
And both accommodations are completed with eviction_reason="graduation"
And both residents are evicted
And success_count=2, error_count=0
And status becomes "completed"
And started_at and completed_at are set

#### Scenario: No active accommodation for a resident
Given Ivan has no active accommodation (already evicted)
And Maria has active accommodation in room 102
When admin attempts batch eviction including Ivan
Then Maria is evicted successfully (success_count=1)
And Ivan generates a BatchOperationError "no active accommodation" (error_count=1)
And status becomes "partial"

### Rule: Commandant Scope (BR-2)

#### Scenario: Commandant sees only assigned buildings
Given commandant "Dave" is assigned to Building A only
When Dave visits new batch eviction page
Then building dropdown shows only Building A
And only residents from Building A are selectable

### Rule: History (BR-3, BR-4, BR-7)

#### Scenario: View batch operation history
Given 3 batch operations exist
When admin visits batch evictions index
Then all 3 are listed with type, building, counts, status, date
