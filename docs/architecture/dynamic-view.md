# Dynamic View — Sequence Diagrams

Runtime interactions for the concurrency-critical flows and PDF generation.
The common pattern for settlement operations: **lock → reload → re-validate → mutate**,
so stale reads can never bypass room capacity and gender rules.

## Confirm pending accommodation (`do_confirm!`)

Triggered by an admin or registrar after resident registration reserved a place.

```mermaid
sequenceDiagram
    actor U as Admin / Registrar
    participant RC as AccommodationsController
    participant Acc as Dormitory::Accommodation
    participant Room as Dormitory::Room
    participant Res as Dormitory::Resident
    participant DB as PostgreSQL

    U->>RC: POST /accommodations/:id/confirm
    RC->>Acc: do_confirm!
    Acc->>DB: BEGIN; track_event journal record
    Acc->>Room: with_lock (SELECT … FOR UPDATE)
    Acc->>Res: lock_preserving_attachment_changes!
    Acc->>Acc: reload (fresh state under lock)
    Acc->>Acc: validate_pending! (still pending?)
    alt occupancy > capacity and not force
        Acc-->>RC: RecordInvalid (room full)
        Acc->>DB: ROLLBACK
    else invariants hold
        Acc->>Acc: confirm! (pending → active)
        Acc->>Res: update!(status: settled, current_room: room)
        Acc->>DB: COMMIT + "accommodation.confirmed" event
        Acc-->>RC: accommodation
        RC-->>U: redirect, success notice
    end
```

## Transfer between rooms (`do_transfer!`)

Both rooms are locked **in sorted id order** to avoid deadlocks between concurrent
transfers touching the same pair of rooms.

```mermaid
sequenceDiagram
    actor U as Admin / Commandant
    participant RC as AccommodationsController
    participant Old as Dormitory::Accommodation
    participant New as Dormitory::Accommodation
    participant Room as Dormitory::Room
    participant Res as Dormitory::Resident
    participant DB as PostgreSQL

    U->>RC: PATCH /accommodations/:id/transfer
    RC->>Old: do_transfer!(new_acc)
    Old->>Old: validate_transfer_preconditions!
    Old->>Room: lock old_room.id, new_room.id (sorted)
    Old->>Room: reload both
    Old->>Old: re-validate destination (capacity, gender, course)
    Old->>Old: complete! (eviction_reason = transfer, actual_end_date = today)
    Old->>Room: old_room occupancy −1, status recalculated
    Old->>New: resident, inherited required_amount, assign_bed!, save!
    Old->>DB: receipts UPDATE ALL → new accommodation (incl. discarded)
    Old->>DB: events "receipts.transferred", "accommodation.created (via transfer)"
    Old->>Room: new_room occupancy +1, status transition
    Old->>Res: update!(status: settled, current_room: new_room)
    Old->>DB: COMMIT + "accommodation.transferred" event
    Old-->>RC: old accommodation
    RC-->>U: redirect to the new accommodation
```

## PDF generation (`Reporting::PdfGenerator`)

Synchronous, in-request; the compiled PDF is cached as an Active Storage blob and
invalidated by comparing a `cache_key` derived from the report data.

```mermaid
sequenceDiagram
    actor U as User
    participant RC as ReportsController
    participant Gen as Reporting::PdfGenerator
    participant St as Active Storage
    participant Ty as Typst CLI

    U->>RC: GET /reports/:id/pdf
    RC->>Gen: call
    alt cache hit (blob.cache_key == report.pdf_cache_key, not forced)
        Gen->>St: read cached pdf_file
        Gen-->>RC: blob
    else cache miss or force
        Gen->>Gen: resolve template (template design or generic.typ.erb)
        Gen->>Gen: render ERB → input.typ
        Gen->>Ty: compile input.typ → output.pdf
        Ty-->>Gen: PDF bytes
        Gen->>St: purge old blob, attach new (filename from report name)
        Gen->>St: blob.metadata.cache_key = report.pdf_cache_key
        Gen-->>RC: blob
    end
    RC-->>U: inline application/pdf
    Note over Ty: on compile failure the error is logged,<br/>controller shows an alert
```

## Related reading

- State transitions: [state-machines.md](state-machines.md)
- Use cases: [use-cases.md](use-cases.md)
