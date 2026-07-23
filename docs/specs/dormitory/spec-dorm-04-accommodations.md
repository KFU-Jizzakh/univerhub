# SPEC-DORM-04: Accommodations (Settle, Transfer, Evict)

Core settlement operations: settling a resident into a room, transferring between rooms, and evicting. An accommodation record links a resident to a room for a time period with supporting documents and planned end dates.

Depends on: SPEC-CORE-02, SPEC-DORM-01, SPEC-DORM-02, SPEC-DORM-03, SPEC-DORM-09

Status: IMPLEMENTED

## Acceptance Criteria

- AC-1: Admin, dormitory administrator, and commandant can settle a resident into a room
- AC-2: Settlement validates: resident is not already active, room has capacity, gender restriction matches, room is not under repair
- AC-3: Settlement requires: application number, contract number, start date, planned end date
- AC-4: Settlement requires at least one receipt with an attached payment file (SPEC-DORM-09 AC-9)
- AC-5: File attachments must be PDF, JPEG, or PNG and under 10 MB each
- AC-6: Admin and dormitory administrator can force-settle even when the room is at full capacity (overcrowding)
- AC-7: An active accommodation can be transferred to another room
- AC-8: Transfer completes the old accommodation with reason "transfer" and creates a new one
- AC-9: Transfer validates: new room is available, gender matches, not under repair — same checks as settlement
- AC-10: Transfer requires a receipt with a file for the new accommodation (SPEC-DORM-09 AC-11), and protects against race conditions
- AC-11: An active accommodation can be evicted
- AC-12: Eviction records the actual end date, eviction reason, completes the accommodation, and updates the resident to evicted status
- AC-13: Eviction reason must be from the predefined list
- AC-14: Eviction reason "other" requires a comment
- AC-15: Accommodation statuses: active (initial) → completed or cancelled
- AC-16: Planned end date is required and must be on or after the start date
- AC-17: Overdue accommodations (planned end date passed, still active) are highlighted in the UI
- AC-18: Each accommodation is automatically linked to the current active academic year
- AC-19: A renewal accommodation must reference a previously completed accommodation
- AC-20: Actual end date is required when status is completed or cancelled
- AC-21: Actual end date must not be before the start date and must not be in the future
- AC-22: An active accommodation must not have an actual end date set
- AC-23: The accommodation list is filterable by building, academic year, and status

## UI/UX Notes

- Settlement form: resident selector (or pre-filled from resident page), room selector (filtered by gender), date pickers, document uploads
- Transfer form: new room selector, document uploads, reason dropdown
- Eviction form: reason dropdown (with text area for "other" reason), confirmation dialog
- Accommodation index: table with resident name, room, dates, status badge, overdue indicator (warning highlight)
- Accommodation show: all details, audit events timeline
- Overdue rows shown with warning color and warning icon
- Capacity warning on settlement form when the room is full (only admin and dormitory administrator can force-settle)

## Business Rules

- BR-1: Eviction reasons: transfer, graduation, expulsion, voluntary, violation, repair, other
- BR-2: Settlement: validates preconditions, updates room occupancy, adjusts room status
- BR-3: Force settlement allows bypassing capacity validation, available only to admin and dormitory administrator
- BR-4: Settlement preconditions: resident must not already be active, room must be kept and active, at least one receipt with an attached file must be present (SPEC-DORM-09 BR-7)
- BR-5: Capacity check: room must have available slots unless forced
- BR-6: Transfer: completes the old accommodation, saves the new one, protects against race conditions for both rooms
- BR-7: Transfer documents: the new accommodation must have supporting documents attached
- BR-8: Eviction: validates the eviction, sets actual end date, completes the accommodation, reduces room occupancy, marks the resident as evicted
- BR-9: Room status is recalculated automatically after any occupancy change
- BR-10: A comment is required when eviction reason is "other"
- BR-11: Planned duration is computed as planned end date minus start date
- BR-12: Actual duration is computed as actual end date minus start date (when actual end date is present)
- BR-13: Overdue accommodations: active accommodations where the planned end date has passed
- BR-14: Transfer operations lock both the source and destination rooms to prevent concurrent conflicts

