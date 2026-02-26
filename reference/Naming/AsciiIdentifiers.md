# `Naming/AsciiIdentifiers`

A rule that reports non-ascii characters in identifiers.

Favour this:

```crystal
class BigAwesomeWolf
end
```

Over this:

```crystal
class BigAwesome🐺
end
```

## YAML configuration example

```yaml
Naming/AsciiIdentifiers:
  Enabled: true
  IgnoreSymbols: false
```
