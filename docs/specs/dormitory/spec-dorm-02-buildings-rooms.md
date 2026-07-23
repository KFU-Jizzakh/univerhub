# SPEC-DORM-02: Buildings & Rooms

CRUD management for dormitory buildings and rooms. Rooms have a status lifecycle for occupancy tracking and support gender restrictions for settlement rules. Rooms can be created individually or in bulk via a batch creation form with editable preview.

Depends on: SPEC-CORE-02

Status: IMPLEMENTED

## Acceptance Criteria

- AC-1: Admin or dormitory administrator can create, edit, and delete buildings
- AC-2: A building has a name (unique), address, floor count (at least 1), and description
- AC-3: A building can be deleted only if it has no non-deleted rooms
- AC-4: Admin or dormitory administrator can create, edit, and delete rooms
- AC-5: A room belongs to a building and has a number, floor (at least 1), capacity (at least 1), and gender restriction (male, female, or none)
- AC-6: The room floor must not exceed the building's floor count
- AC-7: Room number must be unique within a building
- AC-8: Room capacity cannot be reduced below current occupancy (unless an override flag is used)
- AC-9: A room starts in the "free" status and transitions automatically as residents move in and out
- AC-10: Occupancy increases through normal settlement (free → partially occupied → fully occupied) or force settlement (→ overcrowded)
- AC-11: Occupancy decreases through partial eviction or full eviction (→ free if empty)
- AC-12: Room gender restriction is checked during settlement
- AC-13: A room can be deleted only if it is free and has no current residents
- AC-14: An available rooms list can be filtered by gender and building
- AC-15: The system can suggest the next available room number for a given floor in a building
- AC-16: A commandant sees only the rooms in their assigned buildings
- AC-17: Admin or dormitory administrator can create multiple rooms at once via a batch creation form with editable preview table

## UI/UX Notes

- Buildings index: table with name, address, floor count, stats (room count, occupancy rate)
- Building show: details + list of rooms (paginated) + audit events
- Rooms index: table (number, floor, capacity, occupancy, gender restriction, status badge), filter by building
- Room show: details + active accommodations + audit events
- Room form: building selector, number, floor, capacity, gender restriction selector
- Room number auto-suggest: based on floor and building, suggests the next available number
- Available rooms: provides a list of rooms with free or partial capacity for settlement and transfer forms
- Batch room creation: two-step form — (1) set building, floor, number range, default capacity, and default gender restriction, (2) editable preview table where each row (number, capacity, gender) can be modified or removed before submission

## Business Rules

- BR-1: Buildings do not have a status lifecycle (only rooms track occupancy status)
- BR-2: Room statuses: free (initial) → partially occupied → fully occupied → overcrowded
- BR-3: Settling one resident into a free room transitions it to partially occupied (if capacity > 1) or fully occupied (if capacity = 1)
- BR-4: Settling additional residents into a partially occupied room transitions it to fully occupied when occupancy equals capacity
- BR-5: Force-settling into a fully occupied room transitions it to overcrowded
- BR-6: Removing some residents from a fully occupied room transitions it to partially occupied; from overcrowded, back to fully or partially occupied
- BR-7: Removing all residents transitions the room to free (occupancy becomes 0)
- BR-8: An overcrowded room can be normalized back to fully occupied when occupancy drops back to match capacity
- BR-9: Room occupancy is updated manually as residents move in and out
- BR-10: Capacity validation can be overridden with an explicit override flag
- BR-11: Available rooms are non-deleted, free or partially occupied, and match the requested gender restriction (or have no restriction)
- BR-12: The suggested room number is the highest existing number on the floor plus one
- BR-13: Deletion is blocked unless the room is free and has no current residents
- BR-14: A gender restriction of "none" means any gender is allowed
- BR-15: Batch room creation is atomic — all rooms are created in a single database transaction; if any room fails validation, the entire batch is rolled back
- BR-16: Invalid gender_restriction values submitted from the client are silently sanitized to nil
- BR-17: A non-existent building_id fails with a dedicated error message before the transaction begins
- BR-18: Building can be pre-selected in the batch form via query parameter when navigating from the building page

## Behavior

### Background
Given building "Building A" exists with 5 floors
And room 101 exists (floor 1, capacity 3, free, no gender restriction)

### Rule: Building CRUD

#### Scenario: Create building
When admin creates building "Building B" with address "123 Main St" and 3 floors
Then the building is created
And the creation is recorded in the audit log

