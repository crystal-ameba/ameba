# `Lint/ElseNil`

A rule that disallows `else` blocks with `nil` as their body, as they
have no effect and can be safely removed.

This is considered invalid:

```crystal
if foo
  do_foo
else
  nil
end
```

And this is valid:

```crystal
if foo
  do_foo
end
```

## YAML configuration example

```yaml
Lint/ElseNil:
  Enabled: true
```
