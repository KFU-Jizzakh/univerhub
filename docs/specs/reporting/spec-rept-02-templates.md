# SPEC-REPT-02: Report Templates

Report templates define the structure of reports: ordered items with grading parameters and attachment requirements. Templates are managed by managers, reporting administrators, and admins and have a publish/archive lifecycle.

Depends on: SPEC-CORE-02, SPEC-REPT-01

Status: IMPLEMENTED

## Acceptance Criteria

- AC-1: Manager, reporting administrator, and admin can create a report template (name, description)
- AC-2: Template items can be added, edited, or deleted
- AC-3: Template items have: name, description, position (order), max grade, attachment requirement flag
- AC-4: Items are ordered by their position
- AC-5: Template starts as draft status
- AC-6: Template can be published (draft → published)
- AC-7: Template can be archived (published → archived)
- AC-8: Only published templates appear in the report creation template selector
- AC-9: Template can specify a custom PDF design name (letters, digits, and underscores only)
- AC-10: If a custom PDF design exists for the template, it is used; otherwise the default design is used
- AC-11: Template PDF design resolution is protected against directory traversal attacks
- AC-12: Templates index lists all accessible templates (paginated)
- AC-13: Templates are visible to all authenticated users; only managers, reporting administrators, and admins can manage them

## UI/UX Notes

- Templates index: paginated table with name, status badge, item count, creator
- Template show: name, description, items list (ordered), "Add item" button, publish/archive buttons
- Item management: inline add/remove with live updates
- New/edit template form: name, description
- Template selector in report form: dropdown of published templates

## Business Rules

- BR-1: Template has a creator (user who created it)
- BR-2: Template contains ordered items; deleting a template removes all its items
- BR-3: Template states: draft, published, archived
- BR-4: Only published templates are available for report creation
- BR-5: Publishing transitions draft to published and logs the event
- BR-6: Archiving transitions published to archived and logs the event
- BR-7: Custom PDF design name must contain only letters, digits, and underscores
- BR-8: If a template specifies a custom PDF design, that design is used; otherwise the default design is used
- BR-9: Template items are ordered; first item starts at position 0
- BR-10: Published templates are visible to all authenticated users; draft templates are visible only to the creator, reporting administrators, and admins
- BR-11: Only the creator can modify, publish, or delete their own draft templates

## Behavior

### Background
Given Manager (reporting.manager) exists

### Rule: CRUD (BR-1, BR-2)

#### Scenario: Create template
When Manager creates template "Monthly Report" with description "Monthly progress report"
Then template is created with status draft
And creator is set to Manager

#### Scenario: Add item to template
Given template "Monthly Report" exists
When Manager adds item "Project Status" with max grade=5, attachment required=true, position=0
Then item is created
And appears in template items list

#### Scenario: Add second item
Given template has item at position 0
When Manager adds item "Risks" at position 1
Then both items appear ordered by position: "Project Status" (0), "Risks" (1)

#### Scenario: Delete item
Given template has 2 items
When Manager deletes item #1
Then item is removed
And remaining item count is 1

### Rule: Lifecycle (BR-5, BR-6)

#### Scenario: Publish template
Given template "Monthly Report" is draft
When Manager publishes it
Then status changes to published
And the event is recorded in the audit log

#### Scenario: Archive published template
Given template is published
When Manager archives it
Then status changes to archived
And the event is recorded in the audit log

#### Scenario: Draft template not available for report creation
Given template "Monthly Report" is draft
When creating a new report and viewing template selector
Then "Monthly Report" is not listed (only published templates)

#### Scenario: Published template appears in selector
Given template is published
When creating a new report
Then "Monthly Report" appears in template dropdown

### Rule: PDF Design (BR-7, BR-8)

#### Scenario: Custom PDF design exists
Given template specifies custom design name "monthly"
And a design file exists for that name
When resolving the PDF design
Then the custom design is used

#### Scenario: Custom PDF design does not exist
Given template specifies a custom design name, but no design file exists for it
When resolving the PDF design
Then the default design is used

#### Scenario: Invalid PDF design name
When Manager attempts to set a design name with path traversal characters (e.g., "../../../etc/passwd")
Then validation fails (name contains invalid characters)

#### Scenario: Directory traversal protection
Given template's resolved design path would point outside the allowed design directory
When resolving the PDF design
Then the default design is used as a safety fallback
