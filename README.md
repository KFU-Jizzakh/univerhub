# UniverHub

## Dependencies

| Dependency | Version | Notes |
|---|---|---|
| Ruby | 4.0+ | See `.ruby-version` |
| PostgreSQL | 16+ | |
| [Typst](https://typst.app) | 0.14.2 | PDF report generation. Set `TYPST_BIN_PATH` or install to `~/.local/bin/typst` |

## Setup

```bash
bin/setup
```

## Test

```bash
bin/rails test
```

## Lint

```bash
bin/rubocop
```

## Deployment

Built via Dockerfile. Typst is included in the production image.
