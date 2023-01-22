module Ameba::Rule::Style
  # A rule that disallows the use of an `else` block with the `unless`.
  #
  # For example, the rule considers these valid:
  #
  # ```
  # unless something
  #   :ok
  # end
  #
  # if something
  #   :one
  # else
  #   :two
  # end
  # ```
  #
  # But it considers this one invalid as it is an `unless` with an `else`:
  #
  # ```
  # unless something
  #   :one
  # else
  #   :two
  # end
  # ```
  #
  # The solution is to swap the order of the blocks, and change the `unless` to
  # an `if`, so the previous invalid example would become this:
  #
  # ```
  # if something
  #   :two
  # else
  #   :one
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Style/UnlessElse:
  #   Enabled: true
  # ```
  class UnlessElse < Base
    properties do
      description "Disallows the use of an `else` block with the `unless`"
    end

    MSG = "Favour if over unless with else"

    def test(source, node : Crystal::Unless)
      return if node.else.nop?

      location = node.location
      cond_end_location = node.cond.end_location
      else_location = node.else_location
      end_location = node.end_location

      unless location && cond_end_location && else_location && end_location
        issue_for node, MSG
        return
      end

      issue_for location, cond_end_location, MSG do |corrector|
        keyword_begin_pos = source.pos(location)
        keyword_end_pos = keyword_begin_pos + {{ "unless".size }}
        keyword_range = keyword_begin_pos...keyword_end_pos

        cond_end_pos = source.pos(cond_end_location, end: true)
        else_begin_pos = source.pos(else_location)
        body_range = cond_end_pos...else_begin_pos

        else_end_pos = else_begin_pos + {{ "else".size }}
        end_end_pos = source.pos(end_location, end: true)
        end_begin_pos = end_end_pos - {{ "end".size }}
        else_range = else_end_pos...end_begin_pos

        corrector.replace(keyword_range, "if")
        corrector.replace(body_range, source.code[else_range])
        corrector.replace(else_range, source.code[body_range])
      end
    end
  end
end
