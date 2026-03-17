# SPEC-CORE-02: Role-Based Access Control

Predefined role system with 10 roles, scoped admin roles (module-level admins), last-admin protection, and Pundit-based authorization across all controllers.

Depends on: SPEC-CORE-01

Status: DRAFT

## Acceptance Criteria

- AC-1: System has 10 predefined roles in `Role::NAMES`
- AC-2: User can have multiple roles via `UserRole` join table
- AC-3: `UserRole` is unique per user+role combination
- AC-4: Roles support CRUD with audit trail (Trackable concern)
- AC-5: `admin` is the super-admin with full access across all modules
- AC-6: Scoped admin roles (`reporting.admin`, `dormitory.admin`) have full access within their module only
- AC-7: Admin user management respects module scope (scoped admin sees only their module's roles/users)
- AC-8: Cannot deactivate/delete the last active user with a protected role
- AC-9: Protected roles: `admin`, `dormitory.admin`
- AC-10: `User.has_role?(name)` checks role membership
- AC-11: `User.last_active_with_role?(user, name)` checks if user is last active with given role
- AC-12: Every controller action uses `authorize` (Pundit) for access control
- AC-13: Policy violations result in redirect with flash alert, logged to Rails.logger

## UI/UX Notes

- Role assignment happens in admin/users form (checkboxes or multi-select)
- Scoped admin sees filtered role list in user forms
- Deactivation/delete buttons are hidden or disabled when it's the last protected-role user

## Business Rules

- BR-1: Role names: `admin`, `reporting.manager`, `reporting.reporter`, `reporting.reviewer`, `reporting.visitor`, `supervisor`, `reporting.admin`, `dormitory.admin`, `dormitory.commandant`
- BR-2: Module role hierarchy for `reporting.admin`: manages `reporting.manager`, `reporting.reporter`, `reporting.reviewer`, `reporting.visitor`, `reporting.admin`
- BR-3: Module role hierarchy for `dormitory.admin`: manages `dormitory.admin`, `dormitory.commandant`
- BR-4: `supervisor` role gets activity feed access but no admin powers
- BR-5: `admin` user bypasses all module scoping
- BR-6: `UserRole.do_create!`, `.do_update!`, `.do_destroy!` all track events

## Behavior

### Background
Given role `admin` exists
And role `dormitory.admin` exists
And role `dormitory.commandant` exists
And role `reporting.admin` exists
And role `reporting.manager` exists
And role `reporting.reporter` exists
And role `reporting.reviewer` exists
And role `reporting.visitor` exists
And role `supervisor` exists

### Rule: Role Assignment (BR-1, BR-6)

#### Scenario: Assign role to user
Given user "Alice" has no roles
When admin assigns role `dormitory.commandant` to Alice
Then a `UserRole` record is created
And an `OutboxEvent` with action `user_role.created` is logged

#### Scenario: Duplicate role assignment
Given user "Alice" already has role `dormitory.commandant`
When admin tries to assign `dormitory.commandant` again
Then validation error is raised (role_id uniqueness per user_id)

#### Scenario: Remove role from user
Given user "Alice" has role `dormitory.commandant`
When admin removes the role
Then the `UserRole` record is destroyed
And an `OutboxEvent` with action `user_role.destroyed` is logged

### Rule: Last Admin Protection (BR-5)

#### Scenario: Cannot deactivate last active admin
Given user "Bob" is the only active user with role `admin`
When admin tries to deactivate Bob
Then operation is blocked with alert "cannot deactivate last admin"
And Bob remains active

#### Scenario: Can deactivate admin if another exists
Given users "Bob" and "Carol" both have role `admin` and are active
When admin deactivates Bob
Then Bob is deactivated successfully

#### Scenario: Cannot delete last active dormitory.admin
Given user "Dave" is the only active user with role `dormitory.admin`
When admin tries to delete Dave
Then operation is blocked with alert "cannot delete last admin"

### Rule: Scoped Admin (BR-2, BR-3)

#### Scenario: Reporting admin sees only reporting roles
Given user has role `reporting.admin` (not full `admin`)
When user visits admin/users/new
Then role selector shows only: `reporting.manager`, `reporting.reporter`, `reporting.reviewer`, `reporting.visitor`, `reporting.admin`

#### Scenario: Dormitory admin sees only dormitory roles
Given user has role `dormitory.admin` (not full `admin`)
When user visits admin/users
Then only users with dormitory-scoped roles are shown

### Rule: Authorization (BR-5)

#### Scenario: Unauthorized access triggers Pundit error
Given user has only role `reporting.reporter`
When user tries to access dormitory buildings index
Then `Pundit::NotAuthorizedError` is raised
And user is redirected back with "not authorized" alert
And the event is logged to Rails.logger
