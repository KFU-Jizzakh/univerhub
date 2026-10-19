# Use Cases (Cockburn)

Fully dressed use cases in Alistair Cockburn's format. Goal level is *user* (sea level)
unless stated otherwise. Source of truth: controllers in `app/controllers`, models in
`app/models`, policies in `app/policies`.

## Core

### UC-C1: Sign In

- **Primary actor:** User (unauthenticated)
- **Stakeholders:** User — access to workspace; System — audit trail of sign-ins
- **Preconditions:** An active (not deactivated, not deleted) account exists
- **Main success scenario:**
  1. User opens the sign-in page and submits email and password
  2. System validates credentials (email is normalized: downcased, trimmed)
  3. System creates a persistent session (recorded with IP and user agent)
  4. System redirects to the stored return URL or the home page
- **Extensions:**
  - *1a. Rate limit exceeded (10 failed attempts within 3 minutes)* — redirected back with a rate-limit alert, no session
  - *2a. Wrong credentials* — generic alert (no user enumeration), no session
  - *2b. Account deactivated* — "account deactivated" alert, no session
  - *2c. Account deleted* — "account deleted" alert, no session
  - *4a. Return URL points outside the application* — redirect to the default page instead

### UC-C2: Reset Password

- **Primary actor:** User (unauthenticated)
- **Preconditions:** Account exists
- **Main success scenario:**
  1. User requests a password reset by email
  2. System enqueues the reset email in the background
  3. User follows the token link and submits a new password (min 8 characters) with confirmation
  4. System updates the password and destroys all existing sessions
  5. User signs in with the new password
- **Extensions:**
  - *1a. Unknown email* — same "instructions sent" notice (no enumeration), no email
  - *3a. Token invalid or expired* — attempt is logged with network info, alert shown
  - *3b. Password shorter than 8 characters* — validation error

### UC-C3: Administer Users

- **Primary actor:** `admin`; `reporting.admin` / `dormitory.admin` within their module
- **Stakeholders:** Admin — control over accounts; Users — access to the system
- **Preconditions:** Actor is signed in
- **Main success scenario:**
  1. Admin creates a user with email, password, roles, and profile (name, avatar)
  2. System records an audit event
  3. Admin edits the account later: changes roles, assigns commandant buildings, deactivates/reactivates, or resets the password (temporary password shown once, all sessions destroyed)
  4. System records audit events for every change
- **Extensions:**
  - *1a. Duplicate role* — rejected
  - *1b. Building selected for a non-commandant user* — buildings fieldset hidden/ignored
  - *3a. Deactivating self* — denied
  - *3b. Deleting the last active `dormitory.admin`* — denied
  - *3c. Deactivated user makes a request* — session terminated with an alert

### UC-C4: View Notifications

- **Primary actor:** Any user
- **Main success scenario:**
  1. User opens the notifications page (navbar shows the unread count)
  2. System lists their notifications, newest first
  3. User marks one or all as read
- **Extensions:** none significant

### UC-C5: View Activity Feed

- **Primary actor:** `admin`, `supervisor`, `reporting.admin`, `dormitory.admin`
- **Main success scenario:**
  1. Actor opens the activity feed
  2. System shows recent audit events (`outbox_events`): actor, action, record, time
  3. `dormitory.admin` sees only dormitory events; `reporting.admin` only reporting events; global admin/supervisor see everything
- **Extensions:**
  - *1a. Any other role* — access denied

### UC-C6: Switch Active Role

- **Primary actor:** Any user with more than one assigned role
- **Preconditions:** User is signed in; a session exists
- **Main success scenario:**
  1. User opens the user menu in the navbar — the "Роль" section lists all assigned roles with a check mark on the active one
  2. User picks another assigned role
  3. System stores the role on the **current session only** (other devices keep their own role) and redirects to the home page
  4. All authorization checks (menus, policies, scopes) now use the new role
- **Extensions:**
  - *2a. Role not assigned to the user* — alert, active role unchanged
  - *3a. Active role revoked by an admin while the session lives* — falls back to the highest-privilege assigned role
- **Notes:** new sessions start with the highest-privilege assigned role (`UserRole::ROLE_PRIORITY`).

## Dormitory

### UC-D1: Manage Academic Years

- **Primary actor:** `admin`, `dormitory.admin` (others: view only)
- **Main success scenario:**
  1. Admin creates an academic year (name, start/end date) — status `pending`
  2. Admin activates it; accommodations created afterwards link to it automatically
  3. At year end admin closes it (closed_at is set)
- **Extensions:**
  - *1a. Name not unique among kept years* — validation error
  - *1b. Start date not before end date* — validation error
  - *2a. Another year is already active* — denied
  - *3a. Active accommodations exist* — closing denied
  - *4a. Delete* — allowed only for `pending` years