#### Scenario: Delete building with rooms fails
Given building "Building A" has room 101
When admin tries to delete "Building A"
Then an error is raised (cannot delete a building that still has rooms)

#### Scenario: Delete empty building succeeds
Given building "Building B" has no rooms
When admin deletes "Building B"
Then the building is soft-deleted
And the deletion is recorded in the audit log

### Rule: Room CRUD

#### Scenario: Create room
When admin creates room number "102", floor 1, capacity 2, in Building A
Then the room is created with status "free" and occupancy 0
And the creation is recorded in the audit log

#### Scenario: Room number unique within building
Given room 101 exists in Building A
When admin creates another room number "101" in Building A
Then a validation error is raised

#### Scenario: Floor exceeds building floor count
When admin creates a room on floor 6 in Building A (which has 5 floors)
Then a validation error is raised (floor must be within the building's range)

#### Scenario: Capacity less than occupancy (without override)
Given room 101 has capacity 3 and occupancy 2
When admin edits capacity to 1 (without the override flag)
Then a validation error is raised

#### Scenario: Capacity change with override flag
Given room 101 has capacity 3 and occupancy 2
When admin edits capacity to 2 with the override flag enabled
Then the capacity is updated to 2

### Rule: Room Status Transitions (BR-3 through BR-8)

#### Scenario: Occupy free room with capacity greater than 1
Given room 101 is free, capacity 3, occupancy 0
When a resident is settled into room 101
Then the room transitions to partially occupied, occupancy becomes 1

#### Scenario: Occupy free room with capacity 1
Given room 101 is free, capacity 1, occupancy 0
When a resident is settled into room 101
Then the room transitions to fully occupied, occupancy becomes 1

#### Scenario: Occupy more on partially occupied room
Given room 101 is partially occupied, capacity 3, occupancy 2
When another resident is settled
Then the room becomes fully occupied, occupancy becomes 3

#### Scenario: Force occupy full room
Given room 101 is fully occupied, capacity 3, occupancy 3
When a force settlement is performed
Then the room transitions to overcrowded, occupancy becomes 4

#### Scenario: Evict partial from full room
Given room 101 is fully occupied, capacity 3, occupancy 3
When one resident is evicted
Then the room transitions to partially occupied, occupancy becomes 2

#### Scenario: Evict all
Given room 101 is fully occupied, capacity 3, occupancy 3
When all residents are evicted
Then the room transitions to free, occupancy becomes 0

#### Scenario: Normalize overcrowded room
Given room 101 is overcrowded, capacity 3, occupancy 3 (occupancy now matches capacity after departures)
When the system recalculates
Then the room transitions to fully occupied

### Rule: Gender Restriction

#### Scenario: Available rooms filtered by gender
Given room 101 has gender restriction "male"
And room 102 has no gender restriction
When querying available rooms for gender "male"
Then both room 101 and room 102 are returned

#### Scenario: Available rooms exclude mismatched gender
Given room 101 has gender restriction "female"
When querying available rooms for gender "male"
Then room 101 is excluded

### Rule: Batch Room Creation (AC-17, BR-15–BR-18)

#### Scenario: Create multiple rooms via batch form
When admin sets building "Building A", floor 3, numbers 301-305, capacity 2, no gender restriction
And admin submits the batch
Then 5 rooms are created on floor 3 with numbers 301 through 305
And all have capacity 2 and no gender restriction
And admin is redirected to the rooms list filtered by the building

#### Scenario: Edit and remove rooms in preview
When admin generates a range of rooms in the preview table
And admin changes the capacity of one row and deletes another row
Then only the remaining rows are created with the modified values

#### Scenario: Duplicate number in batch fails atomically
Given room 101 exists in Building A
When admin submits a batch that includes number 101
Then no rooms are created
And a validation error is shown

#### Scenario: Floor exceeds building range in batch
Given Building A has 5 floors
When admin submits a batch with floor 6
Then no rooms are created
And a validation error is shown

#### Scenario: Non-existent building in batch
When admin submits a batch with a non-existent building_id
Then no rooms are created
And a dedicated building-not-found error message is shown

#### Scenario: Invalid gender_restriction value is sanitized
When admin submits a batch with an invalid gender_restriction value
Then the room is created with gender_restriction set to nil

#### Scenario: Building pre-selection from building page
Given building "Building A" exists
When admin navigates to batch creation from Building A's detail page
Then the building selector is pre-filled with Building A
