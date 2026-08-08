# `Style/RedundantReturn`

A rule that disallows redundant `return` expressions.

For example, this is considered invalid:

```crystal
def foo
  return :bar
end
```

```crystal
def bar(arg)
  case arg
  when .nil?
    return "nil"
  when .blank?
    return "blank"
  else
    return "empty"
  end
end
```

And has to be written as the following:

```crystal
def foo
  :bar
end
```

```crystal
def bar(arg)
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

1. *allow_multi_return*, default: true

Allows end-user to configure whether to report or not the `return` statements
which return tuple literals i.e.

```crystal
def method(a, b)
  return a, b
end
```

If this param equals to `false`, the method above has to be written as:

```crystal
def method(a, b)
  {a, b}
end
```

2. *allow_empty_return*, default: true

Allows end-user to configure whether to report or not the `return` statements
without arguments. Sometimes such returns are used to return the `nil` value explicitly.

```crystal
def method
  @foo = :empty
  return
end
```

If this param equals to `false`, the method above has to be written as:

```crystal
def method
  @foo = :empty
  nil
end
```

### YAML config example

```crystal
Style/RedundantReturn:
  Enabled: true
  AllowMultiReturn: true
  AllowEmptyReturn: true
```
