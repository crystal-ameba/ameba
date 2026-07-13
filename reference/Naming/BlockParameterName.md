# `Naming/BlockParameterName`

A rule that reports non-descriptive block parameter names.

Favour this:

```crystal
tokens.each { |token| token.last_accessed_at = Time.utc }
```

Over this:

```crystal
tokens.each { |t| t.last_accessed_at = Time.utc }
```

## YAML configuration example

```yaml
Naming/BlockParameterName:
  Enabled: true
  MinNameLength: 3
  AllowNamesEndingInNumbers: true
  AllowedNames: [a, b, e, i, j, k, v, x, y, k1, k2, v1, v2, db, ex, id, io, ip, op, tx, wg, ws]
  ForbiddenNames: []
```
