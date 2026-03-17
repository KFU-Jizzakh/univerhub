# SPEC-REPT-01: Reports Lifecycle

Full report lifecycle with 7 AASM states: draft → new → in_progress → in_review → accepted/rejected, with reopening from rejected. Reports contain ordered items with content, attachments, and grading. Supports comments, deadline tracking, and role-based workflow.

Depends on: SPEC-CORE-01, SPEC-CORE-02

Status: IMPLEMENTED

## Acceptance Criteria

- AC-1: Manager/admin/reporting.admin can create a report (name, description, deadline, reporter, reviewer)
- AC-2: Report is created in `draft` status
- AC-3: Manager can publish draft → `new` (only if report has items)
- AC-4: Reporter can take report `in_progress` (from `new` or `reopened`)
- AC-5: Reporter can edit report items (content, attachments) while `in_progress`
- AC-6: Reporter can submit report `in_review` (only if all required attachments are present)
- AC-7: Submission sets `submitted_at` timestamp
- AC-8: Reviewer can reject report (must provide rejection_reason)
- AC-9: Reviewer can accept report (only if all items are graded)
- AC-10: Acceptance sets `reviewed_at` and calculates `total_grade` (sum of all item grades)
- AC-11: Reporter can reopen a rejected report → `reopened`
- AC-12: Draft report can be created from a report template (items copied from template)
- AC-13: Report can be soft-deleted (discarded) only by creator-manager in draft status
- AC-14: Report is filterable: status, reporter, reviewer, deadline range, name search
- AC-15: Overdue reports (deadline passed, not accepted/archived) are tracked in scope
- AC-16: Deadline-soon reports (within N days) are tracked in scope
- AC-17: Comments can be added to a report by any participant
- AC-18: Comment creator is stored as User, body is required (max 5000 chars)
- AC-19: Report items have name, content, attachments, grade, grade_comment, max_grade
- AC-20: Reporter and reviewer must be different users
- AC-21: All state changes and item updates are tracked via OutboxEvent

## UI/UX Notes

- Reports index: filterable table (name, status badge, reporter, reviewer, deadline, overdue indicator)
- Report show: status timeline, items list with grading, comments thread, action bar (state-dependent buttons)
- Report form: name, description, template selector, deadline date picker, reporter/reviewer selects
- Item form: name, content textarea, attachment upload, grade input (reviewer only)
- Action bar buttons change based on current state: Publish, Take in Progress, Submit, Accept/Reject, Reopen
- Warn before publishing if no items exist
- Overdue reports highlighted with warning color

## Business Rules

- BR-1: AASM states: `draft` (initial) → `new` → `in_progress` → `in_review` → `accepted` | `rejected`; `rejected` → `reopened` → `in_progress`
- BR-2: `publish` guard: `has_items?` — report must have at least one report_item
- BR-3: `submit` guard: `all_attachments_present?` — all items with `attachments_required` must have files
- BR-4: `accept` guard: `all_items_graded?` — every item must have a grade, before callback calculates `total_grade`
- BR-5: `rejection_reason` required when `rejected?` (validated, max 2000 chars)
- BR-6: `reporter_id`, `reviewer_id`, `deadline` required unless `draft?`
- BR-7: `reporter_and_reviewer_must_differ` validation
- BR-8: Scope by role: admin/supervisor/reporting.admin → all; visitor → non-draft; manager → where creator=user; reviewer → where reviewer=user; reporter → where reporter=user
- BR-9: `overdue` scope: `deadline < now AND status NOT IN (accepted, archived)`
- BR-10: `deadline_soon(days)` scope: `deadline BETWEEN now AND N.days.from_now`
- BR-11: `editable?` — report is in a state where reporter can modify items
- BR-12: `missing_attachment_items` — items with `attachments_required` but no files
- BR-13: Comments accessible to all participants (manager, reporter, reviewer, supervisor, admin)
- BR-14: Comment deletion: only comment author, admin, or reporting.admin
- BR-15: `do_publish!` aborts on `AASM::InvalidTransition` if no items (guard failure)

## Behavior

### Background
Given user "Manager" (role: reporting.manager)
And user "Reporter" (role: reporting.reporter)
And user "Reviewer" (role: reporting.reviewer)
And user "Admin" (role: reporting.admin)

