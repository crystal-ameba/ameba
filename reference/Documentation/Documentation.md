# `Documentation/Documentation`

A rule that enforces documentation for public types:
modules, classes, enums, methods and macros.

## YAML configuration example

```yaml
Documentation/Documentation:
  Enabled: true
  IgnoreClasses: false
  IgnoreModules: true
  IgnoreEnums: false
  IgnoreDefs: true
  IgnoreMacros: false
  IgnoreMacroHooks: true
  RequireExample: false
```
