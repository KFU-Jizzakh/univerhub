# SPEC-DORM-07: Dashboard

Dormitory dashboard providing aggregated statistics: occupancy rates, room status distribution, resident demographics, overdue accommodations, overcrowded rooms, and recent activity — all scoped by user role (commandants see only their buildings).

Depends on: SPEC-CORE-02, SPEC-DORM-01, SPEC-DORM-02, SPEC-DORM-03, SPEC-DORM-04

Status: IMPLEMENTED

## Acceptance Criteria

- AC-1: Admin/dormitory.admin/commandant can view the dormitory dashboard
- AC-2: Dashboard shows current active academic year (or "No active year" message)
- AC-3: Dashboard shows key metrics: buildings count, rooms count, residents count, total capacity, current occupancy, occupancy rate (%)
- AC-4: Per-building stats: occupancy rate, capacity, current occupancy
- AC-5: Room status distribution: count per state (free, partially_occupied, fully_occupied, overcrowded)
- AC-6: Resident gender distribution: male count, female count
- AC-7: Resident status distribution: settled, temporarily_absent, evicted, not_settled counts
- AC-8: Overcrowded rooms list (rooms where current_occupancy > capacity)
- AC-9: Overdue accommodations list (active with planned_end_date < today)
- AC-10: Recent events (last 10 OutboxEvents from dormitory models)
- AC-11: Commandant sees only data from their assigned buildings
- AC-12: Occupancy rate is calculated as (occupancy / capacity * 100) rounded to 1 decimal

## UI/UX Notes

- Dashboard page: `/dormitory/dashboard`
- Active year badge at the top
- Metrics cards: Buildings, Rooms, Residents, Total Capacity, Occupancy, Rate (%)
- Building stats table: building name, capacity, occupancy, rate
- Room status bar chart or colored badges
- Gender and status distribution as counts
- Overcrowded rooms: warning card with room links
- Overdue accommodations: warning table with resident name, room, planned_end_date
- Recent events: timeline with actor, action, record, timestamp
- All data scoped to user's accessible buildings

## Business Rules

- BR-1: Dashboard access: admin, dormitory.admin, dormitory.commandant only
- BR-2: Buildings scope: commandant → `user.assigned_buildings`; admin/dormitory.admin → all kept buildings
- BR-3: Rooms, residents, accommodations are filtered through building scope
- BR-4: `current_occupancy` aggregation uses `SUM(current_occupancy)` on filtered rooms
- BR-5: Room status counts via `group(:status).count`
- BR-6: Resident gender counts via `group(:gender).count`
- BR-7: Resident status counts via `group(:status).count`
- BR-8: Overcrowded rooms: `WHERE current_occupancy > capacity`
- BR-9: Overdue accommodations: `Accommodation.overdue` scope filtered by room scope
- BR-10: Recent events: OutboxEvent with dormitory record_types, filtered by commandant's building/room/resident/accommodation IDs
- BR-11: Events limited to 10 most recent
- BR-12: Commandant event scope includes OR conditions for each record type + their accessible IDs

## Behavior

### Background
Given admin user exists
And building "A" has room 101 (capacity 3, occupancy 2) and room 102 (capacity 2, occupancy 2, overcrowded with 3)
And resident "Ivan" is settled in room 101 (male)
And resident "Maria" is settled in room 102 (female)
And Ivan's accommodation is overdue (planned_end_date passed)

### Rule: Aggregated Metrics (BR-2, BR-3, BR-4)

#### Scenario: Admin sees all-building stats
When admin visits dashboard
Then buildings_count = 1
And rooms_count = 2
And residents_count = 2
And total_capacity = 5
And current_occupancy = 5 (2+3)
And occupancy_rate = 100.0

#### Scenario: Commandant sees only assigned buildings
Given commandant "Dave" is assigned to Building A only
Given building "B" also exists with rooms (not assigned to Dave)
When Dave visits dashboard
Then data reflects only Building A
And building "B" is excluded from all metrics

### Rule: Distribution Stats (BR-5, BR-6, BR-7)

#### Scenario: Room status distribution
When admin visits dashboard
Then room_status_counts shows: free=0, partially_occupied=1, fully_occupied=0, overcrowded=1

#### Scenario: Gender distribution
When admin visits dashboard
Then resident_gender_counts shows: male=1, female=1

#### Scenario: Status distribution
When admin visits dashboard
Then resident_status_counts shows: settled=2

### Rule: Warnings (BR-8, BR-9)

#### Scenario: Overcrowded rooms
When admin visits dashboard
Then overcrowded_rooms includes room 102 (capacity=2, occupancy=3)

#### Scenario: Overdue accommodations
When admin visits dashboard
Then overdue_accommodations includes Ivan's accommodation (planned_end_date past)

### Rule: Recent Events (BR-10, BR-11)

#### Scenario: Recent dormitory events shown
Given 5 recent OutboxEvents for dormitory records
When admin visits dashboard
Then all 5 events are displayed with actor and action

#### Scenario: Commandant sees only their events
Given 10 events total: 5 from Building A (assigned), 5 from Building B (not assigned)
When commandant Dave visits dashboard
Then only events related to Building A's rooms/residents/accommodations are shown
