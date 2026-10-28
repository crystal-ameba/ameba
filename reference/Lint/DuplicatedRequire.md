# `Lint/DuplicatedRequire`

A rule that reports duplicated `require` statements.

```crystal
require "./thing"
require "./stuff"
require "./thing" # duplicated require
```

## YAML configuration example

```yaml
Lint/DuplicatedRequire:
  Enabled: true
```
