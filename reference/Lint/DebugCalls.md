# `Lint/DebugCalls`

A rule that disallows calls to debug-related methods.

This is because we don't want debug calls accidentally being
committed into our codebase.

## YAML configuration example

```yaml
Lint/DebugCalls:
  Enabled: true
  MethodNames:
    - p
    - p!
    - pp
    - pp!
```
