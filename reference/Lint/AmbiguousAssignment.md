# `Lint/AmbiguousAssignment`

This rule checks for mistyped shorthand assignments.

This is considered invalid:

    x =- y
    x =+ y
    x =! y

And this is valid:

    x -= y # or x = -y
    x += y # or x = +y
    x != y # or x = !y

## YAML configuration example

```yaml
Lint/AmbiguousAssignment:
  Enabled: true
```
