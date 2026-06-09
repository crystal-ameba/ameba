# `Performance/AnyInsteadOfPresent`

This rule is used to identify usage of arg-less `Enumerable#any?` calls.

Using `Enumerable#any?` instead of `Enumerable#present?` might lead to an
unexpected results (like `[nil, false].any? # => false`). In some cases
it also might be less efficient, since it iterates until the block will
return a _truthy_ value, instead of just checking if there's at least
one value present.

For example, this is considered invalid:

```crystal
[1, 2, 3].any?
```

And it should be written as this:

```crystal
[1, 2, 3].present?
```

## YAML configuration example

```yaml
Performance/AnyInsteadOfPresent:
  Enabled: true
```
