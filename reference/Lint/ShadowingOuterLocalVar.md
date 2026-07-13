# `Lint/ShadowingOuterLocalVar`

A rule that disallows the usage of the same name as outer local variables
for block or proc arguments.

For example, this is considered incorrect:

```crystal
def some_method
  foo = 1

  3.times do |foo| # shadowing outer `foo`
  end
end
```

and should be written as:

```crystal
def some_method
  foo = 1

  3.times do |bar|
  end
end
```

## YAML configuration example

```yaml
Lint/ShadowingOuterLocalVar:
  Enabled: true
```
