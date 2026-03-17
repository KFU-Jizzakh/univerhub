# SPEC-CORE-04: Notifications & Activity Feed

In-app notifications with read/unread state, linked to the items that triggered them, and an activity feed showing system-wide audit events with role-based filtering.

Depends on: SPEC-CORE-01, SPEC-CORE-02

Status: DRAFT

## Acceptance Criteria

- AC-1: User can view list of their notifications (most recent first)
- AC-2: Notification shows description, timestamp, and link to the related item
- AC-3: User can mark a single notification as read
- AC-4: User can mark all notifications as read at once
- AC-5: Unread notification count is visible to the user
- AC-6: Activity feed shows recent audit events with the actor who performed them
- AC-7: Activity feed displays actor name and action description
- AC-8: Activity feed is accessible to `supervisor`, `admin`, `reporting.admin`, `dormitory.admin`
- AC-9: Module-scoped admins see only events from their module
- AC-10: System actions automatically create audit entries when tracked data changes
- AC-11: Audit entries record: who performed the action (actor), what happened (action), which item was affected, and optional context data

## UI/UX Notes

- Notifications page: list with unread indicator
- Each notification updates live when marked as read (with non-JavaScript fallback)
- Unread count shown in navigation bar
- Activity feed: table with actor, action, affected item type, timestamp
- Module-scoped admin feed filters to show only relevant events

## Business Rules

- BR-1: Each notification belongs to one recipient (always the current user)
- BR-2: Each notification links to the item that triggered it (e.g., a report, a resident)
- BR-3: Every notification has a required action description
- BR-4: Read status is determined by whether the notification has been viewed
- BR-5: Marking as read records the current time
- BR-6: "Mark all as read" updates all unread notifications for the current user at once
- BR-7: Audit events may have no actor (for system-triggered events)
- BR-8: Audit entries are created alongside the business operation they track, with optional context data provided after the operation succeeds
- BR-9: Module-scoped admins see only events relevant to their module
- BR-10: Activity feed requires authentication

## Behavior

### Background
Given user "Alice" exists
And Alice has 3 unread notifications

### Rule: Notification Display

#### Scenario: View notifications
When Alice visits notifications page
Then all 3 notifications are displayed
And unread notifications have distinct styling

#### Scenario: Mark single notification as read
Given notification #1 is unread
When Alice marks notification #1 as read
Then the notification updates to its read-state appearance
And page reflects the change without full reload (or redirects on fallback)

#### Scenario: Mark all as read
Given Alice has 3 unread notifications
When Alice clicks "Mark all as read"
Then all 3 notifications are marked as read
And Alice sees a success confirmation

### Rule: Activity Feed

#### Scenario: View activity feed as supervisor
Given user "Bob" has role `supervisor`
When Bob visits activity feed
Then recent 10 audit entries are displayed with actor names

#### Scenario: Full admin sees all events
Given user "Carol" has role `admin`
When Carol visits activity feed
Then events from all modules (reporting and dormitory) are shown

#### Scenario: Reporting admin sees only reporting events
Given user "Dave" has role `reporting.admin` (not full admin)
When Dave visits activity feed
Then only events related to reporting are shown
And dormitory events are excluded

#### Scenario: Dormitory admin sees only dormitory events
Given user "Eve" has role `dormitory.admin` (not full admin)
When Eve visits activity feed
Then only events related to dormitory are shown
And reporting events are excluded

#### Scenario: Unauthorized user cannot access
Given user "Frank" has only role `reporting.reporter`
When Frank visits activity feed
Then access is denied with authorization error

### Rule: Automatic Audit Logging

#### Scenario: Audit entry created on tracked action success
Given the current user is "Alice"
When a resident is created through the system
Then an audit entry is created with:
  - Actor: Alice
  - Action: resident creation
  - Affected item: the resident
  - No additional context

#### Scenario: Audit entry with explicit context
Given the current user is "Alice"
When an accommodation settlement is processed
Then an audit entry is created with:
  - Action: accommodation settlement
  - Context: resident identity, room details, and settlement parameters

#### Scenario: Audit entry with context computed after operation
Given context data is provided as a computation
When the tracked operation completes successfully
Then the computation runs after success
And its result becomes the audit entry's context

#### Scenario: Failed operation creates no audit entry
Given a validation error occurs during the tracked operation
Then no audit entry is created
And the error is propagated to the caller
