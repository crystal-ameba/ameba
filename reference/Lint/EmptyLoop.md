# `Lint/EmptyLoop`

A rule that disallows empty loops.

This is considered invalid:

```crystal
while false
end

until 10
end

loop do
  # nothing here
end
```

And this is valid:

```crystal
a = 1
while a < 10
  a += 1
end

until socket_opened?
end

loop do
  do_something_here
end
```

## YAML configuration example

```yaml
Lint/EmptyLoop:
  Enabled: true
```
