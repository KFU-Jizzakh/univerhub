# SPEC-DORM-09: Payment Receipts & Amount Tracking

Adds financial payment tracking to dormitory accommodations: a required amount field on the accommodation, individual payment receipts with amounts and file attachments, payment summary with balance calculation, payment status visualization across the UI, dashboard, and CSV exports, and a debtors list mode on the accommodations index with totals and CSV export.

Depends on: SPEC-CORE-02, SPEC-DORM-04, SPEC-DORM-06, SPEC-DORM-07

Status: PLANNED

## Data Model

### `dormitory_accommodations` — new column

| Column | Type | Null | Default | Description |
|--------|------|------|---------|-------------|
| `required_amount` | `decimal(10,2)` | `false` | `0` | Total amount to be paid for the accommodation period |

### `dormitory_receipts` — new table

| Column | Type | Null | Default | Description |
|--------|------|------|---------|-------------|
| `accommodation_id` | `bigint` (FK) | `false` | — | Reference to parent accommodation |
| `amount` | `decimal(10,2)` | `false` | — | Paid amount in this receipt |
| `paid_at` | `date` | `false` | — | Date of payment |
| `comment` | `text` | `true` | — | Optional comment |
| `discarded_at` | `datetime` | `true` | — | Soft-delete via Discard |
| `attachment` | Active Storage | — | — | Scanned receipt file (PDF/JPEG/PNG, ≤10 MB) |

## Acceptance Criteria

### Accommodation amount
- AC-1: Admin, dormitory administrator, and commandant can enter `required_amount` when creating or editing an accommodation
- AC-2: `required_amount` is a decimal number ≥ 0, default 0
- AC-3: `required_amount` is displayed on the accommodation show page

### Receipt CRUD
- AC-4: Admin, dormitory administrator, commandant, and registrar can add a receipt to an active accommodation: amount (> 0), paid_at (default today), payment file (PDF/JPEG/PNG, ≤10 MB), optional comment
- AC-5: Admin, dormitory administrator, and commandant can edit a receipt (change amount, paid_at, comment, or re-upload file); registrar cannot edit or delete receipts
- AC-6: File is required when creating a receipt; on edit, existing file is kept if no new file is uploaded
- AC-7: Receipt delete is a soft-delete (Discard) — the record is marked discarded, not physically removed
- AC-8: Deleted receipts are excluded from `total_paid`, not shown in the list, and cannot be restored via UI
- AC-9: Receipts can only be created, edited, or deleted while the parent accommodation is active or pending

### Settlement with receipt
- AC-10: Receipts are created independently via the dedicated `ReceiptsController` (nested under accommodations), not inline in the settlement form — receipts are not required for settlement
- AC-11: Receipts can be added to an active accommodation at any time, not only during settlement

### Payment summary
- AC-13: Accommodation show page displays a payment summary block: required amount, total paid, balance
- AC-14: `total_paid` = sum of all kept receipts' amounts for the accommodation
- AC-15: `balance` = `total_paid` − `required_amount` (positive = overpayment, negative = debt)
- AC-16: Balance display is colored: green if ≥ 0, red if < 0
- AC-17: The accommodations index shows a payment column only in debtors mode ("Долг", absolute value in red); the regular mode has no balance column
- AC-18: Resident history table (on resident show) includes `required_amount`, `total_paid`, and `balance` columns

### Receipt list on accommodation show
- AC-19: Accommodation show displays a table of all kept receipts: paid_at, amount, file link, comment, edit/delete actions
- AC-20: "Add receipt" button is shown when the accommodation is active or pending
- AC-21: "Pay remaining" quick-action button is shown when accommodation is active or pending AND balance < 0 — clicking it opens the receipt form with amount pre-filled to the remaining debt

### Audit logging
- AC-22: Receipt creation, update, and deletion are recorded via Trackable (OutboxEvent), same as accommodation events

### Access control
- AC-23: Receipts follow the same authorization model as Accommodation: admin/dormitory.admin have full access; commandants can only access receipts of accommodations in their assigned buildings; registrar can add receipts to any active accommodation (global scope) but cannot edit or delete them

### Dashboard
- AC-24: Dashboard shows a "Total debt" metric card (sum of negative balances across all accessible active accommodations, shown as absolute value)
- AC-25: Dashboard shows a "Debt by building" breakdown (grouped by building, showing building name and total debt)

