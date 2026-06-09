# `Lint/SelfInitializeDefinition`

A rule that reports usage of `initialize` method definition with a `self` receiver.
Such definitions are almost always a typo.

For example, this is considered invalid:

```crystal
class Foo
  def self.initialize
  end
end
```

And should be written as:

```crystal
class Foo
  def initialize
  end
end
```

## YAML configuration example

```yaml
Lint/SelfInitializeDefinition:
  Enabled: true
```
