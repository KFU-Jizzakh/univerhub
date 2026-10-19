# Roles Matrix

Role-based access control in UniverHub. Roles are stored as strings on `user_roles`
(`UserRole::NAMES`) and enforced exclusively through Pundit policies (`app/policies`).

## Roles

| Role | Module | Purpose |
|---|---|---|
| `admin` | Global | Super-admin, full access to everything |
| `supervisor` | Global | Read-only oversight: sees all reports and the activity feed |
| `reporting.admin` | Reporting | Module admin, manages reporting users and all reporting data |
| `reporting.manager` | Reporting | Creates report templates and reports, assigns performers |
| `reporting.reporter` | Reporting | Fills in and submits assigned reports |
| `reporting.reviewer` | Reporting | Grades, accepts or rejects submitted reports |
| `reporting.visitor` | Reporting | Read-only access to published (non-draft) reports |
| `dormitory.admin` | Dormitory | Module admin, manages dormitory users and reference data |
| `dormitory.commandant` | Dormitory | Manages settlements in their assigned buildings only |
| `dormitory.registrar` | Dormitory | Registers residents, issues receipts, read-only elsewhere |

Legend: **✓** full access · **◐** scoped access (see notes) · **✎** own records only · **—** denied.

## Core

| Capability | Who |
|---|---|
| Sign in / sign out / password reset | Any user |
| Home page / personal dashboard | Any active user |
| View own profile | Any user |
| Notifications: view own, mark read | Any user |
| Activity feed | `admin`, `supervisor`, `reporting.admin`, `dormitory.admin` |
| Administer users: create, edit, activate/deactivate | `admin`; `reporting.admin` / `dormitory.admin` for users whose roles all belong to their module |
| Administer users: delete, reset password | `admin` (never for self; delete also blocked for the last active `dormitory.admin`) |

## Dormitory

| Capability | `admin` | `dormitory.admin` | `dormitory.commandant` | `dormitory.registrar` |
|---|:---:|:---:|:---:|:---:|
| Dormitory dashboard | ✓ | ✓ | ◐ buildings | ✓ |
| Academic years — view | ✓ | ✓ | ✓ | ✓ |
| Academic years — manage | ✓ | ✓ | — | — |
| Buildings — view | ✓ | ✓ | ◐ buildings | ✓ |
| Buildings — manage | ✓ | ✓ | — | — |
| Rooms — view | ✓ | ✓ | ◐ buildings | ✓ |
| Rooms — manage, batch create | ✓ | ✓ | — | — |
| Residents — view | ✓ | ✓ | ◐ ¹ | ✓ |
| Residents — create / edit | ✓ | ✓ | ◐ buildings | ✓ |
| Residents — delete | ✓ | ✓ | — | — |
| Register resident with place ² | ✓ | ✓ | ◐ buildings | ✓ |
| Accommodations — view, debtors | ✓ | ✓ | ◐ buildings | ✓ |
| Settle / transfer / evict | ✓ | ✓ | ◐ buildings | — |
| Force-settle (over capacity) | ✓ | ✓ | — | — |
| Confirm pending settlement | ✓ | ✓ | — | ✓ |
| Reject pending settlement | ✓ | ✓ | — | — |
| Receipts — view | ✓ | ✓ | ◐ buildings | ✓ |
| Receipts — add | ✓ | ✓ | ◐ buildings | ✓ |
| Receipts — edit / delete | ✓ | ✓ | ◐ buildings | — |
| Violations — view | ✓ | ✓ | ◐ ¹ | ✓ |
| Violations — manage | ✓ | ✓ | ◐ buildings | — |
| Batch eviction operations | ✓ | ✓ | ◐ buildings | — |
| CSV exports | ✓ | ✓ | ◐ buildings | ✓ |

¹ Commandant sees residents/violations of assigned buildings **plus** residents without a room.
² During registration the room and bed are suggested automatically; manual room/bed
selection is available to `admin` and `dormitory.admin` only.

## Reporting

| Capability | `admin` | `reporting.admin` | `reporting.manager` | `reporting.reporter` | `reporting.reviewer` | `reporting.visitor` | `supervisor` |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| Templates — view published ³ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Templates — manage ⁴ | ✓ | ✓ | ✎ drafts | — | — | — | — |
| Reports — list / see | all | all | ✎ created | ✎ assigned | ✎ assigned | non-draft | all |
| Reports — create | ✓ | ✓ | ✓ | — | — | — | — |
| Reports — edit / delete own draft | ✓ | ✓ | ✎ | — | — | — | — |
| Take report in progress | ✓ | ✓ | — | ◐ assigned | — | — | — |
| Fill in report items | ✓ | ✓ | — | ◐ assigned | — | — | — |
| Submit report | ✓ | ✓ | — | ◐ assigned | — | — | — |
| Grade items | ✓ | ✓ | — | — | ◐ assigned | — | — |
| Accept report ⁵ | ✓ | ✓ | — | — | ◐ assigned | — | — |
| Reject report | ✓ | ✓ | — | — | ◐ assigned | — | — |
| Reopen rejected report | ✓ | ✓ | — | ◐ assigned | — | — | — |
| Comments — create | ✓ | ✓ | ✓ | ✓ | ✓ | — | ✓ |
| Comments — delete | ✓ | ✓ | author | — | — | — | — |
| PDF — view | = show | = show | = show | = show | = show | = show | = show |
| PDF — regenerate | ✓ | ✓ | ✓ | — | — | — | — |
| Reporter profiles | ✓ | ✓ | — | — | — | ✓ | ✓ |

³ Published templates are visible to any authenticated user (also outside the reporting module).
⁴ Manager: create, edit/delete/publish own drafts, archive own published templates.
◐ assigned = only for records where the user is the assigned reporter/reviewer.
⁵ Accept requires every item graded.

## Scoping rules

- **Module-scoped user administration** (`UserRole::MODULE_ROLES`): `reporting.admin`
  administers only users whose roles are within `reporting.*`; `dormitory.admin` only
  within `dormitory.*`. Global `admin` administers everyone.
- **Protected role**: the last active `dormitory.admin` cannot be deleted or deactivated.
  Nobody can delete or deactivate their own account.
- **Commandant building scope**: assignments live in `dormitory_commandant_buildings`
  (with deactivation support).
- **Active role** (single-role sessions): a user with several roles has exactly one
  *active* role per session (`sessions.active_role`). All role checks see only the
  active role; switching is available in the user menu. The default active role is
  the highest-privilege assigned role (`UserRole::ROLE_PRIORITY`); if the active role
  is revoked while the session lives, the default takes over.
- **Report visibility** (`Reporting::ReportPolicy::Scope`): `admin`, `supervisor`,
  `reporting.admin` see everything; `reporting.visitor` sees non-draft reports;
  managers see reports they created; reporters/reviewers see reports assigned to them.
  Users without any reporting role (pure dormitory staff, role-less users) have no
  reports access at all — the list page is denied and the sidebar menu is hidden.
