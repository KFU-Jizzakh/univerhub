# SPEC-DORM-07: Dashboard

Dormitory dashboard providing aggregated statistics: occupancy rates, room status distribution, resident demographics, overdue accommodations, overcrowded rooms, and recent activity — all scoped by user role (commandants see only their buildings).

Depends on: SPEC-CORE-02, SPEC-DORM-01, SPEC-DORM-02, SPEC-DORM-03, SPEC-DORM-04, SPEC-DORM-09

Status: IMPLEMENTED

## Acceptance Criteria

- AC-1: Admin, dormitory administrator, and commandant can view the dormitory dashboard
- AC-2: Dashboard shows the current active academic year (or a "No active year" message)
- AC-3: Dashboard shows key metrics: buildings count, rooms count, residents count, total capacity, current occupancy, occupancy rate (percentage), total debt (absolute sum of negative balances across active accommodations)
- AC-4: Per-building stats: occupancy rate, capacity, current occupancy
- AC-5: Room status distribution: count per state (free, partially occupied, fully occupied, overcrowded)
- AC-6: Resident gender distribution: male count, female count
- AC-7: Resident status distribution: settled, temporarily absent, evicted, not settled counts
- AC-8: Overcrowded rooms list (rooms where current occupancy exceeds capacity)
- AC-9: Overdue accommodations list (active accommodations where planned end date has passed)
- AC-10: Recent events (last 10 audit log entries from dormitory records)
- AC-11: Commandant sees only data from their assigned buildings
- AC-12: Occupancy rate is calculated as (total occupancy / total capacity × 100), rounded to 1 decimal place
- AC-13: Dashboard shows debt breakdown by building — building name and total debt sum (SPEC-DORM-09 AC-24)
- AC-14: Payment metrics are scoped to commandant's assigned buildings, matching the existing data scoping

## UI/UX Notes

- Dashboard page route
- Active year badge at the top
- Metrics cards: Buildings, Rooms, Residents, Total Capacity, Occupancy, Rate (%)
- Building stats table: building name, capacity, occupancy, rate
- Room status distribution as colored badges or a bar chart
- Gender and status distributions as counts
- Overcrowded rooms: warning card with room links
- Overdue accommodations: warning table with resident name, room, planned end date
- Recent events: timeline with actor, action, record, timestamp
- All data is scoped to the user's accessible buildings

## Business Rules

- BR-1: Dashboard access: admin, dormitory administrator, and dormitory commandant only
- BR-2: Building scope: commandant sees only their assigned buildings; admin and dormitory administrator see all non-deleted buildings
- BR-3: Rooms, residents, and accommodations are filtered through the building scope
- BR-4: Current occupancy is the sum of occupancy across the accessible rooms
- BR-5: Room status counts are aggregated by status
- BR-6: Resident gender counts are aggregated by gender
- BR-7: Resident status counts are aggregated by status
- BR-8: Overcrowded rooms are those where the current occupancy is greater than capacity
- BR-9: Overdue accommodations are active accommodations with a planned end date before today, filtered by the accessible rooms
- BR-10: Recent events are audit log entries for dormitory records, filtered by the commandant's accessible buildings, rooms, residents, and accommodations
- BR-11: Events are limited to the 10 most recent
- BR-12: A commandant's event scope includes events related to any record type within their accessible buildings
- BR-13: Total debt = sum(abs(balance)) for all active accommodations within the user's accessible buildings, where balance < 0
- BR-14: Debt by building is grouped by building name, summing negative balances of active accommodations in each building

## Behavior

### Background
Given admin user exists
And building "A" has room 101 (capacity 3, occupancy 2) and room 102 (capacity 2, occupancy 3 — overcrowded)
And resident "Ivan" is settled in room 101 (male)
And resident "Maria" is settled in room 102 (female)
And Ivan's accommodation is overdue (planned end date has passed)

### Rule: Aggregated Metrics

#### Scenario: Admin sees all-building stats
When admin visits the dashboard
Then buildings count = 1
And rooms count = 2
And residents count = 2
And total capacity = 5
And current occupancy = 5 (2 + 3)
And total debt = 0 (all accommodations paid or no payment data)

#### Scenario: Commandant sees only assigned buildings
Given commandant "Dave" is assigned to Building A only
Given building "B" also exists with rooms (not assigned to Dave)
When Dave visits the dashboard
Then the data reflects only Building A
And building "B" is excluded from all metrics

### Rule: Distribution Stats

#### Scenario: Room status distribution
When admin visits the dashboard
Then room status counts show: free = 0, partially occupied = 1, fully occupied = 0, overcrowded = 1

#### Scenario: Gender distribution
When admin visits the dashboard
Then resident gender counts show: male = 1, female = 1

#### Scenario: Status distribution
When admin visits the dashboard
Then resident status counts show: settled = 2

### Rule: Warnings

#### Scenario: Overcrowded rooms
When admin visits the dashboard
Then overcrowded rooms includes room 102 (capacity 2, occupancy 3)

#### Scenario: Overdue accommodations
When admin visits the dashboard
Then overdue accommodations includes Ivan's accommodation (planned end date has passed)

### Rule: Recent Events

#### Scenario: Recent dormitory events shown
Given 5 recent audit log entries for dormitory records
When admin visits the dashboard
Then all 5 events are displayed with actor and action

#### Scenario: Commandant sees only their events
Given 10 events total: 5 from Building A (assigned), 5 from Building B (not assigned)
When commandant Dave visits the dashboard
Then only events related to Building A's rooms, residents, and accommodations are shown

### Rule: Payment Metrics (BR-13, BR-14)

#### Scenario: Total debt metric
Given building A has 3 active accommodations: balance = -3000, -5000, +2000
When admin visits the dashboard
Then total debt metric = 8000 (sum of negative balances as absolute)
And "+2000" is excluded (not a debt)

#### Scenario: Debt by building
Given building A has debts 3000 and 2000; building B has debt 4000
When admin visits the dashboard
Then "Debt by building" table shows: Building A = 5000, Building B = 4000
