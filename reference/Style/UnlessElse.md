# `Style/UnlessElse`

A rule that disallows the use of an `else` block with the `unless`.

For example, the rule considers these valid:

```crystal
unless something
  :ok
end

if something
  :one
else
  :two
end
```

But it considers this one invalid as it is an `unless` with an `else`:

```crystal
unless something
  :one
else
  :two
end
```

The solution is to swap the order of the blocks, and change the `unless` to
an `if`, so the previous invalid example would become this:

```crystal
if something
  :two
else
  :one
end
```

## YAML configuration example

```yaml
Style/UnlessElse:
  Enabled: true
```
