# UniverHub — Agent Guidelines

## Project

- Rails 8.1, Ruby 3.4, PostgreSQL
- Pundit (authorization), AASM (state machines), Pagy (pagination), Turbo/Stimulus (frontend)
- RuboCop Rails Omakase (linting), Brakeman (security)

## Conventions
- Use Conventional Commits spec for commit msg

## Commands

```bash
bin/rails test           # all tests
bin/rails test test/models/report_test.rb:27  # single test by line
bin/rails test:system    # system tests only
bin/rubocop              # lint (only .rb)
bin/rubocop -A           # lint auto-fix
bin/brakeman             # security scan
```

## Architecture

- **Authorization**: Pundit policies only. Never check roles in views — use `policy(object).action?`
- **State Machines**: AASM with explicit event methods (e.g., `do_publish!`, `do_accept!`)
- **Audit Logging**: Include `Trackable` concern — logs via `OutboxEvent`
- **Code Style**: 2-space indent, 120 char max line, double quotes, trailing commas in multi-line
- **RESTful Controllers**: only `new`, `index`, `create`, `edit`, `update`, `delete`, `show` methods in controllers handle requests. Extract action to dedicated controllers or add params to handle custom action. Ask before implementation.


## Views

- Prefer `tag.span` over raw HTML in helpers
- Use `l()` for dates, `t()` for translations
- No direct role references — always through policies

## Testing

- Minitest (not RSpec)
- Fixtures: `test/fixtures/*.yml`
- Helpers: `test/test_helpers/`

## Localization

- All UI strings in `config/locales/ru.yml`
- Scoped keys: `notifications.actions.report.assigned`
- Include pluralization rules for `datetime.distance_in_words`

## Rules

- After work with code show commit message
- Don't read @docs/* if explicit instructions not provided
- Don't commit if explicit instructions not provided
- Use ripgrep instead of grep if available
- The feature’s behavior and key points from Acceptance Criteria and Business Rules must be covered by tests.

