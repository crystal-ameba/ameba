# `Lint/UselessAssign`

A rule that disallows useless assignments.

For example, this is considered invalid:

```crystal
def method
  var = 1
  do_something
end
```

And has to be written as the following:

```crystal
def method
  var = 1
  do_something(var)
end
```

## YAML configuration example

```yaml
Lint/UselessAssign:
  Enabled: true
  ExcludeTypeDeclarations: false
```
