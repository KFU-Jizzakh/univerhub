# SPEC-CORE-03: User Management (Admin)

Admin interface for CRUD operations on users, including role assignment, profile management, building assignment for commandants, activation/deactivation, and password reset.

Depends on: SPEC-CORE-01, SPEC-CORE-02

Status: DRAFT

## Acceptance Criteria

- AC-1: Admin can list all users (paginated, with roles and profile)
- AC-2: Admin can create new user with email, password, roles, and optional profile
- AC-3: Admin can edit user: email, password (optional), roles, profile (first_name, middle_name, last_name, avatar)
- AC-4: Admin can view user details including roles and profile
- AC-5: Admin can activate a deactivated user
- AC-6: Admin can deactivate an active user (with protections)
- AC-7: Admin can discard (soft-delete) a user
- AC-8: Admin can reset a user's password (generates temporary password, destroys all sessions)
- AC-9: Admin cannot deactivate/delete themselves
- AC-10: Scoped admin (reporting.admin, dormitory.admin) sees only users within their module
- AC-11: When assigning `dormitory.commandant` role, building assignment UI is shown
- AC-12: Building assignments are activated/deactivated (not deleted) when changed
- AC-13: Profile is created on user creation if profile fields are provided
- AC-14: Avatar upload validates format (JPEG/PNG/WebP) and size (max 5 MB)
- AC-15: Invalid role IDs or building IDs trigger validation errors

## UI/UX Notes

- User list: table with email, full name, roles (badges), status (active/deactivated badge)
- User form: email, password/confirmation (password blank = no change on edit), role checkboxes, profile fields
- Commandant user form: additional building multi-select
- Show page: user info card, roles, assigned buildings, activity history
- Flash notices for all actions: created, updated, activated, deactivated, deleted, password reset
- Temporary password is displayed in flash notice after reset

## Business Rules

- BR-1: `email_address` must be unique and valid email format
- BR-2: Password required on create, optional on update (blank = unchanged)
- BR-3: Profile `full_name` is delegated from User (last_name + first_name + middle_name)
- BR-4: Avatar can be marked for removal via `remove_avatar` virtual attribute
- BR-5: Self-demotion protection: admin cannot remove their own `admin` role
- BR-6: Self-action protection: cannot activate/deactivate/destroy self
- BR-7: Scoped admin cannot manage users outside their module scope
- BR-8: Building validation: submitted building_ids must exist among kept buildings
- BR-9: `CommandantBuilding` has unique constraint per user+building among active records
- BR-10: Deactivated commandant buildings are soft-deactivated (`deactivated_at`), not destroyed

## Behavior

### Background
Given admin user "Admin" with role `admin`
And a regular user "Alice" exists with email `alice@example.com`

### Rule: Create User (BR-1, BR-2, BR-3)

#### Scenario: Create user with email and password
When admin creates user with email `bob@example.com` and password `Secret123`
Then user is created with `email_address` normalized
And admin is redirected to user show with "created" notice

#### Scenario: Create user with profile
When admin creates user with email `carol@example.com`, password `Secret123`, first_name "Carol", last_name "Smith"
Then user is created
And a UserProfile is created with first_name="Carol", last_name="Smith"
And OutboxEvent `user_profile.created` is logged

#### Scenario: Create user with duplicate email
When admin creates user with email `alice@example.com` (taken)
Then form re-renders with validation error

### Rule: Edit User (BR-4, BR-5)

#### Scenario: Update user email
When admin updates Alice's email to `alice2@example.com`
Then Alice's email is updated
And redirect to show with "updated" notice

#### Scenario: Update password (blank = no change)
When admin submits edit form with empty password fields
Then Alice's password remains unchanged
And redirect to show with "updated" notice

#### Scenario: Upload avatar
When admin uploads a valid JPEG avatar for Alice
Then avatar is attached via Active Storage

#### Scenario: Upload invalid avatar
When admin uploads a file of type `application/pdf`
Then form re-renders with validation error about avatar format

#### Scenario: Remove avatar
When admin checks "remove avatar" and submits
Then avatar is purged

### Rule: Activate/Deactivate (BR-6)

#### Scenario: Deactivate user
Given Alice is active
When admin deactivates Alice
Then `deactivated_at` is set
And redirect to show with "deactivated" notice

#### Scenario: Reactivate user
Given Alice is deactivated
When admin activates Alice
Then `deactivated_at` is set to nil
And redirect to show with "activated" notice

#### Scenario: Cannot deactivate self
When admin tries to deactivate themselves
Then redirect to show with "cannot deactivate self" alert

### Rule: Delete User (BR-1)

#### Scenario: Discard user
Given Alice is not the last admin
When admin deletes Alice
Then Alice is discarded (`discarded_at` set)
And all sessions are destroyed
And redirect to index with "deleted" notice

#### Scenario: Cannot delete self
When admin tries to delete themselves
Then redirect to index with "cannot delete self" alert

### Rule: Reset Password (BR-2)

#### Scenario: Reset user password
When admin resets Alice's password
Then a temporary random password is generated
And Alice's password is updated
And all Alice's sessions are destroyed
And redirect to show with temporary password in notice

### Rule: Commandant Building Assignment (BR-8, BR-9, BR-10)

#### Scenario: Assign buildings to commandant
Given admin creates user "Dave" with role `dormitory.commandant`
And buildings "Building A" (id:1) and "Building B" (id:2) exist
When admin selects buildings 1 and 2
Then 2 `CommandantBuilding` records are created (active)
And OutboxEvent `dormitory.commandant_building.created` is logged twice

#### Scenario: Reassign buildings
Given Dave has active commandant assignment to Building A (id:1)
When admin updates Dave to have buildings 2 and 3 only
Then Building A assignment is deactivated (deactivated_at set)
And new active assignments for buildings 2 and 3 are created

#### Scenario: Remove commandant role removes building assignments
When admin removes `dormitory.commandant` role from Dave
Then no building assignment UI is shown
And existing assignments are not automatically deactivated (handled separately)
