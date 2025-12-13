# `Lint/TrailingRescueException`

A rule that prohibits the misconception about how trailing `rescue` statements work,
preventing Paths (exception class names or otherwise) from being used as the
trailing value. The value after the trailing `rescue` statement is the value
to use if an exception occurs, not the exception class to rescue from.

For example, this is considered invalid - if an exception occurs,
`response` will be assigned with the value of `IO::Error` instead of `nil`:

```crystal
response = HTTP::Client.get("http://www.example.com") rescue IO::Error
```

And should instead be written as this in order to capture only `IO::Error` exceptions:

```crystal
response = begin
  HTTP::Client.get("http://www.example.com")
rescue IO::Error
  "default value"
end
```

Or to rescue all exceptions (instead of just `IO::Error`):

```crystal
response = HTTP::Client.get("http://www.example.com") rescue "default value"
```

## YAML configuration example

```yaml
Lint/TrailingRescueException:
  Enabled: true
```
