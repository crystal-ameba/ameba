module Ameba::AST
  # Scans the raw text of a macro body (its `MacroLiteral` nodes),
  # telling the code apart from the comments and the literals.
  #
  # Macro bodies are kept as a raw `MacroLiteral` text, split at macro
  # expressions and control nodes, so i.e. a comment or a string literal
  # can span multiple nodes - hence the scanner keeps its state between
  # the subsequent `#scan` calls, which must follow the order of the nodes.
  #
  # ```
  # scanner = MacroCodeScanner.new
  # scanner.scan(%(foo "bar" # baz\n)) # => "foo            \n"
  # ```
  class MacroCodeScanner
    private enum Kind
      Comment
      Literal
      Interpolation
    end

    # Lexical context opened within a macro literal
    private class Context
      getter kind : Kind

      # Delimiters of a literal (`'\0'` if none, i.e. for a heredoc)
      getter opening : Char
      getter closing : Char

      getter? interpolates : Bool
      getter? escapes : Bool
      getter? regex : Bool

      # Pattern matching the closing line of a heredoc
      getter heredoc_end : Regex?

      # Nesting level of the literal delimiters, or of the `{` braces
      # within an interpolation
      property nesting = 0

      def initialize(@kind, closing = '\0', opening = closing, *,
                     @interpolates = false, @escapes = false, @regex = false,
                     @heredoc_end = nil)
        @opening = opening
        @closing = closing
      end
    end

    # Matches the start of a heredoc, i.e. `<<-FOO` or `<<-'FOO'`
    private HEREDOC_START = /<<-(?:'([\p{L}_][\p{L}\p{N}_]*)'|([\p{L}_][\p{L}\p{N}_]*))/

    private PERCENT_LITERAL_DELIMITERS = {
      '(' => ')',
      '[' => ']',
      '{' => '}',
      '<' => '>',
      '|' => '|',
    }

    # Stack of the opened lexical contexts (an empty stack means plain code)
    @contexts = [] of Context

    # Heredocs started on the current line, their bodies begin on the next one
    @heredocs = [] of Context

    # Last character scanned
    @prev_char = '\0'

    # Last non-blank character scanned
    @last_char = '\0'

    # Character preceding the `@last_char`
    @before_last_char = '\0'

    # Reader of the currently scanned macro literal
    @reader = Char::Reader.new("")

    # Returns a deep copy of the scanner, i.e. to scan alternative
    # macro branches starting from the same lexical state.
    def clone : self
      dup.tap(&.copy_contexts!)
    end

    protected def copy_contexts! : Nil
      @contexts = @contexts.map(&.dup)
      @heredocs = @heredocs.map(&.dup)
    end

    # Marks the end of a value placed in between the scanned macro literals,
    # i.e. the output of a `{{ ... }}` macro expression, so that the following
    # `/` or `%` are treated as operators, not literal delimiters.
    def after_value! : Nil
      @prev_char = @last_char = ')'
    end

    # Returns the macro *literal* with all of the comments, string, char,
    # command, symbol, percent, regex and heredoc literals blanked out,
    # while keeping the code within their interpolations.
    #
    # The returned string has the same number of characters and lines
    # as *literal*, as the blanked out characters (but newlines) are
    # replaced with spaces.
    def scan(literal : String) : String
      String.build(literal.bytesize) do |io|
        @reader = Char::Reader.new(literal)

        while @reader.has_next?
          char = @reader.current_char
          start = @reader.pos

          io << (scan_char(char) ? char : blank(char))

          # Blanks out the characters skipped while scanning *char*
          if (skipped_from = start + char.bytesize) <= @reader.pos
            literal
              .byte_slice(skipped_from, @reader.pos + @reader.current_char_width - skipped_from)
              .each_char { |skipped_char| io << blank(skipped_char) }
          end

          before_char, @prev_char = @prev_char, @reader.current_char
          unless @prev_char.in?(' ', '\t')
            @before_last_char, @last_char = before_char, @prev_char
          end
          @reader.next_char
        end
      end
    end

    private def blank(char : Char) : Char
      char == '\n' ? '\n' : ' '
    end

    # Scans *char* in the current context, returns `true` if it's a part of the code
    private def scan_char(char : Char) : Bool
      context = @contexts.last?

      if context.nil? || context.kind.interpolation?
        scan_code(char)
      else
        context.kind.comment? ? scan_comment(char) : scan_literal(char, context)
      end
    end

    # Scans *char* within a comment, returns `false`
    private def scan_comment(char : Char) : Bool
      if char == '\n'
        @contexts.pop
        open_pending_heredoc
      end
      false
    end

    # Scans *char* within a literal, returns `false`
    private def scan_literal(char : Char, context : Context) : Bool
      return false if close_heredoc(context)

      case char
      when '\\'
        advance if context.escapes?
      when '#'
        scan_literal_hash(context)
      when '{'
        scan_literal_opening_brace(context)
      when '\n'
        # Char literals can't span multiple lines, so an unterminated one
        # shouldn't swallow the rest of the macro body
        @contexts.pop if context.closing == '\''
      when context.closing
        close_literal(context)
      when context.opening
        context.nesting += 1
      end
      false
    end

    # Opens an interpolation if it's its start (`#{`)
    private def scan_literal_hash(context : Context) : Nil
      return unless context.interpolates? && @reader.peek_next_char == '{'

      advance
      @contexts << Context.new(:interpolation)
    end

    private def scan_literal_opening_brace(context : Context) : Nil
      # `#` and `{` of an interpolation end up in separate macro literals
      # whenever the macro lexer sees the `#` as a start of a comment,
      # i.e. in `/#{foo}/`
      if context.interpolates? && @prev_char == '#' && @reader.pos.zero?
        @contexts << Context.new(:interpolation)
        return
      end

      context.nesting += 1 if context.opening == '{'
    end

    # Scans *char* within code (or an interpolation),
    # returns `true` if it's a part of the code
    private def scan_code(char : Char) : Bool
      case char
      when '#'       then @contexts << Context.new(:comment)
      when '"', '\'' then @contexts << quoted_literal(char)
      when '`'       then return !start_command_literal
      when ':'       then return !start_symbol_literal
      when '%'       then return !start_percent_literal
      when '/'       then return !start_regex_literal
      when '<'       then return !start_heredoc
      when '{'       then return scan_opening_brace
      when '}'       then return scan_closing_brace
      when '\n'      then return open_pending_heredoc || true
      else                return true
      end
      false
    end

    private def scan_opening_brace : Bool
      if (context = @contexts.last?) && context.kind.interpolation?
        context.nesting += 1
      end
      true
    end

    # Closes the current interpolation if it's its closing brace
    private def scan_closing_brace : Bool
      context = @contexts.last?
      return true unless context && context.kind.interpolation?

      if context.nesting.zero?
        @contexts.pop
        return false
      end

      context.nesting -= 1
      true
    end

    # Returns a string (`"`), char (`'`), or command (`` ` ``) literal context
    private def quoted_literal(quote : Char) : Context
      Context.new(:literal, quote, interpolates: quote != '\'', escapes: true)
    end

    private def close_literal(context : Context) : Nil
      unless context.nesting.zero?
        context.nesting -= 1
        return
      end

      @contexts.pop

      # Skips the regex options, i.e. `/foo/imx`
      if context.regex?
        while @reader.peek_next_char.in?('i', 'm', 'x')
          advance
        end
      end
    end

    # Advances the reader up to the last character of a symbol literal
    # (`:foo`) or to the opening quote of a quoted one (`:"foo"`), returns
    # `false` if there's none at the reader's position (i.e. `Foo::Bar`,
    # `a ? b : c`, or `{foo: 1}`).
    private def start_symbol_literal : Bool
      return false if @prev_char == ':' || ident_part?(@prev_char)

      case @reader.peek_next_char
      when '"'
        advance
        @contexts << quoted_literal('"')
        true
      when .letter?, '_'
        while ident_part?(@reader.peek_next_char)
          advance
        end
        skip_symbol_suffix
        true
      else
        false
      end
    end

    # Advances the reader past the method name suffix of a symbol literal
    # (`:foo?`, `:foo!`, `:foo=`), unless it's a part of an operator
    # following it (i.e. `:foo!= x`, `{:foo=>1}`).
    private def skip_symbol_suffix : Nil
      after_suffix = char_at(@reader.pos + @reader.current_char_width + 1)

      case @reader.peek_next_char
      when '?', '!'
        advance unless after_suffix == '='
      when '='
        advance unless after_suffix.in?('=', '~', '>')
      end
    end

    # Advances the reader up to the opening delimiter of a percent literal
    # (i.e. `%(foo)`, `%w[foo]`, or `%r{foo}`), returns `false` if there's
    # none at the reader's position (i.e. `a % b`).
    private def start_percent_literal : Bool
      return false unless literal_allowed?

      pos = @reader.pos
      type = '\0'
      opening = char_at(pos + 1)

      if opening.in?('q', 'Q', 'w', 'i', 'r', 'x')
        type, opening = opening, char_at(pos + 2)
      end

      return false unless closing = PERCENT_LITERAL_DELIMITERS[opening]?

      advance_to(pos + (type == '\0' ? 2 : 3))

      @contexts << Context.new(:literal, closing, opening,
        interpolates: !type.in?('q', 'w', 'i'),
        escapes: type != 'q',
        regex: type == 'r',
      )
      true
    end

    # Returns `false` if the `` ` `` at the reader's position isn't
    # a start of a command literal (i.e. ``def `(command)``).
    private def start_command_literal : Bool
      return false if operator_name?

      @contexts << quoted_literal('`')
      true
    end

    # Returns `false` if the `/` at the reader's position isn't
    # a start of a regex literal (i.e. `a / b`).
    private def start_regex_literal : Bool
      return false unless literal_allowed?

      @contexts << Context.new(:literal, '/', interpolates: true, escapes: true, regex: true)
      true
    end

    # Advances the reader up to the end of a heredoc start (i.e. `<<-FOO`),
    # its body begins on the next line. Returns `false` if there's none
    # at the reader's position (i.e. `a << b`).
    private def start_heredoc : Bool
      return false unless @reader.peek_next_char == '<'
      return false unless match = match_at_reader(HEREDOC_START)

      raw = !!match[1]?
      id = match[1]? || match[2]

      @heredocs << Context.new(:literal,
        interpolates: !raw,
        escapes: !raw,
        heredoc_end: /[ \t]*#{Regex.escape(id)}(?![\p{L}\p{N}_])/,
      )
      advance_to(match.byte_end(0))
      true
    end

    # Opens the first heredoc started on the line that has just ended,
    # returns `true` if there was one.
    private def open_pending_heredoc : Bool
      return false unless heredoc = @heredocs.shift?

      @contexts << heredoc
      true
    end

    # Advances the reader up to the end of the closing line of the heredoc
    # *context*, returns `false` if there's none at the reader's position.
    private def close_heredoc(context : Context) : Bool
      return false unless @prev_char == '\n' && (heredoc_end = context.heredoc_end)
      return false unless match = match_at_reader(heredoc_end)

      advance_to(match.byte_end(0))
      @contexts.pop
      true
    end

    # Matches *regex* anchored at the reader's position
    private def match_at_reader(regex : Regex) : Regex::MatchData?
      regex.match_at_byte_index(@reader.string, @reader.pos, Regex::MatchOptions::ANCHORED)
    end

    # Returns `true` if a `/` or `%` at the reader's position starts
    # a literal, rather than being a binary operator.
    #
    # NOTE: When in doubt, it's not a literal, as the code mistaken for
    # a literal would be blanked out, while a literal mistaken for the code
    # is merely searched for the references.
    private def literal_allowed? : Bool
      # `a //b`
      return false if @prev_char == '/' || operator_name?
      # `(/a/)`, `= /a/`, `a ? /b/ : c`
      return true unless after_value?
      # `a/b`, `(a) / b`, `"a" % b`, `a? / b`
      return false unless @prev_char.in?(' ', '\t') && ident_part?(@last_char)

      # `foo /a/` vs `a / b`, `a /= b`, `a // b`
      next_char = @reader.peek_next_char
      !next_char.whitespace? && !next_char.in?('=', '/', '\0')
    end

    # Returns `true` if the operator at the reader's position is used
    # as a name: of a symbol (`:/`), a method being called (`a./(b)`)
    # or defined (`def /(other)`).
    private def operator_name? : Bool
      @prev_char.in?(':', '.') || after_def_keyword?
    end

    # Returns `true` if the reader's position follows a `def` keyword
    private def after_def_keyword? : Bool
      string = @reader.string
      index = @reader.pos - 1
      while index >= 0 && string.byte_at(index).unsafe_chr.in?(' ', '\t')
        index -= 1
      end
      return false unless index >= 2 && string.byte_slice?(index - 2, 3) == "def"

      index < 3 || !ident_part?(string.byte_at(index - 3).unsafe_chr)
    end

    # Returns `true` if the last non-blank character ends a value,
    # i.e. an identifier, a literal, or a call to `a?` / `a!` method.
    private def after_value? : Bool
      case @last_char
      when ')', ']', '}', '"', '\'', '`'
        true
      when '?', '!'
        ident_part?(@before_last_char)
      else
        ident_part?(@last_char)
      end
    end

    private def ident_part?(char : Char) : Bool
      char.alphanumeric? || char == '_'
    end

    # Returns the character at the given byte *index* of the scanned
    # macro literal (`'\0'` if there's none, or it's not an ASCII one).
    private def char_at(index : Int32) : Char
      byte = @reader.string.byte_at?(index)
      byte && byte < 0x80 ? byte.unsafe_chr : '\0'
    end

    # Advances the reader by one (skipped) character, unless it's
    # at the last one. Returns `true` if it did.
    #
    # NOTE: Skipped characters are considered to be blanked out.
    private def advance : Bool
      return false unless @reader.pos + @reader.current_char_width < @reader.string.bytesize

      @reader.next_char
      true
    end

    # Advances the reader up to the last character before the byte *index*
    private def advance_to(index : Int32) : Nil
      while @reader.pos + @reader.current_char_width < index
        break unless advance
      end
    end
  end
end