### Exports
- AC-26: Settled residents export (SPEC-DORM-06 AC-7) gains three additional columns: "Сумма к оплате", "Уплачено", "Остаток"
- AC-27: Accommodation history export (SPEC-DORM-06 AC-16) gains three additional columns: "Сумма к оплате", "Уплачено", "Остаток"

### N+1 prevention
- AC-28: When loading accommodations with receipts, N+1 queries are avoided via `includes(:receipts)`; `total_paid` and `balance` reuse the preloaded receipts instead of issuing per-row SUM queries

### Debtors list
- AC-29: The accommodations index has a "Только должники" checkbox; when enabled, only active accommodations with balance < 0 (debtors) are shown
- AC-30: Debtor rows additionally show the resident's phone, required amount, paid amount, and debt (absolute value) columns
- AC-31: In debtors mode a summary shows the number of debtors and the total debt across the whole filtered scope, not just the current page
- AC-32: In debtors mode the list is sorted by debt amount descending
- AC-33: In debtors mode a CSV export is available and preserves the current building/academic year/status filters and the user's building scope
- AC-34: Access to the debtors list follows the accommodations index policy: admin/dormitory.admin/registrar see all, commandant only assigned buildings, registrar is read-only
- AC-35: In debtors mode the summary shows "Всего оплачено" — the sum of kept receipts of the filtered debtors — alongside the debtors count and "Общий долг"
- AC-36: The dashboard shows a "Всего оплачено" metric — the sum of kept receipts of all accommodations (any status) belonging to the active academic year within the user's accessible buildings; when there is no active academic year the metric is 0
- AC-37: The residents index shows "Всего оплатил" (green) and "Должен" (red when > 0) columns — aggregates over all kept accommodations of the resident (any year and status); residents without accommodations show 0,00; for a commandant the aggregates cover only accommodations in their assigned buildings

## UI/UX Notes

- `required_amount` field: number input with step 0.01, placed in the payment section of the accommodation form
- Receipts are created exclusively via the dedicated `ReceiptsController` (new/create/edit/update/destroy actions), not inline in the accommodation form
- Payment summary on show: `<div class="card">` with three info-items (required, paid, balance) using colored value display
- Receipts table: similar to documents table — date, amount, file link, small edit/delete buttons
- "Pay remaining" button: `btn btn-success`, links to `new_dormitory_accommodation_receipt_path(accommodation, amount: debt_amount)`
- Balance column in index: shown only in debtors mode as "Долг" (absolute value, red); the regular mode has no payment columns
- Residents index: "Всего оплатил" (green) and "Должен" (red when > 0) columns after "Курс", formatted like other amounts, 0,00 when the resident has no kept accommodations
- Empty state for receipts: "Нет квитанций" message
- "Только должники" checkbox placed in the existing index filter panel, auto-submitting on change like the filter selects
- Debtors summary: three cards above the table — "Должников" (count), "Всего оплачено" (green), and "Общий долг" (red)
- Debtors table keeps the standard columns and adds "Телефон" after the full name, plus "Сумма к оплате" and "Уплачено" before the balance column; the balance header becomes "Долг" and shows the absolute value in red
- "Экспорт CSV" button in the page header, shown only in debtors mode
- Empty state for debtors: "Нет должников" message

## Business Rules

