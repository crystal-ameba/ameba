# `Naming/PredicateName`

A rule that disallows tautological predicate names -
meaning those that start with the prefix `is_`, except for
the ones that are not valid Crystal code (e.g. `is_404?`).

Favour this:

```crystal
def valid?(x)
end
```

Over this:

```crystal
def is_valid?(x)
end
```

## YAML configuration example

```yaml
Naming/PredicateName:
  Enabled: true
```
