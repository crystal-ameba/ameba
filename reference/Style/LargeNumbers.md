# `Style/LargeNumbers`

A rule that disallows usage of large numbers without underscore.
These do not affect the value of the number, but can help read
large numbers more easily.

For example, these are considered invalid:

```crystal
100000
141592654
5.123456
```

And has to be rewritten as the following:

```crystal
100_000
141_592_654
5.123_456
```

## YAML configuration example

```yaml
Style/LargeNumbers:
  Enabled: true
  IntMinDigits: 6 # i.e. integers higher than 99999
```
