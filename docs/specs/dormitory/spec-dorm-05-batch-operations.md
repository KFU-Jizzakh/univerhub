# SPEC-DORM-05: Batch Operations & Year-End Close

Mass eviction of residents via a wizard-like flow with best-effort (per-resident independent) execution. Batch operations are recorded with error tracking for audit and reporting.

Depends on: SPEC-CORE-02, SPEC-DORM-01, SPEC-DORM-02, SPEC-DORM-04

Status: IMPLEMENTED

## Acceptance Criteria

- AC-1: Admin, dormitory administrator, and commandant can initiate a batch eviction
- AC-2: The wizard shows 3 steps: building selection → residents selection → reason and parameters
- AC-3: If launched from an academic year show page, that year is pre-selected
- AC-4: A commandant sees only their assigned buildings
- AC-5: Resident selection shows only settled and temporarily absent residents of the chosen building
- AC-6: At least one resident must be selected
- AC-7: Eviction reason is required, chosen from the eviction reasons list excluding "transfer"
- AC-8: A comment is required when the reason is "other"
- AC-9: Each resident is evicted independently (best-effort) — one failure does not block others
- AC-10: Successful evictions are counted; failures are recorded with the resident name and error message
- AC-11: Batch operation status: pending → completed (all succeeded) or partial (some errors occurred)
- AC-12: Batch operation records: total count, success count, error count, timestamps
- AC-13: The results page shows a summary (N of M succeeded) and a table of errors
- AC-14: Batch operation history is available as a list
- AC-15: No active academic year blocks batch eviction initiation
- AC-16: Invalid resident identifiers raise a validation error before processing begins

## UI/UX Notes

- Batch evictions index: table of past operations (year, building, reason, counts, status, date)
- New batch eviction: wizard with step indicators
- Step 1: building dropdown (or card selection)
- Step 2: resident table with checkboxes, "select all" / "deselect all", counter
- Step 3: reason dropdown, comment text area, submit button ("Execute")
- Results: summary stats bar, error table (resident name, error), link to batch detail
- Batch show: full details, error list, performer, timestamps

## Business Rules

- BR-1: A batch operation belongs to an academic year, a building, and an optional performer (user)
- BR-2: The operation type is "mass eviction"
- BR-3: Batch operation statuses: "pending", "completed", "partial"
- BR-4: Processing starts by initializing counters and recording the start time
- BR-5: Each successful eviction increments the success counter
- BR-6: Each failed eviction increments the error counter and records the resident, accommodation, and error message
- BR-7: Processing finishes by setting the completion time and final status
- BR-8: All inputs are validated before the batch is created
- BR-9: Validation errors (no year, no building, no residents, invalid reason, missing comment) prevent processing
- BR-10: Unknown resident identifiers are reported in the validation error message
- BR-11: Each eviction follows the same business rules as an individual eviction
- BR-12: A resident must have an active accommodation in the selected building
- BR-13: Final status is set to "completed" if there are no errors, or "partial" otherwise

## Behavior

### Background
Given academic year "2025/2026" is active
And building "Building A" has room 101 with resident "Ivan Petrov" (settled) and room 102 with resident "Maria Ivanova" (settled)
And admin user "Admin" exists

### Rule: Validation (BR-8, BR-9, BR-10)

#### Scenario: No active year blocks initiation
Given no active academic year
When admin visits the new batch eviction page
Then they are redirected to the dashboard with a "no active year" alert

#### Scenario: No residents selected
When admin submits with an empty resident list
Then a validation error is raised (select at least one resident)

#### Scenario: Invalid eviction reason
When admin submits with reason "transfer"
Then a validation error is raised (transfer is not allowed for batch evictions)

#### Scenario: Reason "other" without comment
When admin submits with reason "other" and no comment
Then a validation error is raised (comment is required)

#### Scenario: Unknown resident identifiers
When admin submits with resident identifiers including a non-existent one
Then a validation error is raised listing the unknown residents

### Rule: Successful Batch Eviction (BR-11, BR-12)

#### Scenario: All evictions succeed
When admin evicts Ivan and Maria with reason "graduation"
Then a batch operation is created with total count 2
And both accommodations are completed with eviction reason "graduation"
And both residents are evicted
And the success count is 2, error count is 0
And the status becomes "completed"
And the start and completion times are recorded

#### Scenario: No active accommodation for a resident
Given Ivan has no active accommodation (already evicted)
And Maria has an active accommodation in room 102
When admin attempts a batch eviction including Ivan
Then Maria is evicted successfully (success count 1)
And Ivan generates an error "no active accommodation" (error count 1)
And the status becomes "partial"

### Rule: Commandant Scope

#### Scenario: Commandant sees only assigned buildings
Given commandant "Dave" is assigned to Building A only
When Dave visits the new batch eviction page
Then the building dropdown shows only Building A
And only residents from Building A are selectable

### Rule: History

#### Scenario: View batch operation history
Given 3 batch operations exist
When admin visits the batch evictions index
Then all 3 are listed with type, building, counts, status, and date
