# SPEC-REPT-02: Report Templates

Report templates define the structure of reports: ordered items with grading parameters and attachment requirements. Templates are managed by managers/admin and have publish/archive lifecycle.

Depends on: SPEC-CORE-02, SPEC-REPT-01

Status: IMPLEMENTED

## Acceptance Criteria

- AC-1: Manager/admin/reporting.admin can create a report template (name, description)
- AC-2: Template items can be added/edited/deleted via Turbo Stream
- AC-3: Template items have: name, description, position (order), max_grade, attachments_required flag
- AC-4: Items are ordered by `position` ascending
- AC-5: Template starts as `draft` status
- AC-6: Template can be published (draft → published)
- AC-7: Template can be archived (published → archived)
- AC-8: Only published templates appear in report creation template selector
- AC-9: Template can specify a custom PDF template filename (must match alphanumeric + underscore)
- AC-10: Template resolves PDF template path: custom file if exists, else `generic.typ.erb`
- AC-11: Template PDF path is directory-traversal safe (uses `cleanpath` + prefix check)
- AC-12: Templates index lists all accessible templates (paginated)
- AC-13: Templates are visible to all authenticated users; only managers/admin can manage

## UI/UX Notes

- Templates index: paginated table with name, status badge, item count, creator
- Template show: name, description, items list (ordered), "Add item" button, publish/archive buttons
- Item management: Turbo Stream add/remove with inline editing
- New/edit template form: name, description
- Template selector in report form: dropdown of published templates

## Business Rules

- BR-1: `ReportTemplate` belongs_to `creator` (User)
- BR-2: `ReportTemplate` has_many `items` (ReportTemplateItem, dependent: destroy)
- BR-3: Status enum: `draft=0`, `published=1`, `archived=2`
- BR-4: `scope :available` → `where(status: :published)`
- BR-5: `do_publish!` transitions to published and logs event
- BR-6: `do_archive!` transitions to archived and logs event
- BR-7: `pdf_template` validated as alphanumeric + underscore if present
- BR-8: `pdf_template_path` checks custom file exists, falls back to `generic.typ.erb`
- BR-9: `PDF_TEMPLATES_DIR` = `app/views/reporting/pdf_templates`
- BR-10: Template items position starts from 0
- BR-11: Policy: published templates visible to all, draft only to creator-manager/admin
- BR-12: Only creator-manager can update/destroy/publish their own draft templates

## Behavior

### Background
Given Manager (reporting.manager) exists

### Rule: CRUD (BR-1, BR-2)

#### Scenario: Create template
When Manager creates template "Monthly Report" with description "Monthly progress report"
Then template is created with status `draft`
And creator is set to Manager

#### Scenario: Add item to template
Given template "Monthly Report" exists
When Manager adds item "Project Status" with max_grade=5, attachments_required=true, position=0
Then item is created via Turbo Stream
And appears in template items list

#### Scenario: Add second item
Given template has item at position 0
When Manager adds item "Risks" at position 1
Then both items appear ordered by position: "Project Status" (0), "Risks" (1)

#### Scenario: Delete item
Given template has 2 items
When Manager deletes item #1
Then item is removed via Turbo Stream
And remaining item count is 1

### Rule: Lifecycle (BR-5, BR-6)

#### Scenario: Publish template
Given template "Monthly Report" is `draft`
When Manager publishes it
Then status changes to `published`
And OutboxEvent `reporting.report_template.published` is logged

#### Scenario: Archive published template
Given template is `published`
When Manager archives it
Then status changes to `archived`
And OutboxEvent `reporting.report_template.archived` is logged

#### Scenario: Draft template not in available scope
Given template "Monthly Report" is `draft`
When creating a new report and viewing template selector
Then "Monthly Report" is not listed (only published templates)

#### Scenario: Published template appears in selector
Given template is `published`
When creating a new report
Then "Monthly Report" appears in template dropdown

### Rule: PDF Template (BR-7, BR-8, BR-9)

#### Scenario: Custom PDF template exists
Given template has pdf_template="monthly"
And file `app/views/reporting/pdf_templates/monthly.typ.erb` exists
When `pdf_template_path` is called
Then path resolves to `monthly.typ.erb`

#### Scenario: Custom PDF template does not exist
Given template has pdf_template="nonexistent"
When `pdf_template_path` is called
Then path falls back to `generic.typ.erb`

#### Scenario: Invalid PDF template name
When Manager sets pdf_template="../../../etc/passwd"
Then validation error `invalid_pdf_template` is raised (non-alphanumeric)

#### Scenario: Directory traversal protection
Given template's resolved path would be outside PDF_TEMPLATES_DIR
When `pdf_template_path` is called
Then fallback to generic is triggered (cleanpath + prefix check)
