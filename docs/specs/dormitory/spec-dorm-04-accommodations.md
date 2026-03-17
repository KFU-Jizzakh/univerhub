# SPEC-DORM-04: Accommodations (Settle, Transfer, Evict)

Core settlement operations: settling a resident into a room, transferring between rooms, and evicting. An accommodation record links a resident to a room for a time period with supporting documents and planned end dates.

Depends on: SPEC-CORE-02, SPEC-DORM-01, SPEC-DORM-02, SPEC-DORM-03

Status: IMPLEMENTED

## Acceptance Criteria

- AC-1: Admin/dormitory.admin/commandant can settle a resident into a room
- AC-2: Settle validates: resident not already active, room capacity, gender restriction, room is not under repair
- AC-3: Settle requires: application number, contract number, start_date, planned_end_date
- AC-4: Settle requires at least one document file (application_file, contract_file, payment_receipt)
- AC-5: File attachments must be PDF/JPEG/PNG and under 10 MB each
- AC-6: Admin/dormitory.admin can force-settle even if room is at capacity (overcrowding)
- AC-7: Active accommodation can be transferred to another room
- AC-8: Transfer creates a new accommodation and completes the old one with reason `transfer`
- AC-9: Transfer validates: new room available, gender matches, not under repair, same as settle
- AC-10: Transfer protects against race conditions via pessimistic locking
- AC-11: Active accommodation can be evicted
- AC-12: Eviction sets actual_end_date, eviction_reason, completes accommodation, updates resident to evicted
- AC-13: Eviction reason must be from `EVICTION_REASONS` list
- AC-14: Eviction reason `other` requires a comment
- AC-15: Accommodation has AASM states: active (initial) → completed / cancelled
- AC-16: `planned_end_date` is required, must be >= start_date
- AC-17: Overdue accommodations (planned_end_date < today, status active) are highlighted in UI
- AC-18: `academic_year_id` is auto-set on create from the current active year
- AC-19: `renewal_source_id` must point to a completed accommodation
- AC-20: `actual_end_date` is required when status is completed or cancelled
- AC-21: `actual_end_date` must not be before start_date and not in the future
- AC-22: Active accommodation must not have `actual_end_date` set
- AC-23: Accommodation list is filterable by building, academic_year, and status

## UI/UX Notes

- Self-settle form: resident selector (or pre-filled from resident page), room selector (JSON filtered by gender), date pickers, document uploads
- Transfer form: new room selector, document uploads, reason dropdown
- Eviction form: reason dropdown (with textarea for "other"), confirm dialog
- Accommodation index: table with resident name, room, dates, status badge, overdue indicator (warning color)
- Accommodation show: all details, audit events timeline
- Overdue rows highlighted with `bg-warning-subtle` class and warning icon
- Capacity warning on settlement form when room is full (only admin/dormitory.admin can force)

## Business Rules

- BR-1: `EVICTION_REASONS`: `transfer`, `graduation`, `expulsion`, `voluntary`, `violation`, `repair`, `other`
- BR-2: `do_settle!(force:)` — validates preconditions, acquires room lock, updates room occupancy, triggers room AASM transition
- BR-3: Force settle allows `skip_capacity_validation` on room, only for admin/dormitory.admin
- BR-4: `validate_settle_preconditions!` — checks resident not already active, room is kept and active
- BR-5: `validate_room_capacity!` — checks `room.available_slots > 0` unless forced
- BR-6: `do_transfer!(new_acc, eviction_reason:)` — completes old accommodation, saves new with `via: :transfer`, uses double pessimistic lock for both rooms
- BR-7: `validate_transfer_files!` — ensures documents are attached to new accommodation
- BR-8: `do_evict!(eviction_reason:, comment:)` — validates eviction, sets actual_end_date, completes accommodation, decrements room occupancy, sets resident to evicted
- BR-9: `recalculate_room_status!` — called after occupancy changes to trigger correct AASM transition
- BR-10: Comment is required when eviction_reason is `"other"`
- BR-11: `planned_duration_days` = planned_end_date - start_date
- BR-12: `actual_duration_days` = actual_end_date - start_date (if actual_end_date present)
- BR-13: Status scope `overdue`: active accommodations where `planned_end_date < Date.current`
- BR-14: Transfer uses `SELECT FOR UPDATE` locks on room IDs sorted to avoid deadlocks

