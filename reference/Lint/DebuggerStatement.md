# `Lint/DebuggerStatement`

A rule that disallows calls to `debugger`.

This is because we don't want debugger breakpoints accidentally being
committed into our codebase.

## YAML configuration example

```yaml
Lint/DebuggerStatement:
  Enabled: true
```
