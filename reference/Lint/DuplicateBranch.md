# `Lint/DuplicateBranch`

Checks that there are no repeated bodies within `if/unless`,
`case-when`, `case-in` and `rescue` constructs.

This is considered invalid:

```crystal
if foo
  do_foo
  do_something_else
elsif bar
  do_foo
  do_something_else
end
```

And this is valid:

```crystal
if foo || bar
  do_foo
  do_something_else
end
```

With `IgnoreLiteralBranches: true`, branches are not registered
as offenses if they return a basic literal value (string, symbol,
integer, float, `true`, `false`, or `nil`), or return an array,
hash, regexp or range that only contains one of the above basic
literal values.

With `IgnoreConstantBranches: true`, branches are not registered
as offenses if they return a constant value.

With `IgnoreDuplicateElseBranch: true`, in conditionals with multiple branches,
duplicate 'else' branches are not registered as offenses.

## YAML configuration example

```yaml
Lint/DuplicateBranch:
  Enabled: true
  IgnoreLiteralBranches: false
  IgnoreConstantBranches: false
  IgnoreDuplicateElseBranch: false
```