### Rule: Create and Publish (BR-1, BR-2)

#### Scenario: Create draft report
When Manager creates report "Q1 Report" with deadline=next_month, reporter=Reporter, reviewer=Reviewer
Then report is created with status `draft`
And OutboxEvent `reporting.report.created` is logged

#### Scenario: Create report from template
Given report template "Monthly Report" exists with 3 items
When Manager creates report selecting template "Monthly Report"
Then report is created with 3 report_items copied from template
And items retain name, description, attachments_required, max_grade

#### Scenario: Publish draft with items
Given report has 2 items
When Manager publishes the report
Then status transitions from `draft` to `new`

#### Scenario: Publish draft without items fails
Given report has no items
When Manager tries to publish
Then transition is blocked (guard `has_items?` fails)

### Rule: Work in Progress (BR-3, BR-11, BR-12)

#### Scenario: Take in progress
Given report is `new` and assigned to Reporter
When Reporter clicks "Take in Progress"
Then status transitions to `in_progress`

#### Scenario: Reporter updates item content
Given report is `in_progress` and assigned to Reporter
When Reporter edits item #1 with content "Updated text" and attaches file report.pdf
Then item is updated
And OutboxEvent `reporting.report_item.updated` is logged

#### Scenario: Submit to review
Given report is `in_progress` and all required attachments are present
When Reporter clicks "Submit"
Then status transitions to `in_review`
And `submitted_at` is set

#### Scenario: Submit without required attachments fails
Given item #1 requires attachment but has none
When Reporter tries to submit
Then transition is blocked (guard `all_attachments_present?` fails)

### Rule: Review and Accept/Reject (BR-4, BR-5)

#### Scenario: Reviewer grades all items and accepts
Given report is `in_review` assigned to Reviewer
When Reviewer grades item #1=5 and item #2=3, then clicks "Accept"
Then `total_grade` is calculated as 8
And status transitions to `accepted`
And `reviewed_at` is set

#### Scenario: Accept with ungraded items fails
Given item #2 has no grade
When Reviewer tries to accept
Then transition is blocked (guard `all_items_graded?` fails)

#### Scenario: Reject with reason
Given report is `in_review` assigned to Reviewer
When Reviewer rejects with reason "Insufficient data"
Then status transitions to `rejected`
And `reviewed_at` is set
And `rejection_reason` is stored

#### Scenario: Reject without reason fails
When Reviewer tries to reject with empty reason
Then validation error about rejection_reason presence is raised

### Rule: Reopen (BR-1)

#### Scenario: Reopen rejected report
Given report is `rejected` and assigned to Reporter
When Reporter clicks "Reopen"
Then status transitions to `reopened`

#### Scenario: Take reopened in progress
Given report is `reopened`
When Reporter clicks "Take in Progress"
Then status transitions to `in_progress`

### Rule: Scoped Access (BR-8)

#### Scenario: Reporter sees only their reports
When Reporter visits reports index
Then only reports where reporter=Reporter are displayed

#### Scenario: Manager sees only their created reports
When Manager visits reports index
Then only reports where creator=Manager are displayed

#### Scenario: Admin sees all reports
When Admin visits reports index
Then all reports are displayed (including others' drafts)

### Rule: Overdue Tracking (BR-9, BR-10)

#### Scenario: Overdue report highlighted
Given report deadline is yesterday, status is `in_progress`
When viewing reports index
Then report is included in overdue scope and highlighted

#### Scenario: Deadline approaching
Given report deadline is 2 days from now, status is `in_progress`
When checking `deadline_soon?(3)`
Then report is flagged as deadline soon

### Rule: Comments (BR-13, BR-14)

#### Scenario: Add comment
When a participant adds comment "Needs more data"
Then comment is created with user and body
And OutboxEvent `reporting.report_comment.created` is logged

#### Scenario: Delete own comment
Given Reporter created a comment
When Reporter deletes the comment
Then comment is destroyed

#### Scenario: Cannot delete another's comment (non-admin)
Given Reviewer created a comment
When Reporter tries to delete it
Then authorization fails (Pundit)
