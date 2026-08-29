# `Lint/TopLevelOperatorDefinition`

A rule that disallows top level operator method definitions, since these cannot be called.

For example, this is considered invalid:

```crystal
def +(other)
end
```

And has to be written within a class, struct, or module:

```crystal
class Foo
  def +(other)
  end
end
```

## YAML configuration example

```yaml
Lint/TopLevelOperatorDefinition:
  Enabled: true
```
