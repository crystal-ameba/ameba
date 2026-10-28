# `Lint/RedundantWithIndex`

A rule that disallows redundant `with_index` calls.

For example, this is considered invalid:

```crystal
collection.each.with_index do |e|
  # ...
end

collection.each_with_index do |e, _|
  # ...
end
```

and it should be written as follows:

```crystal
collection.each do |e|
  # ...
end
```

## YAML configuration example

```yaml
Lint/RedundantWithIndex:
  Enabled: true
```