- BR-1: `required_amount` is a non-negative decimal, default 0
- BR-2: Receipt amount must be strictly greater than 0
- BR-3: Receipt `paid_at` must be present (defaults to today in the form)
- BR-4: `total_paid` = sum(amount) of all kept receipts for the accommodation, computed at read time (no cached column); when the receipts association is preloaded, the sum is computed from the loaded records to avoid per-row SUM queries
- BR-5: `balance` = `total_paid` − `required_amount`. Positive = overpayment, negative = debt, zero = settled
- BR-6: Receipts use Discard::Model for soft-deletion — discarded receipts are excluded from `total_paid`, not displayed in lists, and cannot be restored via the UI
- BR-7: Receipts are not required for settlement or transfer — they can be added at any time while the accommodation is active via the dedicated ReceiptsController
- BR-8: Receipt file format: PDF, JPEG, or PNG. Maximum size: 10 MB (same as accommodation document files)
- BR-9: Receipt create/update/delete are recorded via Trackable (OutboxEvent event types: `dormitory.receipt.created`, `dormitory.receipt.updated`, `dormitory.receipt.destroyed`)
- BR-10: Dashboard payment metrics (total debt, debt by building) are scoped by the user's accessible buildings, matching the existing dashboard scoping rules (BR-2 through BR-12 from SPEC-DORM-07)
- BR-11: Balance display: green (`text-success`) when ≥ 0, red (`text-danger`) when < 0
- BR-12: "Pay remaining" button is shown only when the accommodation is active AND balance < 0. It pre-fills the receipt amount to `abs(balance)`
- BR-13: Receipt CRUD operations are only allowed while the parent accommodation is active or pending (status in ["active", "pending"])
- BR-14: Receipts are created exclusively via the dedicated `ReceiptsController`, nested under accommodations, or via resident registration (SPEC-DORM-12) — the accommodation model no longer uses `accepts_nested_attributes_for :receipts`
- BR-15: Receipt attachment file validation (format and size) mirrors the existing validation rules for accommodation documents
- BR-16: A registrar can create receipts for any kept accommodation (global, not building-scoped) but cannot edit, update, or delete receipts
- BR-17: A receipt created during resident registration (SPEC-DORM-12) stays attached if the pending accommodation is later rejected — it documents money actually received and is not discarded automatically
- BR-18: A debtor is an accommodation with status active and balance < 0 (total_paid < required_amount), consistent with the dashboard debt metrics (BR-10); pending, completed, cancelled, and discarded accommodations are excluded
- BR-19: Debtors mode intersects with the existing building, academic year, and status filters and with the user's policy scope
- BR-20: Debtors count and total debt are computed over the whole filtered scope, not the current page
- BR-21: Debtors CSV uses the same UTF-8 BOM and semicolon format as other exports; the "Долг" column contains the absolute value of the negative balance; the "Просрочено" column is "Да" when `planned_end_date < today`, otherwise "Нет"; the export is served only when the debtors filter is enabled — a CSV request without it returns 404
- BR-22: The debtors list uses a SQL subquery on kept receipts so that pagination and totals stay correct without a grouped relation; totals are computed on a relation without eager-loaded joins so receipts cannot multiply accommodation rows
- BR-23: "Всего оплачено" counts only kept receipts of debtors (active, non-discarded, balance < 0), respects the index filters and the user's building scope, and is computed with a single SQL aggregate without join duplication
- BR-24: The dashboard "Всего оплачено" metric sums kept receipts of all kept accommodations (any status) of the active academic year within the user's accessible buildings; accommodations of other academic years are excluded, and the metric is 0 when no academic year is active; it is computed with a single SQL aggregate without join duplication
- BR-25: The residents index aggregates are computed per resident across all their kept accommodations (any year and status): "Всего оплатил" = sum of kept receipts, "Должен" = sum of positive debts (required_amount − total_paid where > 0); discarded receipts and accommodations are excluded; both are computed with single grouped SQL aggregates without N+1 queries or join duplication; for a commandant the aggregates are scoped to their assigned buildings (matching AccommodationPolicy::Scope), while admin/dormitory.admin/registrar see the full history; for a user holding multiple roles, roles above commandant take precedence and the aggregates are not scoped; a commandant without assigned buildings sees 0,00 aggregates

## Behavior

### Background
Given academic year "2025/2026" is active
And admin user exists
And building "Building A" has room 101 (capacity 3, free, no gender restriction)
And resident "Ivan Petrov" exists (not settled, male)

### Rule: Create accommodation with required_amount (AC-1, AC-2, AC-3)

#### Scenario: Settle with required amount
Given admin is on the settlement form for Ivan
When admin fills in: room 101, start date today, planned end date +1 year,
  application number "APP-001", contract number "CNT-001",
  required_amount = 12000, and attaches application and contract files
And submits
Then the accommodation is created with status "active" and required_amount = 12000
And Ivan is settled in room 101
And a settlement event is logged

#### Scenario: Settle with required_amount zero succeeds
Given admin is on the settlement form for Ivan
When admin fills in all fields, required_amount = 0, and attaches required files
And submits
Then the accommodation is created with required_amount = 0

### Rule: Receipt management (BR-2, BR-3, BR-8, BR-13)

#### Scenario: Add receipt to active accommodation
Given Ivan is settled in room 101 (accommodation active, required_amount = 12000, no receipts)
When admin adds a receipt: amount = 5000, paid_at = today, file = receipt1.pdf
Then a receipt is created with amount = 5000
And accommodation total_paid = 5000, balance = -7000
And the receipt is shown in the receipts table on the accommodation show page
And a receipt.created event is logged

