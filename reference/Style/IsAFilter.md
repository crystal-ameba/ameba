# `Style/IsAFilter`

This rule is used to identify usage of `is_a?/nil?` calls within filters.

For example, this is considered invalid:

```crystal
matches = %w[Alice Bob].map(&.match(/^A./))

matches.any?(&.is_a?(Regex::MatchData)) # => true
matches.one?(&.nil?)                    # => true

typeof(matches.reject(&.nil?))                    # => Array(Regex::MatchData | Nil)
typeof(matches.select(&.is_a?(Regex::MatchData))) # => Array(Regex::MatchData | Nil)
```

And it should be written as this:

```crystal
matches = %w[Alice Bob].map(&.match(/^A./))

matches.any?(Regex::MatchData) # => true
matches.one?(Nil)              # => true

typeof(matches.reject(Nil))              # => Array(Regex::MatchData)
typeof(matches.select(Regex::MatchData)) # => Array(Regex::MatchData)
```

## YAML configuration example

```yaml
Style/IsAFilter:
  Enabled: true
  FilterNames:
    - select
    - reject
    - any?
    - all?
    - none?
    - one?
```
