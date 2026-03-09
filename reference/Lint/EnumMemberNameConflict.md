# `Lint/EnumMemberNameConflict`

A rule that reports conflicting enum member names.

Since Crystal will parse enum member names using `String#camelcase` and
`String#downcase`, it is important to ensure that each member has a name
that stays unique after the transformation.

```crystal
enum Foo
  Bar
  BAR
end

Foo.parse("bar") # => Foo::Bar
Foo.parse("Bar") # => Foo::Bar
Foo.parse("BAR") # => Foo::Bar
```

## YAML configuration example

```yaml
Lint/EnumMemberNameConflict:
  Enabled: true
```
