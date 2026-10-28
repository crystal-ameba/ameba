# `Style/HeredocIndent`

A rule that enforces _heredoc_ bodies be indented one level above the
indentation of the line they're used on.

For example, this is considered invalid:

    <<-HEREDOC
      hello world
    HEREDOC

      <<-HEREDOC
    hello world
    HEREDOC

And should be written as:

    <<-HEREDOC
        hello world
      HEREDOC

    <<-HEREDOC
      hello world
      HEREDOC

The `IndentBy` configuration option changes the enforced indentation level
of the _heredoc_.

## YAML configuration example

```yaml
Style/HeredocIndent:
  Enabled: true
  IndentBy: 2
```
