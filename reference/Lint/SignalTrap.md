# `Lint/SignalTrap`

A rule that reports when `Signal::INT/HUP/TERM.trap` is used,
which should be replaced with `Process.on_terminate` instead -
a more portable alternative.

For example, this is considered invalid:

```crystal
Signal::INT.trap do
  shutdown
end
```

And it should be written as this:

```crystal
Process.on_terminate do
  shutdown
end
```

## YAML configuration example

```yaml
Lint/SignalTrap:
  Enabled: true
```
