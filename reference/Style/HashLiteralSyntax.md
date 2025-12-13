# `Style/HashLiteralSyntax`

Encourages the use of `Hash(K, V).new` syntax for creating a hash over `{} of K => V`.

Favour this:

```crystal
Hash(Int32, String?).new
```

Over this:

```crystal
{} of Int32 => String?
```

## YAML configuration example

```yaml
Style/HashLiteralSyntax:
  Enabled: true
```
