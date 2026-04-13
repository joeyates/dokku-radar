# Agent Instructions

See also:

* ARCHITECTURE.md

## Skills

- `ssh -t dokku@$DOKKU_HOST help` — list commands available on the production Dokku instance on `$DOKKU_HOST`
- `ssh -t dokku@$DOKKU_HOST COMMAND` — run other commands on the production Dokku instance
- `mix test` — run the test suite
- `mix check-formatted` — check code formatting (uses Green linter)
