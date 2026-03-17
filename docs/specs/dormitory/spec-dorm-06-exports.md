# SPEC-DORM-06: CSV Exports

Four types of CSV data exports with filters and Pundit scoping: settled residents list, free slots, accommodation history, and occupancy statistics. UTF-8 BOM with semicolon delimiter for Excel compatibility.

Depends on: SPEC-CORE-02, SPEC-DORM-02, SPEC-DORM-03, SPEC-DORM-04

Status: IMPLEMENTED

## Acceptance Criteria

- AC-1: Admin/dormitory.admin/commandant can access all 4 export pages
- AC-2: Each export has an HTML preview page with filters and a download button
- AC-3: CSV download uses UTF-8 BOM and semicolon separator
- AC-4: Filename includes export type and current date (e.g., `settled_residents_2026-05-26.csv`)

### Settled Residents Export
- AC-5: Lists all settled and temporarily_absent residents with their current room
- AC-6: Filters: building_id, floor, room_id, academic_year_id
- AC-7: Columns: full name, gender, DOB, student ticket, phone, email, building, floor, room, settlement date, app#, contract#
- AC-8: Ordered by: building name → floor → room number → last_name → first_name
- AC-9: Skipped if resident has no active accommodation (edge case)

### Free Slots Export
- AC-10: Lists all rooms (except under_repair) with free slot counts
- AC-11: Filters: building_id
- AC-12: Columns: building, floor, room, capacity, occupied, free slots, gender restriction, status
- AC-13: Ordered by: building name → floor → room number

### Accommodation History Export
- AC-14: Lists all accommodations with optional filters
- AC-15: Filters: building_id, status, date_range (start_date from/to), academic_year_id
- AC-16: Columns: resident name, student ticket, building, floor, room, app#, contract#, start date, end date (or "—"), duration days, status, eviction reason, comment
- AC-17: Ordered by: building name → floor → room number → start_date

### Occupancy Statistics Export
- AC-18: Aggregated stats per building floor with subtotals per building and grand total
- AC-19: Columns: building, floor, total rooms, free, partially occupied, fully occupied, overcrowded, capacity, occupied, occupancy %
- AC-20: Subtotal row per building (building name, "—") 
- AC-21: Grand total row if multiple buildings ("ИТОГО", "—")
- AC-22: Occupancy % rounded to 1 decimal place

## UI/UX Notes

- Export pages: filter form + preview table (first 50 rows) + "Download CSV" button
- Filter defaults to all/no filter
- Buttons accessible from: residents#index, rooms#index, accommodations#index, dashboard
- Preview tables mirror CSV column structure

## Business Rules

- BR-1: UTF-8 BOM (`\uFEFF`) prepended to first column header for Russian Excel compatibility
- BR-2: CSV delimiter: `;` (semicolons)
- BR-3: Pundit policy_scope applied to all data queries
- BR-4: Only kept (non-discarded) records are exported
- BR-5: Academic year filter on accommodations: `start_date BETWEEN year.start_date AND year.end_date`
- BR-6: Gender displayed as localized string (I18n)
- BR-7: Room status displayed as localized string (I18n)
- BR-8: Eviction reason displayed as localized string (I18n)
- BR-9: Occupancy % = (occupied / capacity) * 100
- BR-10: `find_each` used for batch processing to avoid memory issues
- BR-11: Private class methods for filter application (building, floor, room, academic_year, date range)

## Behavior

### Background
Given admin user exists
And building "Building A" has room 101 (capacity 3, occupancy 2) and room 102 (capacity 2, occupancy 0)
And resident "Ivan Petrov" is settled in room 101 (active accommodation)

### Rule: Settled Residents Export (BR-4, BR-5)

#### Scenario: Export with UTF-8 BOM and semicolons
When admin downloads settled residents CSV
Then file starts with BOM character
And delimiter is `;`
And header row: `ФИО;Пол;Дата рождения;№ студ. билета;...`
And Ivan's row contains his full name, gender, room 101 info

#### Scenario: Resident without active accommodation is skipped
Given resident "Maria" is evicted (no active accommodation)
When admin downloads settled residents CSV
Then Maria is not in the export

#### Scenario: Filter by building
When admin filters by Building A
Then only residents of Building A are exported

#### Scenario: Filter by academic year
When admin filters by year "2025/2026"
Then only residents with active accommodation in that year are exported

### Rule: Free Slots Export (BR-6, BR-7)

#### Scenario: Export free slots
When admin downloads free slots CSV
Then room 101 shows: Building A, 1, 101, 3, 2, 1, male/female/—, "Частично занята"
And room 102 shows: Building A, 1, 102, 2, 0, 2, ..., "Свободна"

### Rule: Accommodation History Export (BR-8)

#### Scenario: Export with date range filter
When admin filters accommodation history by date_from=2025-01-01 and date_to=2025-12-31
Then only accommodations with start_date within range are exported

#### Scenario: Export with status filter
When admin filters by status=completed
Then only completed/cancelled accommodations are exported

### Rule: Occupancy Statistics Export (BR-9)

#### Scenario: Export with subtotals
When admin downloads occupancy stats CSV
Then floor-level rows are present
And subtotal rows per building exist ("Итого Building A;—;...")
And grand total row exists if multiple buildings ("ИТОГО;—;...")
And occupancy % is correct (e.g., 40.0 for building with 2/5 occupied)

#### Scenario: Single building — no grand total
Given only 1 building exists
When admin exports occupancy stats
Then grand total row is not included
