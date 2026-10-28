# `Lint/VoidOutsideLib`

A rule that disallows uses of `Void` outside C lib bindings.
Usages of these outside of C lib bindings don't make sense,
and can sometimes break the compiler. `Nil` should be used instead in these cases.
`Pointer(Void)` is the only case that's allowed per this rule.

These are considered invalid:

```crystal
def foo(bar : Void) : Slice(Void)?
end

alias Baz = Void

struct Qux < Void
end
```

## YAML configuration example

```yaml
Lint/VoidOutsideLib:
  Enabled: true
```
