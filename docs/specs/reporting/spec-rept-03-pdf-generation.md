# SPEC-REPT-03: PDF Generation

PDF document generation from reports. Applies watermarks for non-accepted reports and caches generated PDFs for performance. A cached PDF is reused until the underlying report data changes.

Depends on: SPEC-REPT-01, SPEC-REPT-02

Status: IMPLEMENTED

## Acceptance Criteria

- AC-1: Report PDF can be viewed inline in the browser or downloaded
- AC-2: PDF is generated from the report's template design
- AC-3: Template design is resolved from the report's template, falling back to the default design
- AC-4: Generated PDF is cached for subsequent access
- AC-5: Cached PDF is returned when the report has not changed since the last generation
- AC-6: PDF can be forcefully regenerated on demand even when cache is valid
- AC-7: Non-accepted reports have a diagonal watermark showing the report's status
- AC-8: Accepted reports have no watermark
- AC-9: Watermark text by status: draft→ЧЕРНОВИК, in progress→В РАБОТЕ, in review→НА ПРОВЕРКЕ, rejected→ОТКЛОНЁН, new→НОВЫЙ, reopened→ПЕРЕОТКРЫТ
- AC-10: PDF filename is based on the report name (fallback to ID)
- AC-11: Generation errors are logged and reported to the user
- AC-12: Only authorized users can view or regenerate PDFs (same access as report viewing)

## UI/UX Notes

- Report show page: "View PDF" / "Download PDF" buttons
- "Regenerate PDF" button for forced regeneration
- PDF opens inline in the browser
- Failure alert: generic error message; details are logged server-side
- Generated filename: parameterized version of the report name

## Business Rules

- BR-1: PDF generation accepts a report and an optional force-regenerate flag
- BR-2: Cached PDF is valid when the report has not been modified since the last generation
- BR-3: A version identifier tracks report changes for cache invalidation
- BR-4: The template design is rendered with the report's data
- BR-5: The rendered template is compiled into a PDF document
- BR-6: On successful generation, the old cached PDF is replaced with the new one
- BR-7: The version identifier is updated after each generation
- BR-8: Special characters in report content are safely escaped for PDF rendering
- BR-9: Dates are formatted as dd.mm.yyyy; missing dates are shown as an em-dash
- BR-10: User names are displayed; missing names are shown as an em-dash
- BR-11: Generation errors are logged and result in a user-friendly error message

## Behavior

### Background
Given report "Q1 Report" exists with status accepted and 2 graded items

### Rule: Generate PDF (BR-1 through BR-7)

#### Scenario: First generation (no cache)
Given report has no cached PDF
When user clicks "View PDF"
Then the template design is rendered with report data
And the design is compiled into a PDF
And the PDF is stored and linked to the report
And the version identifier is recorded
And the PDF is displayed in the browser

#### Scenario: Cached PDF returned
Given report has a cached PDF matching the current version
When user clicks "View PDF"
Then the cached PDF is returned (no generation occurs)

#### Scenario: Force regeneration
Given report has a cached PDF matching the current version
When user clicks "Regenerate PDF"
Then the old cached PDF is replaced
And a new PDF is generated and stored
And user is redirected to the PDF view

#### Scenario: Cache miss triggers regeneration
Given report has a cached PDF but the report was modified since (e.g., items updated)
When user clicks "View PDF"
Then a new PDF is generated (old one replaced)

### Rule: Watermarks (BR-8)

#### Scenario: Accepted report has no watermark
Given report is accepted
When PDF is generated
Then PDF has no watermark overlay

#### Scenario: Draft report has draft watermark
Given report is draft
When PDF is generated
Then PDF has a diagonal "ЧЕРНОВИК" watermark

#### Scenario: In-progress report has watermark
Given report is in progress
When PDF is generated
Then PDF has a "В РАБОТЕ" watermark

#### Scenario: Rejected report has watermark
Given report is rejected
When PDF is generated
Then PDF has an "ОТКЛОНЁН" watermark

### Rule: Error Handling (BR-11)

#### Scenario: PDF generation fails
Given the generation process encounters an error
When PDF generation is triggered
Then the error details are logged
And an internal error is raised
And user sees a friendly alert "PDF generation failed"

#### Scenario: Template design file missing
Given the resolved template design does not exist
When PDF generation is triggered
Then the error is reported
And user sees a friendly alert (not a technical trace)
