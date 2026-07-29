# SPEC-DORM-11: Bed/Place Statistics

Displays aggregated bed/place statistics on the building show page, rooms index page, and room show page — total beds, occupied, free, occupancy rate, and room status breakdown.

Depends on: SPEC-DORM-02

Status: IMPLEMENTED

## Acceptance Criteria

- AC-1: Building show page displays a bed statistics summary card with: total beds, occupied beds, free beds, occupancy rate (with progress bar)
- AC-2: Building show page displays room status breakdown: counts for free, partially_occupied, fully_occupied, overcrowded
- AC-3: Rooms index page displays summary cards with: total beds, occupied beds, free beds, occupancy rate
- AC-4: Rooms index table includes an "available slots" column showing free slots per room (capacity - current_occupancy)
- AC-5: Room show page displays available slots and occupancy percentage in the info grid
- AC-6: All statistics respect user scope — commandant sees only data from their assigned buildings

## UI/UX Notes

- Building show: bed stats card inserted above the rooms table (before "Комнаты в корпусе")
- Building show: room status breakdown displayed alongside or below the bed stats card
- Rooms index: summary cards (Total beds / Occupied / Free / Rate) placed above the table, mirroring the dashboard metrics card style
- Rooms index: available_slots column inserted between capacity and gender_restriction in the table
- Room show: available slots and occupancy percentage added to the info-grid section

## Business Rules

- BR-1: Total beds = sum of capacity of all kept rooms in the current scope (building, or all rooms for the index)
- BR-2: Occupied beds = sum of current_occupancy of all kept rooms in scope
- BR-3: Free beds = total beds - occupied beds
- BR-4: Occupancy rate = (occupied beds / total beds × 100), rounded to 1 decimal place; 0 if total beds is 0
- BR-5: Available slots per room = capacity - current_occupancy
- BR-6: Room status counts are aggregated by status across all kept rooms in scope

## Behavior

### Background
Given Building A with 5 floors, containing:
- Room 101 (capacity 3, occupancy 2, partially_occupied)
- Room 102 (capacity 2, occupancy 0, free)
- Room 201 (capacity 4, occupancy 2, partially_occupied)

### Rule: Building bed statistics (BR-1, BR-2, BR-3, BR-4, BR-6)

#### Scenario: Building show displays bed stats summary
When admin visits Building A show page
Then a bed stats card is visible with:
- Total beds = 9 (3+2+4)
- Occupied beds = 4 (2+0+2)
- Free beds = 5
- Occupancy rate = 44.4%
And a room status breakdown shows:
- free = 1
- partially_occupied = 2
- fully_occupied = 0
- overcrowded = 0

#### Scenario: Building with no rooms
Given Building B has no rooms
When admin visits Building B show page
Then total beds = 0, occupied = 0, free = 0, rate = 0%
And room status counts are all 0

### Rule: Rooms index bed statistics (BR-1 through BR-4)

#### Scenario: Rooms index displays aggregated stats
Given rooms across all buildings: room_101, room_102, room_201 (total capacity 9, total occupancy 4)
When admin visits rooms index
Then summary cards show:
- Total beds = 9
- Occupied = 4
- Free = 5
- Occupancy rate = 44.4%

#### Scenario: Rooms index filtered by building
Given admin filters rooms index by Building A
When the filtered index renders
Then summary cards reflect only Building A rooms (capacity 9, occupancy 4)

### Rule: Available slots column (BR-5)

#### Scenario: Rooms index shows available slots per room
When admin visits rooms index
Then each row shows available_slots (capacity - current_occupancy):
- Room 101: 1 slot
- Room 102: 2 slots
- Room 201: 2 slots

#### Scenario: Room show displays available slots and percentage
When admin visits room 201 (capacity 4, occupancy 2)
Then info grid shows available slots = 2
And occupancy percentage = 50.0%
