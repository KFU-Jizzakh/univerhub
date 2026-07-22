# SPEC-DORM-06: CSV Exports

Four types of CSV data exports with filters and role-based access control: settled residents list, free slots, accommodation history, and occupancy statistics. Exports use UTF-8 encoding with a BOM prefix and semicolon delimiter for Excel compatibility (Russian locale requirement).

Depends on: SPEC-CORE-02, SPEC-DORM-02, SPEC-DORM-03, SPEC-DORM-04, SPEC-DORM-09

Status: IMPLEMENTED

## Acceptance Criteria

- AC-1: Admin, dormitory administrator, and commandant can access all 4 export pages
- AC-2: Each export has a preview page with filters and a download button
- AC-3: CSV download uses UTF-8 with a BOM prefix and semicolon as the separator
- AC-4: The filename includes the export type and current date (e.g., `settled_residents_2026-05-26.csv`)

### Settled Residents Export
- AC-5: Lists all settled and temporarily absent residents with their current room
- AC-6: Filters: building, floor, room, academic year
- AC-7: Columns: full name, gender, date of birth, student ticket, phone, email, building, floor, room, settlement date, application number, contract number, required amount, total paid, balance (SPEC-DORM-09 AC-25)
- AC-8: Ordered by: building name → floor → room number → last name → first name
- AC-9: Residents without an active accommodation are skipped

### Free Slots Export
- AC-10: Lists all rooms (except those under repair) with free slot counts
- AC-11: Filter: building
- AC-12: Columns: building, floor, room, capacity, occupied, free slots, gender restriction, status
- AC-13: Ordered by: building name → floor → room number

### Accommodation History Export
- AC-14: Lists all accommodations with optional filters
- AC-15: Filters: building, status, date range (start date from/to), academic year
- AC-16: Columns: resident name, student ticket, building, floor, room, application number, contract number, start date, end date (or "—" if ongoing), duration in days, status, eviction reason, comment, required amount, total paid, balance (SPEC-DORM-09 AC-26)
- AC-17: Ordered by: building name → floor → room number → start date

### Occupancy Statistics Export
- AC-18: Aggregated stats per building floor, with subtotals per building and a grand total
- AC-19: Columns: building, floor, total rooms, free, partially occupied, fully occupied, overcrowded, capacity, occupied, occupancy percentage
- AC-20: Subtotal row per building (building name, "—" for floor)
- AC-21: Grand total row if multiple buildings ("ИТОГО", "—" for floor)
- AC-22: Occupancy percentage rounded to 1 decimal place

## UI/UX Notes

- Export pages: filter form + preview table (first 50 rows) + "Download CSV" button
- Filter defaults to "all" / no filter
- Buttons accessible from: residents index, rooms index, accommodations index, dashboard
- Preview tables mirror the CSV column structure

## Business Rules

- BR-1: A UTF-8 BOM (byte order mark) is prepended to the first column header for Russian Excel compatibility
- BR-2: The CSV separator is a semicolon (not a comma)
- BR-3: All data queries respect the user's role-based access (commandants see only their buildings' data)
- BR-4: Only non-deleted records are exported
- BR-5: Academic year filter on accommodations matches records whose start date falls within the year's date range
- BR-6: Gender is displayed as a localized string
- BR-7: Room status is displayed as a localized string
- BR-8: Eviction reason is displayed as a localized string
- BR-9: Occupancy percentage = (occupied / capacity) × 100
- BR-10: Data is processed in batches to avoid memory issues with large datasets
- BR-11: Each filter (building, floor, room, academic year, date range) is applied independently
- BR-12: Payment amount columns (required amount, total paid, balance) are formatted with 2 decimal places and use period as decimal separator

## Behavior

### Background
Given admin user exists
And building "Building A" has room 101 (capacity 3, occupancy 2) and room 102 (capacity 2, occupancy 0)
And resident "Ivan Petrov" is settled in room 101 (active accommodation)

### Rule: Settled Residents Export

#### Scenario: Export with UTF-8 BOM and semicolons
When admin downloads the settled residents CSV
Then the file starts with a BOM character
And the separator is ";"
And the header row uses Russian column names
And Ivan's row contains his full name, gender, and room 101 info

#### Scenario: Resident without active accommodation is skipped
Given resident "Maria" is evicted (no active accommodation)
When admin downloads the settled residents CSV
Then Maria is not in the export

#### Scenario: Filter by building
When admin filters by Building A
Then only residents of Building A are exported

#### Scenario: Filter by academic year
When admin filters by year "2025/2026"
Then only residents with an active accommodation in that year are exported

### Rule: Free Slots Export

#### Scenario: Export free slots
When admin downloads the free slots CSV
Then room 101 shows: Building A, 1, 101, 3, 2, 1, (gender), "Partially occupied"
And room 102 shows: Building A, 1, 102, 2, 0, 2, ..., "Free"

### Rule: Accommodation History Export

#### Scenario: Export with date range filter
When admin filters accommodation history by date from 2025-01-01 and date to 2025-12-31
Then only accommodations with a start date within that range are exported

#### Scenario: Export with status filter
When admin filters by status "completed"
Then only completed and cancelled accommodations are exported

### Rule: Occupancy Statistics Export

#### Scenario: Export with subtotals
When admin downloads the occupancy stats CSV
Then floor-level rows are present
And subtotal rows per building exist ("Итого Building A;—;...")
And a grand total row exists if there are multiple buildings ("ИТОГО;—;...")
And the occupancy percentage is correct (e.g., 40.0 for a building with 2 of 5 occupied)

#### Scenario: Single building — no grand total
Given only 1 building exists
When admin exports occupancy stats
Then the grand total row is not included

#### Scenario: Settled residents with payment columns
Given Ivan's accommodation has required_amount = 12000 and one receipt of 5000
When admin downloads the settled residents CSV
Then Ivan's row contains: "12000.00", "5000.00", "-7000.00"

#### Scenario: History with payment columns
Given Ivan's completed accommodation had required_amount = 12000 and total paid = 12000
When admin downloads the history CSV
Then Ivan's row contains: "12000.00", "12000.00", "0.00"
