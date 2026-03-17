# SPEC-CORE-03: User Management (Admin)

Admin interface for managing users: creating, editing, activating/deactivating, deleting, assigning roles, managing profiles, and assigning buildings to commandants.

Depends on: SPEC-CORE-01, SPEC-CORE-02

Status: DRAFT

## Acceptance Criteria

- AC-1: Admin can list all users (with roles and profile information)
- AC-2: Admin can create new user with email, password, roles, and optional profile
- AC-3: Admin can edit user: email, password (optional), roles, profile (first name, middle name, last name, avatar)
- AC-4: Admin can view user details including roles and profile
- AC-5: Admin can activate a deactivated user
- AC-6: Admin can deactivate an active user (with protections)
- AC-7: Admin can delete a user
- AC-8: Admin can reset a user's password (generates temporary password, destroys all sessions)
- AC-9: Admin cannot deactivate or delete themselves
- AC-10: Module-scoped admin sees only users within their module
- AC-11: When assigning the `dormitory.commandant` role, building assignment controls are shown
- AC-12: Building assignments are deactivated (not permanently removed) when changed
- AC-13: Profile is created alongside user if profile fields are provided
- AC-14: Avatar upload accepts JPEG, PNG, WebP formats only, up to 5 MB
- AC-15: Invalid role or building selections trigger validation errors

## UI/UX Notes

- User list: table with email, full name, roles displayed as badges, status (active/deactivated badge)
- User form: email, password/confirmation (leave password blank to keep unchanged on edit), role checkboxes, profile fields
- Commandant user form: additional building multi-select control
- Show page: user info card, roles, assigned buildings, activity history
- Confirmation messages for all actions: created, updated, activated, deactivated, deleted, password reset
- Temporary password is displayed in the confirmation message after reset

## Business Rules

- BR-1: Email must be unique and in valid format
- BR-2: Password required on creation, optional on edit (blank means no change)
- BR-3: Full name is composed from last name, first name, and middle name
- BR-4: Avatar can be removed via a dedicated control
- BR-5: Self-demotion protection: admin cannot remove their own `admin` role
- BR-6: Self-action protection: cannot activate, deactivate, or delete own account
- BR-7: Module-scoped admin cannot manage users outside their module
- BR-8: Building assignments must reference existing buildings
- BR-9: A commandant cannot have duplicate active assignments to the same building
- BR-10: Building assignments are soft-deactivated (not permanently deleted) when reassigned or removed

## Behavior

### Background
Given admin user "Admin" with role `admin`
And a regular user "Alice" exists with email `alice@example.com`

### Rule: Create User

#### Scenario: Create user with email and password
When admin creates user with email `bob@example.com` and password `Secret123`
Then user is created with normalized email
And admin is redirected to user details with "created" message

#### Scenario: Create user with profile
When admin creates user with email `carol@example.com`, password `Secret123`, first name "Carol", last name "Smith"
Then user is created
And a profile is created with first name "Carol" and last name "Smith"
And the creation is recorded in the audit log

#### Scenario: Create user with duplicate email
When admin creates user with email `alice@example.com` (already taken)
Then form re-displays with validation error

### Rule: Edit User

#### Scenario: Update user email
When admin updates Alice's email to `alice2@example.com`
Then Alice's email is updated
And admin is redirected to user details with "updated" message

#### Scenario: Leave password blank (no change)
When admin submits edit form with empty password fields
Then Alice's password remains unchanged
And admin is redirected to user details with "updated" message

#### Scenario: Upload avatar
When admin uploads a valid JPEG avatar for Alice
Then avatar is attached to the profile

#### Scenario: Upload invalid avatar format
When admin uploads a PDF file as avatar
Then form re-displays with validation error about invalid avatar format

#### Scenario: Remove avatar
When admin uses the remove-avatar control and submits
Then avatar is removed

### Rule: Activate/Deactivate

#### Scenario: Deactivate user
Given Alice is active
When admin deactivates Alice
Then Alice is deactivated
And admin is redirected to user details with "deactivated" message

#### Scenario: Reactivate user
Given Alice is deactivated
When admin activates Alice
Then Alice is activated
And admin is redirected to user details with "activated" message

#### Scenario: Cannot deactivate self
When admin tries to deactivate themselves
Then admin is redirected with "cannot deactivate self" alert

### Rule: Delete User

#### Scenario: Delete user
Given Alice is not the last admin
When admin deletes Alice
Then Alice is deleted
And all Alice's sessions are destroyed
And admin is redirected to user list with "deleted" message

#### Scenario: Cannot delete self
When admin tries to delete themselves
Then admin is redirected with "cannot delete self" alert

### Rule: Reset Password

#### Scenario: Reset user password
When admin resets Alice's password
Then a temporary random password is generated
And Alice's password is updated
And all Alice's sessions are destroyed
And admin is redirected to user details with the temporary password in the message

### Rule: Commandant Building Assignment

#### Scenario: Assign buildings to commandant
Given admin creates user "Dave" with role `dormitory.commandant`
And buildings "Building A" and "Building B" exist
When admin selects Building A and Building B
Then Dave is assigned to both buildings
And the assignments are recorded in the audit log

#### Scenario: Reassign buildings
Given Dave has an active assignment to Building A
When admin updates Dave to be assigned to Building B and Building C only
Then Building A assignment is deactivated
And new active assignments for Building B and Building C are created

#### Scenario: Removing commandant role hides building controls
When admin removes `dormitory.commandant` role from Dave
Then building assignment controls are no longer shown
And existing assignments are not automatically affected
