# Domain Model (ERD)

Entity relationships grouped by module. All records use soft delete (`Discard`, column
`discarded_at`); `kept` scopes filter it out everywhere. Key attributes are illustrative,
not exhaustive — see `db/schema.rb` for the full definition.

## Core

```mermaid
erDiagram
    USERS {
        string email
        string password_digest
        datetime deactivated_at
        datetime deleted_at
    }
    USER_ROLES {
        string role_name
    }
    SESSIONS {
        string ip_address
        string user_agent
    }
    USER_PROFILES {
        string last_name
        string first_name
    }
    NOTIFICATIONS {
        string action
        boolean read
        datetime read_at
    }
    OUTBOX_EVENTS {
        bigint actor_id
        string action
        string record_type
        bigint record_id
        jsonb payload
    }
    COMMANDANT_BUILDINGS {
        datetime deactivated_at
    }
    USERS ||--o{ USER_ROLES : "has many (unique role per user)"
    USERS ||--o{ SESSIONS : "has many"
    USERS ||--|| USER_PROFILES : "has one"
    USERS ||--o{ NOTIFICATIONS : "receives (recipient_id)"
    USERS ||--o{ OUTBOX_EVENTS : "acts as (actor, optional)"
    USERS ||--o{ COMMANDANT_BUILDINGS : "commandant of"
    NOTIFICATIONS }o--|| USERS : "recipient"
    NOTIFICATIONS }o--o| NOTIFIABLE : "polymorphic notifiable"
    OUTBOX_EVENTS }o--o| RECORD : "polymorphic record"
    COMMANDANT_BUILDINGS }o--|| DORMITORY_BUILDINGS : "building"
```

`NOTIFIABLE` and `RECORD` are polymorphic targets (any model), shown for completeness.

## Dormitory

```mermaid
erDiagram
    DORMITORY_BUILDINGS {
        string name
        string address
        integer floors_count
    }
    DORMITORY_ROOMS {
        integer floor
        string number
        integer capacity
        integer current_occupancy
        string status
        string gender
        integer_array allowed_courses
    }
    DORMITORY_RESIDENTS {
        string last_name
        string first_name
        string middle_name
        string ticket
        string gender
        integer course
        string status
        bigint current_room_id
    }
    DORMITORY_ACADEMIC_YEARS {
        string name
        date start_date
        date end_date
        string status
    }
    DORMITORY_ACCOMMODATIONS {
        string status
        string bed_label
        integer course
        decimal required_amount
        string application_number
        string contract_number
        date start_date
        date planned_end_date
        date actual_end_date
        string eviction_reason
        bigint renewal_source_id
    }
    DORMITORY_RECEIPTS {
        decimal amount
        date paid_at
    }
    DORMITORY_VIOLATIONS {
        integer violation_type
        string place
        integer status
        date occurred_at
        date reviewed_at
    }
    DORMITORY_BATCH_OPERATIONS {
        string operation_type
        string status
        integer total_count
        integer success_count
        integer error_count
    }
    DORMITORY_BATCH_OPERATION_ERRORS {
        string error_text
    }
    DORMITORY_BUILDINGS ||--o{ DORMITORY_ROOMS : "has many"
    DORMITORY_ROOMS ||--o{ DORMITORY_ACCOMMODATIONS : "history of"
    DORMITORY_ROOMS ||--o{ DORMITORY_RESIDENTS : "current residents (settled)"
    DORMITORY_RESIDENTS ||--o{ DORMITORY_ACCOMMODATIONS : "has many"
    DORMITORY_RESIDENTS }o--o| DORMITORY_ROOMS : "current_room (optional)"
    DORMITORY_ACADEMIC_YEARS ||--o{ DORMITORY_ACCOMMODATIONS : "groups"
    DORMITORY_ACCOMMODATIONS ||--o{ DORMITORY_RECEIPTS : "payments"
    DORMITORY_ACCOMMODATIONS }o--o| DORMITORY_ACCOMMODATIONS : "renewal_source"
    DORMITORY_RESIDENTS ||--o{ DORMITORY_VIOLATIONS : "has many"
    DORMITORY_ACADEMIC_YEARS ||--o{ DORMITORY_BATCH_OPERATIONS : "year-end close"
    DORMITORY_BUILDINGS ||--o{ DORMITORY_BATCH_OPERATIONS : "scoped to"
    USERS ||--o{ DORMITORY_BATCH_OPERATIONS : "performed_by"
    DORMITORY_BATCH_OPERATIONS ||--o{ DORMITORY_BATCH_OPERATION_ERRORS : "per-resident errors"
    DORMITORY_BATCH_OPERATION_ERRORS }o--o| DORMITORY_RESIDENTS : "resident"
    DORMITORY_BATCH_OPERATION_ERRORS }o--o| DORMITORY_ACCOMMODATIONS : "accommodation"
```

Attachments (Active Storage, one per record): resident `photo` + prepared
`application_file`/`contract_file`; accommodation `application_file`/`contract_file`;
receipt `attachment`; violation `protocol_file`.

## Reporting

```mermaid
erDiagram
    REPORTING_REPORT_TEMPLATES {
        string name
        string description
        integer status
        string pdf_template
    }
    REPORTING_REPORT_TEMPLATE_ITEMS {
        string name
        string description
        integer position
        integer max_grade
        boolean attachments_required
    }
    REPORTING_REPORTS {
        string name
        string status
        date deadline
        string rejection_reason
        decimal total_grade
    }
    REPORTING_REPORT_ITEMS {
        text content
        decimal grade
        bigint graded_by_id
    }
    REPORTING_REPORT_COMMENTS {
        text body
    }
    REPORTING_REPORT_TEMPLATES ||--o{ REPORTING_REPORT_TEMPLATE_ITEMS : "ordered items"
    REPORTING_REPORT_TEMPLATES ||--o{ REPORTING_REPORTS : "created from"
    USERS ||--o{ REPORTING_REPORTS : "creator"
    USERS }o--o{ REPORTING_REPORTS : "reporter (assigned)"
    USERS }o--o{ REPORTING_REPORTS : "reviewer (assigned)"
    REPORTING_REPORTS ||--o{ REPORTING_REPORT_ITEMS : "items (copied from template)"
    REPORTING_REPORTS ||--o{ REPORTING_REPORT_COMMENTS : "discussion"
    USERS ||--o{ REPORTING_REPORT_COMMENTS : "author"
```

`REPORTING_REPORTS.pdf_file` is an Active Storage attachment holding the cached
Typst-generated PDF (see [dynamic view](dynamic-view.md)).
