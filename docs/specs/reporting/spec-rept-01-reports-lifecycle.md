# SPEC-REPT-01: Reports Lifecycle

Full report lifecycle with 7 states: draft → new → in progress → in review → accepted/rejected, with reopening from rejected. Reports contain ordered items with content, attachments, and grading. Supports comments, deadline tracking, and role-based workflow.

Depends on: SPEC-CORE-01, SPEC-CORE-02

Status: IMPLEMENTED

## Acceptance Criteria

- AC-1: Manager, reporting administrator, and admin can create a report (name, description, deadline, reporter, reviewer)
- AC-2: Report is created in draft status
- AC-3: Manager can publish draft → new (only if report has items)
- AC-4: Reporter can take report in progress (from new or reopened)
- AC-5: Reporter can edit report items (content, attachments) while in progress
- AC-6: Reporter can submit report to review (only if all required attachments are present)
- AC-7: Submission records the submission timestamp
- AC-8: Reviewer can reject report (must provide rejection reason)
- AC-9: Reviewer can accept report (only if all items are graded)
- AC-10: Acceptance records the review timestamp and calculates total grade as sum of all item grades
- AC-11: Reporter can reopen a rejected report → reopened
- AC-12: Draft report can be created from a report template (items copied from template)
- AC-13: Report can be soft-deleted only by the creator (manager, reporting administrator, or admin), and only in draft status
- AC-14: Report is filterable: status, reporter, reviewer, deadline range, name search
- AC-15: Overdue reports (deadline passed, not yet accepted) are identified
- AC-16: Deadline-soon reports (within N days) are identified
- AC-17: Comments can be added to a report by any participant
- AC-18: Comment requires body (max 5000 chars); author is recorded
- AC-19: Report items have name, content, attachments, grade, grade comment, max grade
- AC-20: Reporter and reviewer must be different users
- AC-21: All state changes and item updates are recorded in the audit log

## UI/UX Notes

- Reports index: filterable table (name, status badge, reporter, reviewer, deadline, overdue indicator)
- Report show: status timeline, items list with grading, comments thread, action bar with state-dependent buttons
- Report form: name, description, template selector, deadline date picker, reporter/reviewer selects
- Item form: name, content textarea, attachment upload, grade input (reviewer only)
- Action bar buttons change based on current state: Publish, Take in Progress, Submit, Accept/Reject, Reopen
- Warn before publishing if no items exist
- Overdue reports highlighted with warning color

## Business Rules

- BR-1: States: draft (initial) → new → in progress → in review → accepted | rejected; rejected → reopened → in progress
- BR-2: Publish requires at least one item in the report
- BR-3: Submit to review requires all items that mandate attachments to have files attached
- BR-4: Accept requires every item to have a grade; total grade is the sum of all item grades
- BR-5: Rejection reason is required when rejecting (max 2000 chars)
- BR-6: Reporter, reviewer, and deadline are required unless the report is in draft status
- BR-7: Reporter and reviewer must be different users
- BR-8: Visibility by role: admin, supervisor, reporting.admin → all reports; visitor → non-draft reports; manager → own reports; reviewer → assigned reports; reporter → assigned reports
- BR-9: Overdue: deadline has passed and report is not yet accepted
- BR-10: Deadline soon: deadline is within N days from now
- BR-11: Reporter can modify items only when the report is in an editable state
- BR-12: Items requiring attachments but lacking files are flagged
- BR-13: Comments visible to all participants (manager, reporter, reviewer, supervisor, admin)
- BR-14: Comment deletion: only comment author, admin, or reporting.admin
- BR-15: Attempting to publish a report with no items fails with an error

## Behavior

### Background
Given user "Manager" (role: reporting.manager)
And user "Reporter" (role: reporting.reporter)
And user "Reviewer" (role: reporting.reviewer)
And user "Admin" (role: reporting.admin)

### Rule: Create and Publish (BR-1, BR-2)

#### Scenario: Create draft report
When Manager creates report "Q1 Report" with deadline=next_month, reporter=Reporter, reviewer=Reviewer
Then report is created with status draft
And the event is recorded in the audit log

#### Scenario: Create report from template
Given report template "Monthly Report" exists with 3 items
When Manager creates report selecting template "Monthly Report"
Then report is created with 3 items copied from template
And items retain name, description, attachment requirement, and max grade

#### Scenario: Publish draft with items
Given report has 2 items
When Manager publishes the report
Then status transitions from draft to new

#### Scenario: Publish draft without items fails
Given report has no items
When Manager tries to publish
Then publishing is blocked (report has no items)

### Rule: Work in Progress (BR-3, BR-11, BR-12)

#### Scenario: Take in progress
Given report is new and assigned to Reporter
When Reporter clicks "Take in Progress"
Then status transitions to in progress

#### Scenario: Reporter updates item content
Given report is in progress and assigned to Reporter
When Reporter edits item #1 with content "Updated text" and attaches file report.pdf
Then item is updated
And the event is recorded in the audit log

#### Scenario: Submit to review
Given report is in progress and all required attachments are present
When Reporter clicks "Submit"
Then status transitions to in review
And submission timestamp is set

#### Scenario: Submit without required attachments fails
Given item #1 requires an attachment but has none
When Reporter tries to submit
Then submission is blocked (missing required attachments)

### Rule: Review and Accept/Reject (BR-4, BR-5)

#### Scenario: Reviewer grades all items and accepts
Given report is in review assigned to Reviewer
When Reviewer grades item #1=5 and item #2=3, then clicks "Accept"
Then total grade is calculated as 8
And status transitions to accepted
And review timestamp is set

#### Scenario: Accept with ungraded items fails
Given item #2 has no grade
When Reviewer tries to accept
Then acceptance is blocked (not all items graded)

#### Scenario: Reject with reason
Given report is in review assigned to Reviewer
When Reviewer rejects with reason "Insufficient data"
Then status transitions to rejected
And review timestamp is set
And rejection reason is stored

#### Scenario: Reject without reason fails
When Reviewer tries to reject with empty reason
Then validation error about required rejection reason is raised

### Rule: Reopen (BR-1)

#### Scenario: Reopen rejected report
Given report is rejected and assigned to Reporter
When Reporter clicks "Reopen"
Then status transitions to reopened

#### Scenario: Take reopened in progress
Given report is reopened
When Reporter clicks "Take in Progress"
Then status transitions to in progress

### Rule: Visibility by Role (BR-8)

#### Scenario: Reporter sees only their reports
When Reporter visits reports index
Then only reports assigned to Reporter are displayed

#### Scenario: Manager sees only their created reports
When Manager visits reports index
Then only reports created by Manager are displayed

#### Scenario: Admin sees all reports
When Admin visits reports index
Then all reports are displayed (including others' drafts)

### Rule: Overdue Tracking (BR-9, BR-10)

#### Scenario: Overdue report highlighted
Given report deadline is yesterday, status is in progress
When viewing reports index
Then report is flagged as overdue and highlighted

#### Scenario: Deadline approaching
Given report deadline is 2 days from now, status is in progress
When checking if deadline is within 3 days
Then report is flagged as deadline soon

### Rule: Comments (BR-13, BR-14)

#### Scenario: Add comment
When a participant adds comment "Needs more data"
Then comment is created with user and body
And the event is recorded in the audit log

#### Scenario: Delete own comment
Given Reporter created a comment
When Reporter deletes the comment
Then comment is destroyed

#### Scenario: Cannot delete another's comment (non-admin)
Given Reviewer created a comment
When Reporter tries to delete it
Then authorization fails
