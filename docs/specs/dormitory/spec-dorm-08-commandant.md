# SPEC-DORM-08: Commandant Management

Building-to-commandant assignment system that controls access scope. Commandants are users with `dormitory.commandant` role who are assigned specific buildings they can manage.

Depends on: SPEC-CORE-02, SPEC-CORE-03, SPEC-DORM-02

Status: IMPLEMENTED

## Acceptance Criteria

- AC-1: Admin can assign buildings to users with `dormitory.commandant` role
- AC-2: Building assignment is done via admin user form (create/edit)
- AC-3: Active assignments have `deactivated_at = nil`
- AC-4: Deactivated assignments set `deactivated_at` (soft-deactivate, not delete)
- AC-5: Each user+building combination is unique among active assignments
- AC-6: Reassigning buildings activates new ones and deactivates removed ones
- AC-7: Commandant sees only their assigned buildings across all dormitory pages
- AC-8: Pundit scopes in all dormitory policies respect commandant's building assignments
- AC-9: Building assignment changes are tracked via OutboxEvent
- AC-10: Commandant buildings scope: `user.assigned_buildings` returns active assigned buildings

## UI/UX Notes

- Admin user form: building multi-select appears when `dormitory.commandant` role is checked
- Building selection: dropdown with building names (only kept buildings)
- User show: assigned buildings list with activation status
- No management interface in dormitory section — managed solely through admin

## Business Rules

- BR-1: `CommandantBuilding` model tracks user+building+deactivated_at
- BR-2: `scope :active` = `where(deactivated_at: nil)`, `scope :deactivated` = `where.not(deactivated_at: nil)`
- BR-3: Uniqueness validation: `building_id` unique per user among active records
- BR-4: `user.assigned_buildings` — through association with active scope
- BR-5: `do_deactivate!` sets `deactivated_at = Time.current`
- BR-6: `do_create!` and `do_deactivate!` are tracked via Trackable
- BR-7: Assignment changes in admin: compare old_ids vs new_ids, deactivate removed, create new
- BR-8: Policy scope for buildings: admin → all kept → commandant → filtered by `user.assigned_building_ids`
- BR-9: Policy scope for rooms: admin → all kept → commandant → `where(building_id: user.assigned_building_ids)`
- BR-10: Policy scope for residents: admin → all → commandant → with NULL current_room OR room in assigned buildings
- BR-11: Policy scope for accommodations: admin → all → commandant → joins room where building_id in assigned
- BR-12: Policy scope for batch operations: admin → all → commandant → joins building where id in assigned

## Behavior

### Background
Given admin user exists
And user "Dave" exists with role `dormitory.commandant`
And building "Building A" (id:1) and "Building B" (id:2) exist

### Rule: Assignment (BR-1 through BR-6)

#### Scenario: Assign buildings to commandant
When admin assigns buildings 1 and 2 to Dave
Then 2 `CommandantBuilding` records are created
And both have `deactivated_at = nil`
And OutboxEvent `dormitory.commandant_building.created` is logged twice
And `Dave.assigned_buildings` returns [Building A, Building B]

#### Scenario: Reassign buildings
Given Dave has active assignments to Building A and B
When admin updates Dave to have only Building B
Then Building A assignment is deactivated (deactivated_at set)
And Building B assignment remains active
And OutboxEvent `dormitory.commandant_building.deactivated` is logged
And `Dave.assigned_buildings` returns [Building B]

#### Scenario: Duplicate active assignment blocked
Given Dave has active assignment to Building A
When admin tries to add Building A again
Then validation error `already_assigned` is raised

#### Scenario: Deactivated assignment allows re-activation
Given Dave's assignment to Building A was deactivated (exists with deactivated_at)
When admin assigns Building A again
Then a new active record is created (old one remains deactivated)
And uniqueness constraint is not violated (only among active)

### Rule: Scoped Access (BR-8 through BR-12)

#### Scenario: Commandant sees only assigned buildings in index
Given Dave is assigned to Building A only
When Dave visits buildings index
Then only Building A is displayed

#### Scenario: Commandant sees only assigned rooms
Given Building A has rooms 101 and 102
And Building B has room 201 (not assigned to Dave)
When Dave visits rooms index
Then only rooms 101 and 102 are displayed

#### Scenario: Commandant sees residents from assigned rooms
Given Ivan is settled in room 101 (Building A)
And Maria is settled in room 201 (Building B)
When Dave visits residents index
Then Ivan is displayed (in assigned building)
And Maria is not displayed (not in assigned building)
But not_settled residents without current_room ARE displayed (NULL room → accessible)

#### Scenario: Commandant sees only assigned buildings' accommodations
Given accommodations exist for Building A and Building B
When Dave visits accommodations index
Then only Building A accommodations are displayed

#### Scenario: Commandant dashboard scoped
When Dave visits dormitory dashboard
Then all stats reflect only Building A data
And recent events are filtered to Building A
