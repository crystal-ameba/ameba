# `Lint/UnusedExpression`

A rule that disallows unused expressions.

For example, this is considered invalid:

```crystal
a = obj.method do |x|
  x == 1 # => Comparison operation has no effect
  puts x
end

Float64 | StaticArray(Float64, 10)

pointerof(foo)
```

And these are considered valid:

```crystal
a = obj.method do |x|
  x == 1
end

foo : Float64 | StaticArray(Float64, 10) = 0.1

bar = pointerof(foo)
```

This rule currently supports checking for unused:
- comparison operators: `<`, `>=`, etc.
- generics and unions: `String?`, `Int32 | Float64`, etc.
- literals: strings, bools, chars, hashes, arrays, range, etc.
- pseudo-method calls: `sizeof`, `is_a?` etc.
- variable access: local, `@ivar`, `@@cvar` and `self`

## YAML configuration example

```yaml
Lint/UnusedExpression:
  Enabled: true
```
