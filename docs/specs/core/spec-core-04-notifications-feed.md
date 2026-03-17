# SPEC-CORE-04: Notifications & Activity Feed

In-app notifications with read/unread state, a polymorphic association to notifiable records, and an activity feed powered by the OutboxEvent audit log with Trackable concern and scoped admin filtering.

Depends on: SPEC-CORE-01, SPEC-CORE-02

Status: DRAFT

## Acceptance Criteria

- AC-1: User can view list of notifications (paginated, most recent first)
- AC-2: Notification shows action description, timestamp, and link to notifiable record
- AC-3: User can mark a single notification as read (Turbo Stream + HTML fallback)
- AC-4: User can mark all notifications as read at once
- AC-5: Unread notification count is available to views
- AC-6: Activity feed page shows recent OutboxEvents (paginated, with actor)
- AC-7: Activity feed displays actor name and event action
- AC-8: Activity feed is accessible to `supervisor`, `admin`, `reporting.admin`, `dormitory.admin`
- AC-9: Scoped admin sees only events from their module (reporting.admin → reporting events only)
- AC-10: Trackable concern auto-creates OutboxEvent on model state changes
- AC-11: OutboxEvent stores actor (nullable), action, record (polymorphic), and payload (JSON)

## UI/UX Notes

- Notifications page: list with unread badge indicator
- Each notification is a Turbo Frame for live update on mark-as-read
- Unread count shown in navigation bar
- Activity feed: table with actor, action, record type, timestamp
- Scoped admin feed filters events by action prefix

## Business Rules

- BR-1: `Notification.belongs_to :recipient` (User) — recipient is always the current user's notifications
- BR-2: `Notification.belongs_to :notifiable` (polymorphic) — links to the record that triggered it
- BR-3: `Notification.action` is required and describes the event
- BR-4: `read_at` presence determines read/unread state
- BR-5: `mark_as_read!` sets `read_at` to current time
- BR-6: `mark_all_as_read` bulk-updates all unread notifications for the current user
- BR-7: `OutboxEvent.actor` can be nil (for system events or when no user in context)
- BR-8: `Trackable.track_event` wraps operations in a transaction, creates OutboxEvent, supports lazy payload via callable
- BR-9: Scoped admin filtering: events filtered by record_type or action prefix depending on module
- BR-10: Activity feed requires authentication (like all pages)

## Behavior

### Background
Given user "Alice" exists
And Alice has 3 unread notifications

### Rule: Notification Display (BR-1, BR-2, BR-3)

#### Scenario: View notifications
When Alice visits notifications page
Then all 3 notifications are displayed (paginated)
And unread notifications have distinct styling

#### Scenario: Mark single notification as read
Given notification #1 is unread
When Alice clicks "Mark as read" on notification #1
Then Turbo Stream replaces the notification with read-state version
Or (HTML fallback) redirects to notifications page with updated state

#### Scenario: Mark all as read
Given Alice has 3 unread notifications
When Alice clicks "Mark all as read"
Then all 3 notifications have `read_at` set
And Alice is redirected to notifications page with success notice

### Rule: Activity Feed (BR-7, BR-8, BR-9)

#### Scenario: View activity feed as supervisor
Given user "Bob" has role `supervisor`
When Bob visits activity feed
Then recent 10 OutboxEvents are displayed with actor names

#### Scenario: Full admin sees all events
Given user "Carol" has role `admin`
When Carol visits activity feed
Then events from all modules (reporting and dormitory) are shown

#### Scenario: Reporting admin sees only reporting events
Given user "Dave" has role `reporting.admin` (not full admin)
When Dave visits activity feed
Then only events with action starting with "reporting." or record_type from reporting models are shown
And dormitory events are excluded

#### Scenario: Dormitory admin sees only dormitory events
Given user "Eve" has role `dormitory.admin` (not full admin)
When Eve visits activity feed
Then only events with record_type in dormitory models are shown
And reporting events are excluded

#### Scenario: Unauthorized user cannot access
Given user "Frank" has only role `reporting.reporter`
When Frank visits activity feed
Then `Pundit::NotAuthorizedError` is raised

### Rule: Trackable Concern (BR-8)

#### Scenario: Trackable creates OutboxEvent on success
Given Current.user is "Alice"
When `resident.do_create!` is called
Then an OutboxEvent is created with:
  - actor: Alice
  - action: "dormitory.resident.created"
  - record: the resident
  - payload: {} (default)

#### Scenario: Trackable with explicit payload
Given Current.user is "Alice"
When `accommodation.do_settle!(force: false)` is called
Then an OutboxEvent is created with:
  - action: "dormitory.accommodation.created"
  - payload: { resident_id: ..., room_id: ..., room_number: ..., force: false }

#### Scenario: Trackable with lazy payload
Given a callable is passed as payload
When the track_event block executes
Then the callable is called lazily after the block succeeds
And the returned value is used as payload

#### Scenario: Trackable on failure doesn't create event
Given a validation error occurs in the block
When `model.do_create!` is called
Then no OutboxEvent is created
And the error propagates
