# SPEC-DORM-02: Buildings & Rooms

CRUD management for dormitory buildings and rooms. Rooms have an AASM state machine for occupancy status and gender restriction for settlement rules.

Depends on: SPEC-CORE-02

Status: IMPLEMENTED

## Acceptance Criteria

- AC-1: Admin/dormitory.admin can create/edit/delete buildings
- AC-2: Building has name (unique), address, floors_count (>=1), description
- AC-3: Building can be discarded only if it has no kept rooms
- AC-4: Admin/dormitory.admin can create/edit/delete rooms
- AC-5: Room belongs to a building, has number, floor (>=1), capacity (>=1), gender_restriction (male/female/nil)
- AC-6: Room floor must not exceed building floors_count
- AC-7: Room number must be unique within a building
- AC-8: Room capacity cannot be reduced below current occupancy (unless force flag)
- AC-9: Room starts in `free` status, transitions automatically via AASM events
- AC-10: Room occupiable events: occupy, occupy_more, force_occupy
- AC-11: Room de-occupancy events: evict_partial, evict_all, normalize
- AC-12: Room gender restriction is checked during settlement
- AC-13: Room can be discarded only if free and empty (no residents)
- AC-14: Available rooms API returns free/partially_occupied rooms filtered by gender and building
- AC-15: Room number suggestion endpoint returns next available number for a floor
- AC-16: Commandant sees only their assigned buildings' rooms

## UI/UX Notes

- Buildings index: table with name, address, floors, stats (room count, occupancy rate)
- Building show: details + list of rooms (paginated) + audit events
- Rooms index: table (number, floor, capacity, occupancy, gender restriction, status badge), filter by building
- Room show: details + active accommodations + audit events
- Room form: building select, number, floor, capacity, gender_restriction select
- Room number auto-suggest via Stimulus controller (floor + building → next number)
- Available rooms: JSON API endpoint for settlement/transfer forms

## Business Rules

- BR-1: Building AASM for rooms is separate from building itself (building has no AASM)
- BR-2: Room AASM states: `free` (initial) → `partially_occupied` → `fully_occupied` → `overcrowded`
- BR-3: `occupy` event: free → partially_occupied (occ=1, cap>1) or free → fully_occupied (occ=1, cap=1)
- BR-4: `occupy_more` event: partially_occupied → partially_occupied (occ+1<cap) or partially_occupied → fully_occupied (occ+1==cap)
- BR-5: `force_occupy` event: fully_occupied → overcrowded (occ+1 > cap)
- BR-6: `evict_partial` event: fully_occupied → partially_occupied, overcrowded → fully_occupied or partially_occupied
- BR-7: `evict_all` event: any → free (occupancy → 0)
- BR-8: `normalize` event: overcrowded → fully_occupied (only if occ == cap)
- BR-9: `current_occupancy` is managed manually (increment!/decrement! in Accommodation), not counter_cache
- BR-10: `skip_capacity_validation` virtual attribute allows bypassing capacity check on update
- BR-11: `available_for(gender, building_id:)` scope: kept, free or partially_occupied, matching gender_restriction
- BR-12: `suggested_number` returns max(number) + 1 for the given building+floor
- BR-13: `do_discard!` guard: room must be free and `empty?` (no current_residents)
- BR-14: Gender restriction `nil` means no restriction (any gender allowed)

## Behavior

### Background
Given building "Building A" exists with 5 floors
And room 101 exists (floor 1, capacity 3, free, no gender restriction)

### Rule: Building CRUD (BR-1)

#### Scenario: Create building
When admin creates building "Building B" with address "123 Main St" and floors_count=3
Then building is created
And OutboxEvent `dormitory.building.created` is logged

#### Scenario: Discard building with rooms fails
Given building "Building A" has room 101
When admin tries to discard "Building A"
Then error `cannot_delete_with_rooms` is raised

#### Scenario: Discard empty building succeeds
Given building "Building B" has no rooms
When admin discards "Building B"
Then building is soft-deleted
And OutboxEvent `dormitory.building.discarded` is logged

### Rule: Room CRUD (BR-2, BR-7)

#### Scenario: Create room
When admin creates room number "102", floor 1, capacity 2, in Building A
Then room is created with status `free` and occupancy 0
And OutboxEvent `dormitory.room.created` is logged

#### Scenario: Room number unique within building
Given room 101 exists in Building A
When admin creates another room number "101" in Building A
Then validation error is raised

#### Scenario: Floor exceeds building floors_count
When admin creates room on floor 6 in Building A (has 5 floors)
Then validation error `floor_within_building_range` is raised

#### Scenario: Capacity less than occupancy (without force)
Given room 101 has capacity=3 and occupancy=2
When admin edits capacity to 1 (without skip_capacity_validation)
Then validation error is raised

#### Scenario: Capacity change with force flag
Given room 101 has capacity=3 and occupancy=2
When admin edits capacity to 2 with skip_capacity_validation=true
Then capacity is updated to 2

### Rule: Room AASM Transitions (BR-3 through BR-8)

#### Scenario: Occupy free room with capacity > 1
Given room 101 is free, capacity=3, occupancy=0
When a resident is settled into room 101
Then room transitions to `partially_occupied`, occupancy=1

#### Scenario: Occupy free room with capacity 1
Given room 101 is free, capacity=1, occupancy=0
When a resident is settled into room 101
Then room transitions to `fully_occupied`, occupancy=1

#### Scenario: Occupy more on partially occupied room
Given room 101 is partially_occupied, capacity=3, occupancy=2
When another resident is settled
Then room becomes `fully_occupied`, occupancy=3

#### Scenario: Force occupy full room
Given room 101 is fully_occupied, capacity=3, occupancy=3
When a force settle is performed
Then room transitions to `overcrowded`, occupancy=4

#### Scenario: Evict partial from full room
Given room 101 is fully_occupied, capacity=3, occupancy=3
When one resident is evicted
Then room transitions to `partially_occupied`, occupancy=2

#### Scenario: Evict all
Given room 101 is fully_occupied, capacity=3, occupancy=3
When all residents are evicted
Then room transitions to `free`, occupancy=0

#### Scenario: Normalize overcrowded room
Given room 101 is overcrowded, capacity=3, occupancy=3
When `normalize` is called (occupancy matches capacity)
Then room transitions to `fully_occupied`

### Rule: Gender Restriction (BR-11, BR-14)

#### Scenario: Available rooms filtered by gender
Given room 101 has gender_restriction=male
And room 102 has gender_restriction=nil
When querying available rooms for gender=male
Then room 101 and room 102 are both returned

#### Scenario: Available rooms exclude mismatched gender
Given room 101 has gender_restriction=female
When querying available rooms for gender=male
Then room 101 is excluded