### UC-D2: Manage Buildings and Rooms

- **Primary actor:** `admin`, `dormitory.admin`
- **Main success scenario:**
  1. Admin creates a building (name, address, floors count)
  2. Admin creates rooms (floor, number, capacity, gender, allowed courses)
  3. System maintains room occupancy status automatically: `free` → `partially_occupied` → `fully_occupied` / `overcrowded`
- **Extensions:**
  - *2a. Mass creation* — admin picks a number range, previews and edits the table, then submits atomically
  - *2b. Duplicate room number in the building* — validation error
  - *2c. Floor outside 1..floors_count* — validation error
  - *3a. Capacity reduced below current occupancy* — warning; confirmable with an override flag
  - *5a. Delete building/room with active accommodations* — denied

### UC-D3: Register Resident (with place)

> State machine of the pending → active flow: [state machines](state-machines.md#accommodation-dormitoryaccommodation).

- **Primary actor:** `dormitory.registrar` (also `admin`, `dormitory.admin`, commandant for their buildings)
- **Stakeholders:** Registrar — data quality; Resident — a reserved place
- **Preconditions:** An active academic year exists
- **Main success scenario:**
  1. Registrar enters personal data (full name, ticket, gender, course, contacts, prepared documents)
  2. System suggests the next free room and bed (matching gender and course)
  3. Registrar confirms the suggestion and optionally records the required amount and a first receipt
  4. System creates the resident and a **pending** accommodation reserving the bed label
  5. Admin/registrar confirms the pending accommodation: resident becomes `settled`, room occupancy grows
- **Extensions:**
  - *2a. Manual room/bed override* — available to `admin`/`dormitory.admin` only
  - *3a. Room full / gender or course mismatch* — validation error; under force (admin) occupancy may exceed capacity → room `overcrowded`
  - *3b. Receipt fields incomplete (file without amount or amount without file)* — form error, resident not created
  - *5a. Admin rejects the pending accommodation* — bed released, resident stays `not_settled`, receipts are kept
  - *5b. Pending edited to another room* — old reservation released, new one taken

### UC-D4: Settle Resident (classic)

- **Primary actor:** `admin`, `dormitory.admin`, commandant (their buildings)
- **Main success scenario:**
  1. Actor opens the settlement form for a resident
  2. Actor picks room, dates, contract/application numbers, required amount
  3. System creates an **active** accommodation, marks the resident `settled`, increments occupancy, recalculates room status, copies prepared documents (first settlement only)
- **Extensions:**
  - *2a. No free bed* — error, or force-settle (`admin`/`dormitory.admin`) leaves the bed empty and may overcrowd
  - *2b. Gender/course mismatch or discarded room* — validation error
  - *3a. Planned end date before start date* — validation error

### UC-D5: Transfer Resident

> Runtime locking protocol: [dynamic view](dynamic-view.md#transfer-between-rooms-do_transfer).

- **Primary actor:** `admin`, `dormitory.admin`, commandant (their buildings)
- **Main success scenario:**
  1. Actor picks a new room (and optionally bed) for a settled resident
  2. System locks both rooms, completes the old accommodation with reason `transfer`, creates a new active one, moves all receipts, inherits the required amount
- **Extensions:**
  - *1a. Destination full/mismatched* — error; force variant overrides capacity

### UC-D6: Evict Resident

- **Primary actor:** `admin`, `dormitory.admin`, commandant (their buildings)
- **Main success scenario:**
  1. Actor chooses an eviction reason (transfer, graduation, expulsion, voluntary, violation, repair, other) and sets the actual end date
  2. System completes the accommodation, sets the resident `evicted`, decrements occupancy, recalculates room status
- **Extensions:**
  - *1a. Reason `other`* — comment required
  - *1b. Missing documents (contract/application)* — flagged, eviction still possible for admins

### UC-D7: Batch Eviction (year-end close)

- **Primary actor:** `admin`, `dormitory.admin`, commandant (their buildings)
- **Main success scenario:**
  1. Actor starts a 3-step wizard: building → residents (settled/temporarily absent of that building) → reason and parameters
  2. System runs a best-effort mass eviction and records a `BatchOperation` with success/error counters
  3. Actor reviews the results page: totals and per-resident errors
- **Extensions:**
  - *2a. Some residents fail* — operation completes with status `partial`; errors stored per resident
  - *2b. Reason `transfer`* — not allowed for batch eviction

### UC-D8: Manage Payment Receipts and Debtors

- **Primary actor:** `admin`, `dormitory.admin`, commandant (their buildings), `dormitory.registrar` (add)
- **Main success scenario:**
  1. Actor adds a receipt (amount, paid date, scanned file) to an active or pending accommodation
  2. System tracks `total_paid` and `balance = total_paid − required_amount`
  3. Actor opens the debtors list (accommodations with negative balance) or exports it to CSV
- **Extensions:**
  - *1a. Accommodation completed/cancelled* — adding denied
  - *1b. Registrar* — can add but not edit/delete

### UC-D9: Register Violation

- **Primary actor:** `admin`, `dormitory.admin`, commandant (their buildings)
- **Main success scenario:**
  1. Actor records a violation: resident, type (noise, damage, …), place, description, date, optional protocol file
  2. Commandant reviews later: sets review date and result → status `reviewed`, then `closed`
- **Extensions:**
  - *1a. Occurred date in the future* — validation error
  - *2a. Review fields missing on reviewed/closed* — validation error; forbidden while `open`

### UC-D10: Export CSV Reports

- **Primary actor:** `admin`, `dormitory.admin`, commandant (scoped data), `dormitory.registrar`
- **Main success scenario:**
  1. Actor opens an export page (settled residents, free slots, accommodation history, occupancy stats) with filters (building, year, dates, status)
  2. System generates a CSV (UTF-8 BOM, `;` delimiter) for Excel
- **Extensions:** none significant

### UC-D11: View Dormitory Dashboard

- **Primary actor:** `admin`, `dormitory.admin`, `dormitory.commandant` (scoped), `dormitory.registrar`
- **Main success scenario:**
  1. Actor opens the dashboard
  2. System shows: active academic year, building/room/resident counts, occupancy rate, total debt and debt by building, room status / gender / resident status distributions, overcrowded rooms, overdue accommodations, recent events
  3. For a commandant every metric is limited to their buildings

## Reporting

### UC-R1: Manage Report Template

- **Primary actor:** `reporting.manager` (also `admin`, `reporting.admin`)
- **Main success scenario:**
  1. Manager creates a template and adds ordered items (name, description, max grade, attachments required)
  2. Manager picks a Typst PDF design for the template
  3. Manager publishes the template; it becomes available for creating reports
  4. Manager archives it later when obsolete
- **Extensions:**
  - *2a. Unknown PDF design name* — falls back to the default design
  - *3a. Edit/archive* — own drafts/published templates or `admin`/`reporting.admin` only

### UC-R2: Create and Publish Report

- **Primary actor:** `reporting.manager` (also `admin`, `reporting.admin`)
- **Main success scenario:**
  1. Manager creates a report from a published template, sets the name, deadline, reporter and reviewer
  2. Report starts as a `draft`; manager publishes it → status `new`
  3. Assigned reporter is notified
- **Extensions:**
  - *2a. Publish with no items* — denied
  - *2b. Reporter and reviewer are the same person* — validation error
  - *2c. Delete* — creator only, drafts only

### UC-R3: Fulfill Report

- **Primary actor:** `reporting.reporter` (assigned)
- **Main success scenario:**
  1. Reporter takes the `new`/`reopened` report in progress
  2. Reporter fills items: content and attachments
  3. Reporter submits the report → status `in_review`
- **Extensions:**
  - *2a. Item requires an attachment but none attached* — flagged in the UI
  - *3a. Submit while required attachments are missing* — denied

### UC-R4: Review Report

- **Primary actor:** `reporting.reviewer` (assigned)
- **Main success scenario:**
  1. Reviewer grades each item (points up to the item's max grade)
  2. Reviewer accepts the report → status `accepted`, total grade computed
- **Extensions:**
  - *2a. Reviewer rejects instead* — reason required (max 2000 chars) → status `rejected`
  - *1a. Not all items graded* — acceptance denied

### UC-R5: Reopen Rejected Report

- **Primary actor:** `reporting.reporter` (assigned)
- **Main success scenario:**
  1. Reporter reopens the rejected report → status `reopened`
  2. Reporter takes it in progress again, reworks items, resubmits
- **Extensions:** none significant

### UC-R6: Comment on Report

- **Primary actor:** Report participants (`manager`, `reporter`, `reviewer`, admins, `supervisor`)
- **Main success scenario:**
  1. Participant writes a comment (max 5000 chars) on the report
  2. System records the author and timestamp
- **Extensions:**
  - *2a. Delete* — author, `admin` or `reporting.admin` only

### UC-R7: Generate Report PDF

- **Primary actor:** Any user with access to the report (view); regeneration — `admin`, `reporting.admin`, `reporting.manager`, creator
- **Main success scenario:**
  1. User opens the report PDF
  2. System renders the Typst template of the report's design, adds a status watermark (no watermark for `accepted`), caches the blob
  3. Subsequent opens serve the cached file until report data changes
  4. Authorized user forces regeneration → new PDF replaces the old blob
- **Extensions:**
  - *2a. Typst compilation fails* — error logged, alert shown
