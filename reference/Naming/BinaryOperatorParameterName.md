# `Naming/BinaryOperatorParameterName`

A rule that enforces that certain binary operator methods have
standardized parameter names - by default `other`.

For example, this is considered valid:

```crystal
class Money
  def +(other)
  end
end
```

And this is invalid parameter name:

```crystal
class Money
  def +(amount)
  end
end
```

## YAML configuration example

```yaml
Naming/BinaryOperatorParameterName:
  Enabled: true
  ExcludedOperators: ["[]", "[]?", "[]=", "<<", ">>", "=~", "!~"]
  AllowedNames: [other]
```