#### Scenario: Add second receipt
Given Ivan's accommodation has one receipt of 5000
When admin adds another receipt: amount = 7000, paid_at = today, file = receipt2.pdf
Then total_paid = 12000, balance = 0
And both receipts are shown

#### Scenario: Edit receipt
Given Ivan's accommodation has a receipt of 5000
When admin edits the receipt: amount = 6000
Then total_paid recalculates to 6000
And balance becomes -6000
And a receipt.updated event is logged

#### Scenario: Delete receipt (soft-delete)
Given Ivan's accommodation has receipts of 5000 and 7000
When admin deletes the 5000 receipt
Then the receipt is marked as discarded (not physically deleted)
And total_paid = 7000, balance = -5000
And the deleted receipt is no longer shown
And a receipt.destroyed event is logged

#### Scenario: Cannot add receipt to completed accommodation
Given Ivan's accommodation is completed
When admin tries to add a receipt
Then the "Add receipt" button is not shown

### Rule: Payment summary and indicators (BR-5, BR-11, BR-12)

#### Scenario: Payment summary with debt
Given Ivan's accommodation: required_amount = 12000, total_paid = 8000
When admin views the accommodation show page
Then a payment summary block shows:
  "Сумма к оплате: 12 000,00"
  "Уплачено: 8 000,00"
  "Остаток: −4 000,00" (colored red)
And "Оплатить остаток" button is shown with pre-filled amount = 4000

#### Scenario: Payment summary fully paid
Given Ivan's accommodation: required_amount = 12000, total_paid = 12000
When admin views the accommodation show page
Then balance = 0,00 (colored green)
And "Оплатить остаток" button is NOT shown

#### Scenario: Payment summary overpaid
Given Ivan's accommodation: required_amount = 12000, total_paid = 15000
When admin views the accommodation show page
Then balance = +3 000,00 (colored green)

### Rule: Receipt Policy access control (AC-23)

#### Scenario: Admin sees all receipts
Given receipts exist for accommodations in Building A and Building B
When admin accesses receipt actions (new/create/edit/update/destroy)
Then all operations are allowed (full access, matching Accommodation policy behavior)

#### Scenario: Commandant sees only receipts from assigned buildings
Given commandant "Dave" is assigned to Building A only
And receipts exist for accommodations in Building A and Building B
When Dave accesses receipt actions for a receipt in Building A
Then operations are allowed
When Dave accesses receipt actions for a receipt in Building B
Then access is denied

### Rule: Dashboard metrics (BR-10)

#### Scenario: Total debt metric
Given building A has 3 active accommodations: balance = -3000, -5000, +2000
When admin visits the dashboard
Then total debt metric = 8000 (sum of negative balances as absolute)
And "+2000" is excluded (not a debt)

#### Scenario: Debt by building
Given building A has debts 3000 and 2000; building B has debt 4000
When admin visits the dashboard
Then "Debt by building" table shows: Building A = 5000, Building B = 4000

#### Scenario: Total paid metric for the active year
Given building A has a debtor with paid amount 2000 and a fully paid accommodation with paid amount 5000
And building B has a debtor with paid amount 4000
When admin visits the dashboard
Then "Всего оплачено" metric = 11000 (all accommodations of the active year)
And the fully paid accommodation's 5000 IS included

#### Scenario: Accommodations of other academic years are excluded
Given building A has an active accommodation of the active year with paid amount 2000
And building A has an accommodation of a closed year with paid amount 5000
When admin visits the dashboard
Then "Всего оплачено" metric = 2000
But the closed year's 5000 is NOT included

#### Scenario: No active academic year
Given no academic year is active
When admin visits the dashboard
Then "Всего оплачено" metric = 0

### Rule: Residents index aggregates (AC-37, BR-25)

#### Scenario: Paid and debt across all accommodations
Given Ivan has a debtor accommodation with paid amount 8000 and required amount 12000
And Ivan has a completed accommodation of a previous year with paid amount 3000
When admin visits the residents index
Then Ivan's row shows "Всего оплатил" = 11 000,00
And "Должен" = 4 000,00

#### Scenario: Overpayments do not reduce debt
Given Ivan has a debtor accommodation with debt 4000
And Ivan has another accommodation overpaid by 2000
When admin visits the residents index
Then Ivan's row shows "Должен" = 4 000,00

