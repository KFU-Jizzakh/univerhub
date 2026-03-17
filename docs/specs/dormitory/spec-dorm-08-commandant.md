# SPEC-DORM-08: Commandant Management

Building-to-commandant assignment system that controls access scope. Commandants are users with the "dormitory commandant" role who are assigned specific buildings they can manage.

Depends on: SPEC-CORE-02, SPEC-CORE-03, SPEC-DORM-02

Status: IMPLEMENTED

## Acceptance Criteria

- AC-1: Admin can assign buildings to users with the "dormitory commandant" role
- AC-2: Building assignment is done via the admin user form (create and edit)
- AC-3: Active assignments are those that have not been deactivated
- AC-4: Deactivated assignments are soft-deactivated (not deleted), recording when they were deactivated
- AC-5: Each user and building combination is unique among active assignments
- AC-6: Reassigning buildings activates newly selected ones and deactivates removed ones
- AC-7: A commandant sees only their assigned buildings across all dormitory pages
- AC-8: Role-based access in all dormitory features respects the commandant's building assignments
- AC-9: Building assignment changes are recorded in the audit log
- AC-10: A commandant's assigned buildings are their active (non-deactivated) building assignments

## UI/UX Notes

- Admin user form: building multi-select appears when the "dormitory commandant" role is selected
- Building selection: dropdown with building names (only non-deleted buildings)
- User show: list of assigned buildings with activation status
- No management interface in the dormitory section — assignments are managed solely through the admin area

## Business Rules

- BR-1: Each building assignment tracks which user is assigned, which building, and whether the assignment is active or deactivated
- BR-2: Active assignments are those not deactivated; deactivated assignments have a deactivation timestamp
- BR-3: A building can be assigned to a user only once among active records
- BR-4: A commandant's assigned buildings are their active assignments
- BR-5: Deactivation records the current time as the deactivation timestamp
- BR-6: Both creation and deactivation of assignments are recorded in the audit log
- BR-7: When building assignments are changed, the system compares old and new selections, deactivates removed ones, and creates new ones for additions
- BR-8: Building access: admin sees all non-deleted buildings; commandant sees only their assigned buildings
- BR-9: Room access: admin sees all non-deleted rooms; commandant sees only rooms in their assigned buildings
- BR-10: Resident access: admin sees all; commandant sees residents with no current room OR residents in rooms within their assigned buildings
- BR-11: Accommodation access: admin sees all; commandant sees accommodations whose room is in an assigned building
- BR-12: Batch operation access: admin sees all; commandant sees operations linked to their assigned buildings

## Behavior

### Background
Given admin user exists
And user "Dave" exists with role "dormitory commandant"
And building "Building A" and "Building B" exist

### Rule: Assignment (BR-1 through BR-6)

#### Scenario: Assign buildings to commandant
When admin assigns Building A and Building B to Dave
Then two building assignments are created
And both assignments are active
And the creation is recorded in the audit log (once per assignment)
And Dave's assigned buildings are [Building A, Building B]

#### Scenario: Reassign buildings
Given Dave has active assignments to Building A and Building B
When admin updates Dave to have only Building B
Then the Building A assignment is deactivated
And the Building B assignment remains active
And the deactivation is recorded in the audit log
And Dave's assigned buildings are [Building B]

#### Scenario: Duplicate active assignment blocked
Given Dave has an active assignment to Building A
When admin tries to add Building A again
Then a validation error is raised (already assigned)

#### Scenario: Deactivated assignment allows re-activation
Given Dave's assignment to Building A was previously deactivated (exists with a deactivation timestamp)
When admin assigns Building A again
Then a new active assignment is created (the old one remains deactivated)
And the uniqueness constraint is not violated (it applies only among active assignments)

### Rule: Scoped Access (BR-8 through BR-12)

#### Scenario: Commandant sees only assigned buildings in index
Given Dave is assigned to Building A only
When Dave visits the buildings index
Then only Building A is displayed

#### Scenario: Commandant sees only assigned rooms
Given Building A has rooms 101 and 102
And Building B has room 201 (not assigned to Dave)
When Dave visits the rooms index
Then only rooms 101 and 102 are displayed

#### Scenario: Commandant sees residents from assigned rooms
Given Ivan is settled in room 101 (Building A)
And Maria is settled in room 201 (Building B)
When Dave visits the residents index
Then Ivan is displayed (in an assigned building)
And Maria is not displayed (not in an assigned building)
But not-settled residents without a current room are displayed (no room restriction applies)

#### Scenario: Commandant sees only assigned buildings' accommodations
Given accommodations exist for Building A and Building B
When Dave visits the accommodations index
Then only Building A accommodations are displayed

#### Scenario: Commandant dashboard scoped
When Dave visits the dormitory dashboard
Then all stats reflect only Building A data
And recent events are filtered to Building A
