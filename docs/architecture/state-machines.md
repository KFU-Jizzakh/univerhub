# State Machines

AASM state machines and status lifecycles of key domain records. All transitions are
enforced in code (`app/models`) via explicit `do_*!` event methods; every state change
is journaled to `outbox_events`.

## Accommodation (`Dormitory::Accommodation`)

AASM, column `status`. The machine's initial state is `active` (the classic
`do_settle!` path); `pending` is set explicitly by `do_register!` when a place is
reserved during resident registration.

```mermaid
stateDiagram-v2
    [*] --> active : do_settle! (classic settlement)
    [*] --> pending : do_register! (registration, reserves bed)
    pending --> active : confirm! / do_confirm!
    active --> completed : complete! / do_transfer!, do_evict!
    pending --> cancelled : cancel! / do_reject!, do_cancel_without_occupancy!
    active --> cancelled : cancel!
    completed --> [*]
    cancelled --> [*]
```

Notes:
- `do_transfer!` completes the old record with reason `transfer` and creates a new `active` accommodation, moving all receipts to it.
- `do_evict!` completes the record (reason required, `other` requires a comment), sets the resident `evicted`.
- `do_discard!` (soft delete) reconciles first: an `active` record runs the full eviction equivalent, a `pending` record the rejection equivalent.
- `do_update_pending!` keeps the record `pending` but may release the old room and reserve a new one.

## Room occupancy (`Dormitory::Room`)

AASM, column `status`. Guards compare `current_occupancy` with `capacity`:
`partial_occupation?` (0 < occupancy < capacity) and `full_occupation?` (occupancy ≥ capacity).
Transitions are triggered by accommodation operations, never by hand.

```mermaid
stateDiagram-v2
    [*] --> free
    free --> partially_occupied : occupy [partial_occupation?]
    free --> fully_occupied : occupy [full_occupation?]
    partially_occupied --> fully_occupied : occupy_more [full_occupation?]
    partially_occupied --> partially_occupied : occupy_more [partial_occupation?]
    fully_occupied --> overcrowded : force_occupy (force settle/transfer)
    overcrowded --> overcrowded : force_occupy
    fully_occupied --> partially_occupied : evict_partial [partial_occupation?]
    overcrowded --> fully_occupied : evict_partial [full_occupation?]
    overcrowded --> partially_occupied : evict_partial [partial_occupation?]
    partially_occupied --> free : evict_all
    fully_occupied --> free : evict_all
    overcrowded --> free : evict_all
    overcrowded --> fully_occupied : normalize [full_occupation?]
```

## Report (`Reporting::Report`)

AASM, column `status`. Guarded transitions protect the workflow contract;
notifications are sent to the reporter/reviewer on assignment and submission.

```mermaid
stateDiagram-v2
    [*] --> draft
    draft --> new : publish [has_items?]
    new --> in_progress : take_in_progress (assigned reporter)
    reopened --> in_progress : take_in_progress
    in_progress --> in_review : submit [all_attachments_present?]
    in_review --> accepted : accept [all_items_graded?]
    in_review --> rejected : reject (reason required)
    rejected --> reopened : reopen (assigned reporter)
    accepted --> [*]
```

## Academic year (`Dormitory::AcademicYear`)

AASM, column `status`. Business invariants: only one `active` year at a time;
`do_close!` is denied while active accommodations reference the year.

```mermaid
stateDiagram-v2
    [*] --> pending
    pending --> active : activate (no other active year)
    active --> closed : close (no active accommodations)
    pending --> [*] : do_discard! (pending only)
```

## Report template (`Reporting::ReportTemplate`) — status enum, not AASM

```mermaid
stateDiagram-v2
    [*] --> draft : create
    draft --> published : publish
    published --> archived : archive
```

## Violation (`Dormitory::Violation`) — status enum, not AASM

```mermaid
stateDiagram-v2
    [*] --> open : create (occurred_at cannot be in the future)
    open --> reviewed : set review date + result (required)
    reviewed --> closed : close
```

## Batch operation status (`Dormitory::BatchOperation`) — plain column

`pending` → `completed` (all residents evicted) or `partial` (some failed; per-resident
errors are stored in `dormitory_batch_operation_errors`).
