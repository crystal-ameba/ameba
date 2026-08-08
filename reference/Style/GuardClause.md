# `Style/GuardClause`

Use a guard clause instead of wrapping the code inside a conditional
expression

```crystal
# bad
def test
  if something
    work
  end
end

# good
def test
  return unless something

  work
end

# also good
def test
  work if something
end

# bad
if something
  raise "exception"
else
  ok
end

# good
raise "exception" if something
ok

# bad
if something
  foo || raise("exception")
else
  ok
end

# good
foo || raise("exception") if something
ok
```

## YAML configuration example

```yaml
Style/GuardClause:
  Enabled: true
```
