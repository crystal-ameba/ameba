# `Style/NegatedConditionsInUnless`

A rule that disallows negated conditions in `unless`.

For example, this is considered invalid:

```crystal
unless !s.empty?
  :ok
end
```

And should be rewritten to the following:

```crystal
if s.empty?
  :ok
end
```

It is pretty difficult to wrap your head around a block of code
that is executed if a negated condition is NOT met.

## YAML configuration example

```yaml
Style/NegatedConditionsInUnless:
  Enabled: true
```