## Behavior

### Background
Given academic year "2025/2026" is active
And resident "Ivan Petrov" exists (not settled, male)
And room 101 exists (Building A, floor 1, capacity 3, free, no gender restriction)

### Rule: Settle (BR-2, BR-3, BR-4, BR-5)

#### Scenario: Successful settlement
When a user settles Ivan into room 101 with start date today, planned end date one year from today, application number "APP-001", contract number "CNT-001", and creates a receipt with payment confirmation
Then the accommodation is created with status "active"
And the resident status changes to "settled", current room becomes 101
And room 101 occupancy increases to 1, status becomes "partially occupied"
And the settlement is recorded in the audit log
And the accommodation is linked to the active year

#### Scenario: Settle without documents fails
When a user tries to settle without attaching any document
Then a validation error about required documents is raised

#### Scenario: Settle resident who is already active fails
Given Ivan is already settled in room 101
When a user tries to settle Ivan into room 102
Then an error is raised (resident already has an active accommodation)

#### Scenario: Settle into full room without force fails
Given room 101 is fully occupied (capacity 3, occupancy 3)
When a user tries to settle Ivan into room 101 without the force flag
Then an error is raised (room is at full capacity)

#### Scenario: Settle into full room with force (admin)
Given an admin user
And room 101 is fully occupied (capacity 3, occupancy 3)
When the admin force-settles Ivan into room 101
Then the accommodation is created
And room 101 transitions to "overcrowded"

#### Scenario: Gender mismatch
Given room 101 has gender restriction "female"
And Ivan is male
When a user tries to settle Ivan into room 101
Then an error is raised (gender does not match room restriction)

#### Scenario: Planned end date before start date fails
When a user sets start date to 2025-09-01 and planned end date to 2025-01-01
Then a validation error is raised (planned date must be after start date)

### Rule: Transfer (BR-6, BR-7)

#### Scenario: Successful transfer
Given Ivan is settled in room 101 (active accommodation)
And room 205 is free, no gender restriction
When a user transfers Ivan to room 205 with new application number "APP-002", contract number "CNT-002", and uploads all required documents
Then the old accommodation is completed with eviction reason "transfer", actual end date today
And room 101 occupancy decreases by 1
And a new accommodation is created in room 205 with status "active"
And room 205 occupancy increases by 1
And the resident remains settled with current room 205
And the transfer and creation are recorded in the audit log

#### Scenario: Transfer without new documents fails
When a user submits a transfer without attaching documents for the new accommodation
Then an error about missing files is raised

#### Scenario: Transfer into full room fails
Given room 205 is fully occupied and the user is not an admin
When a user tries to transfer Ivan to room 205
Then an error about capacity is raised

### Rule: Evict (BR-8, BR-10)

#### Scenario: Successful eviction
Given Ivan is settled in room 101 (active accommodation)
When a user evicts Ivan with reason "graduation"
Then the accommodation is completed with actual end date today and eviction reason "graduation"
And room 101 occupancy decreases by 1
And the resident status changes to "evicted", current room cleared
And the room status is recalculated
And the eviction is recorded in the audit log

#### Scenario: Evict with reason "other" requires comment
When a user submits an eviction with reason "other" and no comment
Then a validation error is raised (comment is required for "other" reason)

#### Scenario: Evict with reason "other" with comment succeeds
When a user submits an eviction with reason "other" and comment "Personal reasons"
Then the eviction succeeds with the comment stored

#### Scenario: Cannot evict non-active accommodation
Given an accommodation is already completed
When a user tries to evict it
Then an error about non-active accommodation is raised

### Rule: Overdue (BR-13)

#### Scenario: Overdue accommodation highlighted
Given Ivan's accommodation is active with planned end date 30 days ago
When viewing the accommodations list
Then the row is highlighted with warning styling
And an overdue indicator is shown