#### Scenario: Resident without accommodations
Given Ivan has no kept accommodations
When admin visits the residents index
Then Ivan's row shows "Всего оплатил" = 0,00 and "Должен" = 0,00

#### Scenario: Commandant scope
Given commandant Dave is assigned to building A only
And Ivan's accommodations include a debtor in building A (paid 8000, debt 4000)
And Ivan's completed accommodation in building B has paid amount 5000
When Dave visits the residents index
Then Ivan's row shows "Всего оплатил" = 8 000,00 and "Должен" = 4 000,00
But the building B paid amount of 5000 is NOT included

### Rule: Exports (AC-26, AC-27)

#### Scenario: Settled residents with payment columns
Given Ivan's accommodation has required_amount = 12000 and one receipt of 5000
When admin downloads the settled residents CSV
Then Ivan's row contains: "12000.00", "5000.00", "-7000.00"

#### Scenario: History with payment columns
Given Ivan's completed accommodation had required_amount = 12000 and total paid = 12000
When admin downloads the history CSV
Then Ivan's row contains: "12000.00", "12000.00", "0.00"

### Rule: Debtors filter (AC-29, AC-30, BR-18, BR-19)

#### Scenario: Only active underpaid accommodations are shown
Given Ivan's active accommodation has required_amount = 12000 and total paid = 8000
And Petr's active accommodation has required_amount = 12000 and total paid = 12000
And Anna has a pending accommodation with required_amount = 12000 and total paid = 5000
And Olga has a completed accommodation with required_amount = 12000 and total paid = 0
When admin opens the accommodations index and enables "Только должники"
Then Ivan's accommodation is shown with debt 4000
But Petr's, Anna's, and Olga's accommodations are NOT shown

#### Scenario: Debtor row shows contact and payment details
Given Ivan's active accommodation has required_amount = 12000, total paid = 8000, and phone +7 900 000-00-00
When admin views the debtors list
Then the row shows phone "+7 900 000-00-00", "Сумма к оплате" 12 000,00, "Уплачено" 8 000,00, and "Долг" 4 000,00

#### Scenario: Overdue debtor is marked
Given Ivan's active accommodation has balance -4000 and planned_end_date in the past
When admin views the debtors list
Then the row shows the overdue indicator

### Rule: Debtors totals and ordering (AC-31, AC-32, BR-20)

#### Scenario: Totals cover the whole filtered scope
Given building A has debtors with debts 3000 and 5000
And building B has a debtor with debt 4000
When admin enables "Только должники" with building filter "Building A"
Then the debtors count is 2
And the total debt is 8000
And the first row is the debtor with debt 5000

#### Scenario: Total paid covers the whole filtered scope
Given building A has debtors with paid amounts 2000 and 5000
And building B has a debtor with paid amount 4000
When admin enables "Только должники" with building filter "Building A"
Then "Всего оплачено" shows 7000
But the building B paid amount is NOT included

#### Scenario: Total paid excludes fully paid accommodations
Given Ivan is a debtor with paid amount 2000
And Petr's active accommodation is fully paid (paid amount 5000)
When admin enables "Только должники"
Then "Всего оплачено" shows 2000
But Petr's paid amount is NOT included

#### Scenario: Commandant scope
Given commandant "Dave" is assigned to building A only
And building A has a debtor with debt 3000
And building B has a debtor with debt 4000
When Dave enables "Только должники"
Then only the building A debtor is shown
And the total debt is 3000

### Rule: Debtors CSV (AC-33, BR-21)

#### Scenario: Export debtors with filters
Given building A has a debtor with debt 4000 and phone +7 900 000-00-00
And building B has a debtor with debt 3000
When admin enables "Только должники" with building filter "Building A" and downloads the CSV
Then the CSV has a UTF-8 BOM and semicolon separator
And the CSV contains the header "Долг"
And the CSV contains the building A debtor with "4000.00" and phone "+7 900 000-00-00"
But the CSV does NOT contain the building B debtor

#### Scenario: Overdue flag in CSV
Given a debtor has planned_end_date in the past
When admin downloads the debtors CSV
Then the debtor's row contains "Да" in the "Просрочено" column

#### Scenario: Registrar can download the debtors CSV
Given registrar is signed in
When registrar downloads the debtors CSV
Then the CSV is returned successfully
