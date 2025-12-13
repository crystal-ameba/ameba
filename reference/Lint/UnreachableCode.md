# `Lint/UnreachableCode`

A rule that reports unreachable code.

For example, this is considered invalid:

```crystal
def method(a)
  return 42
  a + 1
end
```

```crystal
a = 1
loop do
  break
  a += 1
end
```

And has to be written as the following:

```crystal
def method(a)
  return 42 if a == 0
  a + 1
end
```

```crystal
a = 1
loop do
  break a > 3
  a += 1
end
```

## YAML configuration example

```yaml
Lint/UnreachableCode:
  Enabled: true
```
