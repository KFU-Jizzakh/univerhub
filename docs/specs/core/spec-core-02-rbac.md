# SPEC-CORE-02: Role-Based Access Control

Predefined role system with 10 roles, module-level admin roles, last-admin protection, and authorization across all system features.

Depends on: SPEC-CORE-01

Status: DRAFT

## Acceptance Criteria

- AC-1: System has 10 predefined roles
- AC-2: User can have multiple roles
- AC-3: A user cannot have the same role assigned twice
- AC-4: Role assignments are audited (every grant and revocation is logged)
- AC-5: `admin` is the super-admin with full access across all modules
- AC-6: Module-scoped admin roles (`reporting.admin`, `dormitory.admin`) have full access within their module only
- AC-7: Module-scoped admins see only users and roles from their own module
- AC-8: Cannot deactivate or delete the last active user holding a protected role
- AC-9: Protected roles: `admin`, `dormitory.admin`
- AC-10: Role membership can be checked for any user
- AC-11: System can determine if a user is the last active member of a given role
- AC-12: Every feature action enforces authorization rules
- AC-13: Unauthorized access redirects with an alert and is logged

## UI/UX Notes

- Role assignment appears in the admin user form (checkboxes or multi-select)
- Module-scoped admins see a filtered role list in user forms
- Deactivation and delete buttons are hidden or disabled when the user is the last holder of a protected role

## Business Rules

- BR-1: Role names: `admin`, `reporting.manager`, `reporting.reporter`, `reporting.reviewer`, `reporting.visitor`, `supervisor`, `reporting.admin`, `dormitory.admin`, `dormitory.commandant`
- BR-2: `reporting.admin` manages: `reporting.manager`, `reporting.reporter`, `reporting.reviewer`, `reporting.visitor`, `reporting.admin`
- BR-3: `dormitory.admin` manages: `dormitory.admin`, `dormitory.commandant`
- BR-4: `supervisor` can view the activity feed but has no administrative powers
- BR-5: `admin` bypasses all module scoping and sees everything
- BR-6: Every role grant and revocation is recorded in the audit log

## Behavior

### Background
Given the following roles exist: `admin`, `dormitory.admin`, `dormitory.commandant`, `reporting.admin`, `reporting.manager`, `reporting.reporter`, `reporting.reviewer`, `reporting.visitor`, `supervisor`

### Rule: Role Assignment

#### Scenario: Assign role to user
Given user "Alice" has no roles
When admin assigns role `dormitory.commandant` to Alice
Then Alice gains the role
And the assignment is recorded in the audit log

#### Scenario: Duplicate role assignment
Given user "Alice" already has role `dormitory.commandant`
When admin tries to assign `dormitory.commandant` again
Then the operation is rejected with a validation error

#### Scenario: Remove role from user
Given user "Alice" has role `dormitory.commandant`
When admin removes the role
Then Alice loses the role
And the removal is recorded in the audit log

### Rule: Last Admin Protection

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

### Rule: Module-Scoped Admin Access

#### Scenario: Reporting admin sees only reporting roles
Given user has role `reporting.admin` (not full `admin`)
When user visits the new-user form
Then role selector shows only: `reporting.manager`, `reporting.reporter`, `reporting.reviewer`, `reporting.visitor`, `reporting.admin`

#### Scenario: Dormitory admin sees only dormitory users
Given user has role `dormitory.admin` (not full `admin`)
When user visits user list
Then only users with dormitory-scoped roles are shown

### Rule: Authorization Enforcement

#### Scenario: Unauthorized access attempt
Given user has only role `reporting.reporter`
When user tries to access dormitory buildings list
Then user is redirected back with "not authorized" alert
And the attempt is logged
