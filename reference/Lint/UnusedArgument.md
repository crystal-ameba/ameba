# `Lint/UnusedArgument`

A rule that reports unused arguments.
For example, this is considered invalid:

```crystal
def method(a, b, c)
  a + b
end
```

and should be written as:

```crystal
def method(a, b)
  a + b
end
```

## YAML configuration example

```yaml
Lint/UnusedArgument:
  Enabled: true
  IgnoreDefs: true
  IgnoreBlocks: false
  IgnoreProcs: false
```
