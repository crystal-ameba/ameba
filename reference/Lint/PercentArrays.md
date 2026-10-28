# `Lint/PercentArrays`

A rule that disallows some unwanted symbols in percent string and symbol array literals.

For example, this is usually written by mistake:

```crystal
%w["one", "two"]
%i[:one, :two]
```

And the expected example is:

```crystal
%w[one two]
%i[one two]
```

## YAML configuration example

```yaml
Lint/PercentArrays:
  Enabled: true
  StringArrayUnwantedSymbols: ',"'
  SymbolArrayUnwantedSymbols: ',:'
```
