# SPEC-DORM-09: Payment Receipts & Amount Tracking

Adds financial payment tracking to dormitory accommodations: a required amount field on the accommodation, individual payment receipts with amounts and file attachments, payment summary with balance calculation, and payment status visualization across the UI, dashboard, and CSV exports.

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
- AC-4: Admin, dormitory administrator, and commandant can add a receipt to an active accommodation: amount (> 0), paid_at (default today), payment file (PDF/JPEG/PNG, ≤10 MB), optional comment
- AC-5: Admin, dormitory administrator, and commandant can edit a receipt (change amount, paid_at, comment, or re-upload file)
- AC-6: File is required when creating a receipt; on edit, existing file is kept if no new file is uploaded
- AC-7: Receipt delete is a soft-delete (Discard) — the record is marked discarded, not physically removed
- AC-8: Deleted receipts are excluded from `total_paid`, not shown in the list, and cannot be restored via UI
- AC-9: Receipts can only be created, edited, or deleted while the parent accommodation is active

### Settlement with receipt
- AC-10: Receipts are created independently via the dedicated `ReceiptsController` (nested under accommodations), not inline in the settlement form — receipts are not required for settlement
- AC-11: Receipts can be added to an active accommodation at any time, not only during settlement

### Payment summary
- AC-13: Accommodation show page displays a payment summary block: required amount, total paid, balance
- AC-14: `total_paid` = sum of all kept receipts' amounts for the accommodation
- AC-15: `balance` = `total_paid` − `required_amount` (positive = overpayment, negative = debt)
- AC-16: Balance display is colored: green if ≥ 0, red if < 0
- AC-17: Accommodation index table includes a balance column with color indicator
- AC-18: Resident history table (on resident show) includes `required_amount`, `total_paid`, and `balance` columns

### Receipt list on accommodation show
- AC-19: Accommodation show displays a table of all kept receipts: paid_at, amount, file link, comment, edit/delete actions
- AC-20: "Add receipt" button is shown when the accommodation is active
- AC-21: "Pay remaining" quick-action button is shown when accommodation is active AND balance < 0 — clicking it opens the receipt form with amount pre-filled to the remaining debt

### Audit logging
- AC-22: Receipt creation, update, and deletion are recorded via Trackable (OutboxEvent), same as accommodation events

### Access control
- AC-23: Receipts follow the same authorization model as Accommodation: admin/dormitory.admin have full access; commandants can only access receipts of accommodations in their assigned buildings

### Dashboard
- AC-24: Dashboard shows a "Total debt" metric card (sum of negative balances across all accessible active accommodations, shown as absolute value)
- AC-25: Dashboard shows a "Debt by building" breakdown (grouped by building, showing building name and total debt)

### Exports
- AC-26: Settled residents export (SPEC-DORM-06 AC-7) gains three additional columns: "Сумма к оплате", "Уплачено", "Остаток"
- AC-27: Accommodation history export (SPEC-DORM-06 AC-16) gains three additional columns: "Сумма к оплате", "Уплачено", "Остаток"

### N+1 prevention
- AC-28: When loading accommodations with receipts, N+1 queries are avoided via `includes(:receipts)`

## UI/UX Notes

- `required_amount` field: number input with step 0.01, placed in the payment section of the accommodation form
- Receipts are created exclusively via the dedicated `ReceiptsController` (new/create/edit/update/destroy actions), not inline in the accommodation form
- Payment summary on show: `<div class="card">` with three info-items (required, paid, balance) using colored value display
- Receipts table: similar to documents table — date, amount, file link, small edit/delete buttons
- "Pay remaining" button: `btn btn-success`, links to `new_dormitory_accommodation_receipt_path(accommodation, amount: debt_amount)`
- Balance column in index: inline span with colored badge (green/red)
- Empty state for receipts: "Нет квитанций" message

## Business Rules

- BR-1: `required_amount` is a non-negative decimal, default 0
- BR-2: Receipt amount must be strictly greater than 0
- BR-3: Receipt `paid_at` must be present (defaults to today in the form)
- BR-4: `total_paid` = sum(amount) of all kept receipts for the accommodation, computed at read time (no cached column)
- BR-5: `balance` = `total_paid` − `required_amount`. Positive = overpayment, negative = debt, zero = settled
- BR-6: Receipts use Discard::Model for soft-deletion — discarded receipts are excluded from `total_paid`, not displayed in lists, and cannot be restored via the UI
- BR-7: Receipts are not required for settlement or transfer — they can be added at any time while the accommodation is active via the dedicated ReceiptsController
- BR-8: Receipt file format: PDF, JPEG, or PNG. Maximum size: 10 MB (same as accommodation document files)
- BR-9: Receipt create/update/delete are recorded via Trackable (OutboxEvent event types: `dormitory.receipt.created`, `dormitory.receipt.updated`, `dormitory.receipt.destroyed`)
- BR-10: Dashboard payment metrics (total debt, debt by building) are scoped by the user's accessible buildings, matching the existing dashboard scoping rules (BR-2 through BR-12 from SPEC-DORM-07)
- BR-11: Balance display: green (`text-success`) when ≥ 0, red (`text-danger`) when < 0
- BR-12: "Pay remaining" button is shown only when the accommodation is active AND balance < 0. It pre-fills the receipt amount to `abs(balance)`
- BR-13: Receipt CRUD operations are only allowed while the parent accommodation is active (status = "active")
- BR-14: Receipts are created exclusively via the dedicated `ReceiptsController`, nested under accommodations — the accommodation model no longer uses `accepts_nested_attributes_for :receipts`
- BR-15: Receipt attachment file validation (format and size) mirrors the existing validation rules for accommodation documents

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

### Rule: Exports (AC-26, AC-27)

#### Scenario: Settled residents with payment columns
Given Ivan's accommodation has required_amount = 12000 and one receipt of 5000
When admin downloads the settled residents CSV
Then Ivan's row contains: "12000.00", "5000.00", "-7000.00"

#### Scenario: History with payment columns
Given Ivan's completed accommodation had required_amount = 12000 and total paid = 12000
When admin downloads the history CSV
Then Ivan's row contains: "12000.00", "12000.00", "0.00"