## Behavior

### Background
Given academic year "2025/2026" is active
And resident "Ivan Petrov" exists (not_settled, male)
And room 101 exists (Building A, floor 1, capacity 3, free, no gender restriction)

### Rule: Settle (BR-2, BR-3, BR-4, BR-5)

#### Scenario: Successful settlement
When user settles Ivan into room 101 with start_date=today, planned_end_date=today+1.year, app#="APP-001", contract#="CNT-001", and uploads payment_receipt.pdf
Then accommodation is created with status `active`
And resident status changes to `settled`, current_room=101
And room 101 occupancy increases to 1, status becomes `partially_occupied`
And OutboxEvent `dormitory.accommodation.created` is logged
And `academic_year_id` is set to active year

#### Scenario: Settle without documents fails
When user tries to settle without attaching any document
Then validation error about required documents is raised

#### Scenario: Settle resident who is already active fails
Given Ivan is already settled in room 101
When user tries to settle Ivan into room 102
Then error "resident already has an active accommodation" is raised

#### Scenario: Settle into full room without force fails
Given room 101 is fully_occupied (capacity=3, occupancy=3)
When user tries to settle Ivan into room 101 without force flag
Then error "room is at full capacity" is raised

#### Scenario: Settle into full room with force (admin)
Given admin user
And room 101 is fully_occupied (capacity=3, occupancy=3)
When admin force-settles Ivan into room 101
Then accommodation is created
And room 101 transitions to `overcrowded`

#### Scenario: Gender mismatch
Given room 101 has gender_restriction=female
And Ivan is male
When user tries to settle Ivan into room 101
Then error "gender does not match room restriction" is raised

#### Scenario: planned_end_date before start_date fails
When user sets start_date=2025-09-01 and planned_end_date=2025-01-01
Then validation error "planned date must be after start date" is raised

### Rule: Transfer (BR-6, BR-7)

#### Scenario: Successful transfer
Given Ivan is settled in room 101 (active accommodation)
And room 205 is free, no gender restriction
When user transfers Ivan to room 205 with new app#="APP-002", contract#="CNT-002", and uploads all documents
Then old accommodation is completed with eviction_reason="transfer", actual_end_date=today
And room 101 occupancy decreases by 1
And new accommodation is created in room 205 with status=active
And room 205 occupancy increases by 1
And resident remains settled with current_room=205
And OutboxEvent `dormitory.accommodation.transferred` + `dormitory.accommodation.created` are logged

#### Scenario: Transfer without new documents fails
When user submits transfer without attaching documents for new accommodation
Then error about missing files is raised

#### Scenario: Transfer into full room fails
Given room 205 is fully_occupied and user is not admin
When user tries to transfer Ivan to room 205
Then error about capacity is raised

### Rule: Evict (BR-8, BR-10)

#### Scenario: Successful eviction
Given Ivan is settled in room 101 (active accommodation)
When user evicts Ivan with reason="graduation"
Then accommodation is completed: actual_end_date=today, eviction_reason="graduation"
And room 101 occupancy decreases by 1
And resident status changes to `evicted`, current_room=nil
And room status recalculated
And OutboxEvent `dormitory.accommodation.evicted` is logged

#### Scenario: Evict with reason "other" requires comment
When user submits eviction with reason="other" and no comment
Then validation error "comment is required for 'other' reason" is raised

#### Scenario: Evict with reason "other" with comment succeeds
When user submits eviction with reason="other" and comment="Personal reasons"
Then eviction succeeds with comment stored

#### Scenario: Cannot evict non-active accommodation
Given accommodation is already completed
When user tries to evict it
Then error about non-active accommodation is raised

### Rule: Overdue (BR-13)

#### Scenario: Overdue accommodation highlighted
Given Ivan's accommodation is active with planned_end_date = 30 days ago
When viewing accommodations list
Then the row is highlighted with warning styling
And an overdue indicator is shown
