# `Lint/UselessVisibilityModifier`

A rule that disallows top level `protected` method visibility modifier,
since it has no effect.

For example, this is considered invalid:

```crystal
protected def foo
end
```

And has to be written as follows:

```crystal
def foo
end
```

## YAML configuration example

```yaml
Lint/UselessVisibilityModifier:
  Enabled: true
```
