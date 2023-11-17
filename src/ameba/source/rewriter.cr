class Ameba::Source
  # This class performs the heavy lifting in the source rewriting process.
  # It schedules code updates to be performed in the correct order.
  #
  # For simple cases, the resulting source will be obvious.
  #
  # Examples for more complex cases follow. Assume these examples are acting on
  # the source `puts(:hello, :world)`. The methods `#wrap`, `#remove`, etc.
  # receive a range as the first two arguments; for clarity, examples below use
  # English sentences and a string of raw code instead.
  #
  # ## Overlapping deletions:
  #
  # * remove `:hello, `
  # * remove `, :world`
  #
  # The overlapping ranges are merged and `:hello, :world` will be removed.
  #
  # ## Multiple actions at the same end points:
  #
  # Results will always be independent of the order they were given.
  # Exception: rewriting actions done on exactly the same range (covered next).
  #
  # Example:
  #
  # * replace `, ` by ` => `
  # * wrap `:hello, :world` with `{` and `}`
  # * replace `:world` with `:everybody`
  # * wrap `:world` with `[`, `]`
  #
  # The resulting string will be `puts({:hello => [:everybody]})`
  # and this result is independent of the order the instructions were given in.
  #
  # ## Multiple wraps on same range:
  #
  # * wrap `:hello` with `(` and `)`
  # * wrap `:hello` with `[` and `]`
  #
  # The wraps are combined in order given and results would be `puts([(:hello)], :world)`.
  #
  # ## Multiple replacements on same range:
  #
  # * replace `:hello` by `:hi`, then
  # * replace `:hello` by `:hey`
  #
  # The replacements are made in the order given, so the latter replacement
  # supersedes the former and `:hello` will be replaced by `:hey`.
  #
  # ## Swallowed insertions:
  #
  # * wrap `world` by `__`, `__`
  # * replace `:hello, :world` with `:hi`
  #
  # A containing replacement will swallow the contained rewriting actions
  # and `:hello, :world` will be replaced by `:hi`.
  #
  # ## Implementation
  #
  # The updates are organized in a tree, according to the ranges they act on
  # (where children are strictly contained by their parent).
  class Rewriter
    getter code : String

    def initialize(@code)
      @action_root = Rewriter::Action.new(0, code.size)
    end

    # Returns `true` if no (non trivial) update has been recorded
    def empty?
      @action_root.empty?
    end

    # Replaces the code of the given range with *content*.
    def replace(begin_pos, end_pos, content)
      combine begin_pos, end_pos,
        replacement: content.to_s
    end

    # Inserts the given strings before and after the given range.
    def wrap(begin_pos, end_pos, insert_before, insert_after)
      combine begin_pos, end_pos,
        insert_before: insert_before.to_s,
        insert_after: insert_after.to_s
    end

    # Shortcut for `replace(begin_pos, end_pos, "")`
    def remove(begin_pos, end_pos)
      replace(begin_pos, end_pos, "")
    end

    # Shortcut for `wrap(begin_pos, end_pos, content, nil)`
    def insert_before(begin_pos, end_pos, content)
      wrap(begin_pos, end_pos, content, nil)
    end

    # Shortcut for `wrap(begin_pos, end_pos, nil, content)`
    def insert_after(begin_pos, end_pos, content)
      wrap(begin_pos, end_pos, nil, content)
    end

    # Shortcut for `insert_before(pos, pos, content)`
    def insert_before(pos, content)
      insert_before(pos, pos, content)
    end

    # Shortcut for `insert_after(pos, pos, content)`
    def insert_after(pos, content)
      insert_after(pos, pos, content)
    end

    # Applies all scheduled changes and returns modified source as a new string.
    def process
      String.build do |io|
        last_end = 0
        @action_root.ordered_replacements.each do |begin_pos, end_pos, replacement|
          io << code[last_end...begin_pos] << replacement
          last_end = end_pos
        end
        io << code[last_end...code.size]
      end
    end

    protected def combine(begin_pos, end_pos, **attributes)
      check_range_validity(begin_pos, end_pos)
      action = Rewriter::Action.new(begin_pos, end_pos, **attributes)
      @action_root = @action_root.combine(action)
    end

    private def check_range_validity(begin_pos, end_pos)
      return unless begin_pos < 0 || end_pos > code.size
      raise IndexError.new(
        "The range #{begin_pos}...#{end_pos} is outside the bounds of the source"
      )
    end
  end
end
