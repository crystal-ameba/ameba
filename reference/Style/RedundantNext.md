# `Style/RedundantNext`

A rule that disallows redundant `next` expressions. A `next` keyword allows
a block to skip to the next iteration early, however, it is considered
redundant in cases where it is the last expression in a block or combines
into the node which is the last in a block.

For example, this is considered invalid:

```crystal
block do |v|
  next v + 1
end
```

```crystal
block do |v|
  case v
  when .nil?
    next "nil"
  when .blank?
    next "blank"
  else
    next "empty"
  end
end
```

And has to be written as the following:

```crystal
block do |v|
  v + 1
end
```

```crystal
block do |v|
  case arg
  when .nil?
    "nil"
  when .blank?
    "blank"
  else
    "empty"
  end
end
```

### Configuration params

1. *allow_multi_next*, default: true

Allows end-user to configure whether to report or not the `next` statements
which yield tuple literals i.e.

```crystal
block do
  next a, b
end
```

If this param equals to `false`, the block above will be forced to be written as:

```crystal
block do
  {a, b}
end
```

2. *allow_empty_next*, default: true

Allows end-user to configure whether to report or not the `next` statements
without arguments. Sometimes such statements are used to yield the `nil` value explicitly.

```crystal
block do
  @foo = :empty
  next
end
```

If this param equals to `false`, the block above will be forced to be written as:

```crystal
block do
  @foo = :empty
  nil
end
```

### YAML config example

```crystal
Style/RedundantNext:
  Enabled: true
  AllowMultiNext: true
  AllowEmptyNext: true
```
