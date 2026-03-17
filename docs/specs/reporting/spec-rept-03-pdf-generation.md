# SPEC-REPT-03: PDF Generation

PDF document generation from reports using the Typst typesetting engine. Renders ERB templates with report data, applies watermarks for non-accepted reports, and caches generated PDFs with cache-key invalidation.

Depends on: SPEC-REPT-01, SPEC-REPT-02

Status: IMPLEMENTED

## Acceptance Criteria

- AC-1: Report PDF can be viewed (inline) or downloaded
- AC-2: PDF is generated from Typst template via system `typst` binary
- AC-3: Template is resolved from report's template, falling back to `generic.typ.erb`
- AC-4: PDF is cached as Active Storage attachment with cache_key metadata
- AC-5: Cached PDF is returned on subsequent requests if cache_key matches
- AC-6: `regenerate_pdf` action forces regeneration even if cache is valid
- AC-7: Non-accepted reports have a diagonal watermark showing status text
- AC-8: Accepted reports have no watermark
- AC-9: Watermark text is translated by status: draft→ЧЕРНОВИК, in_progress→В РАБОТЕ, in_review→НА ПРОВЕРКЕ, rejected→ОТКЛОНЁН, new→НОВЫЙ, reopened→ПЕРЕОТКРЫТ
- AC-10: PDF filename is the report name parameterized (fallback to ID)
- AC-11: Typst compilation error is logged and raises exception
- AC-12: ERB rendering uses trim_mode: "-" to suppress unwanted whitespace
- AC-13: PDF generation failure shows user-friendly alert (not stack trace)
- AC-14: Only authorized users can view/regenerate PDF (same as report show access)

## UI/UX Notes

- Report show page: "View PDF" / "Download PDF" button
- "Regenerate PDF" button for forced regeneration
- PDF opens inline in browser (disposition: inline)
- Failure alert: generic error message, details logged server-side
- Generated filename: `{report-name-parameterized}.pdf`

## Business Rules

- BR-1: `PdfGenerator` takes report and optional `force:` flag
- BR-2: Cached PDF is valid if `pdf_file.attached?` AND `blob.metadata["cache_key"] == report.pdf_cache_key`
- BR-3: `pdf_cache_key` is provided by the Report model (implementation-defined)
- BR-4: Generation creates temp directory via `Dir.mktmpdir` for Typst input/output
- BR-5: ERB template is read from `resolve_template` path and rendered with report binding
- BR-6: Typst is compiled via `Open3.capture3(bin, "compile", input_path, output_path)`
- BR-7: `typst_bin_path` is read from `Rails.configuration.typst_bin_path`
- BR-8: On successful compile, old pdf_file is purged and new one attached
- BR-9: Blob metadata is updated with current cache_key after attachment
- BR-10: `typst_escape` escapes special Typst characters: `\`, `#`, `[`, `]`, `{`, `}`, `@`, `$`, `` ` ``, `_`, `*`, `~`, `<`, `>`, newlines
- BR-11: `format_date` formats datetime as `dd.mm.yyyy`, nil as em-dash
- BR-12: `user_name` returns `profile.full_name` or em-dash
- BR-13: Errors during generation are re-raised after logging to `Rails.logger.error`

## Behavior

### Background
Given report "Q1 Report" exists with status `accepted`, 2 items (graded)
And Typst binary is available at configured path

### Rule: Generate PDF (BR-1 through BR-8)

#### Scenario: First generation (no cache)
Given report has no attached PDF
When user clicks "View PDF"
Then ERB template is rendered with report data
And Typst compiles the `.typ` to `.pdf`
And PDF is attached to report via Active Storage
And blob metadata has cache_key set
And PDF is sent to browser inline

#### Scenario: Cached PDF returned
Given report has attached PDF with matching cache_key
When user clicks "View PDF"
Then cached PDF is returned (no Typst compilation)
And no new temp files are created

#### Scenario: Force regeneration
Given report has cached PDF with matching cache_key
When user clicks "Regenerate PDF"
Then old PDF is purged
And new PDF is generated and attached
And user is redirected to PDF view

#### Scenario: Cache miss triggers regeneration
Given report has attached PDF but cache_key changed (e.g., items updated)
When user clicks "View PDF"
Then new PDF is generated (old one replaced)

### Rule: Watermarks (BR-9)

#### Scenario: Accepted report has no watermark
Given report is `accepted`
When PDF is generated
Then PDF has no watermark overlay

#### Scenario: Draft report has draft watermark
Given report is `draft`
When PDF is generated
Then PDF has diagonal "ЧЕРНОВИК" watermark in light gray at 40% top

#### Scenario: In-progress report has watermark
Given report is `in_progress`
When PDF is generated
Then PDF has "В РАБОТЕ" watermark

#### Scenario: Rejected report has watermark
Given report is `rejected`
When PDF is generated
Then PDF has "ОТКЛОНЁН" watermark

### Rule: Error Handling (BR-10, BR-13)

#### Scenario: Typst compilation fails
Given Typst binary returns non-zero exit code
When PDF generation is triggered
Then `Rails.logger.error` records the stderr output
And exception is raised with "typst compile failed"
And user sees friendly alert "PDF generation failed"

#### Scenario: Template file missing
Given resolved template path does not exist
When PDF generation is triggered
Then an I/O error occurs during template read
And user sees friendly alert (not stack trace)
