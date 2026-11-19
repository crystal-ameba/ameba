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

      def_equals_and_hash @kind, @opening, @closing, @interpolates, @escapes,
        @regex, @heredoc_end, @nesting

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

    # Kinds of the operand preceding a `/` or `%` (i.e. `a /b`)
    private enum Operand
      # A literal, a constant, or a variable (but a local one), followed
      # by an operator (`1 /a`, `(a) /b`, `A /b`, `@a /b`, `self /a`)
      Value
      # A method call or a keyword, followed by a literal
      # (`a.b /c/`, `A::b /c/`, `a? /b/`, `when /a/`)
      Call
      # Either a local variable or a method call (`a /b`)
      Unknown
    end

    # Keywords followed by an expression, i.e. by a regex literal (`when /a/`)
    private EXPRESSION_KEYWORDS = %w[
      if unless elsif when while until return next break yield then else do begin case
    ]

    # Keywords being a value, i.e. followed by an operator (`self /a`)
    private VALUE_KEYWORDS = %w[self nil true false]

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

    # Kind of the operand ending the previously scanned macro literals,
    # i.e. `puts` in `puts{% if foo %}{% end %} /a/`
    @last_operand = Operand::Value

    # Reader of the currently scanned macro literal
    @reader = Char::Reader.new("")

    # Whether the ambiguous `/` are read the other way round
    # (see `#flipped`) within the currently scanned macro literal
    @flipped = false

    # Returns `true` if the last scanned macro literal has any `/` read
    # as the division operator, which might start a regex literal as well,
    # i.e. `a /b / c` (`a` being a local variable) vs `foo /a / if b`.
    getter? ambiguous = false

    # Scanners in the same lexical state are equal
    def_equals_and_hash @contexts, @heredocs, @prev_char, @last_char,
      @before_last_char, @last_operand

    # Returns a deep copy of the scanner, i.e. to scan alternative
    # macro branches starting from the same lexical state.
    def clone : self
      dup.tap(&.copy_contexts!)
    end

    protected def copy_contexts! : Nil
      @contexts = @contexts.map(&.dup)
      @heredocs = @heredocs.map(&.dup)
    end

    # Returns a copy of the scanner, which reads the ambiguous `/`
    # (see `#ambiguous?`) of the next scanned macro literal as regex
    # literals, i.e. to follow both of their readings.
    def flipped : self
      clone.tap(&.flip!)
    end

    protected def flip! : Nil
      @flipped = true
    end

    # Marks the end of a value placed in between the scanned macro literals,
    # i.e. the output of a `{{ ... }}` macro expression, so that the following
    # `/` or `%` are treated as operators, not literal delimiters.
    def after_value! : Nil
      @prev_char = @last_char = ')'
      @last_operand = Operand::Value
    end

    # Returns the macro *literal* with all of the comments, string, char,
    # command, symbol, percent, regex and heredoc literals blanked out,
    # while keeping the code within their interpolations.
    #
    # The returned string has the same number of characters and lines
    # as *literal*, as the blanked out characters (but newlines) are
    # replaced with spaces.
    def scan(literal : String) : String
      @ambiguous = false

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

        unless skip_blanks_back(literal.bytesize - 1).negative?
          @last_operand = operand_before(literal.bytesize)
        end
      end
    ensure
      @flipped = false
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

      @contexts << Context.new(:literal, '/',
        interpolates: true,
        escapes: true,
        regex: true,
      )
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
    # is merely searched for the references - unless it'd make the rest
    # of the literal a comment (`foo /a#{b} /`), in which case the scanned
    # literal is marked as `#ambiguous?`, to follow both of the readings.
    private def literal_allowed? : Bool
      # `a //b`
      return false if @prev_char == '/' || operator_name?
      # `(/a/)`, `= /a/`, `a ? /b/ : c`
      return true unless after_value?
      # `a/b`, `a?/b`
      return false unless @prev_char.in?(' ', '\t')

      # `foo /a/` vs `a / b`, `a /= b`, `a // b`
      next_char = @reader.peek_next_char
      return false if next_char.whitespace? || next_char.in?('=', '/', '\0')

      case preceding_operand
      in .value? then false
      in .call?  then true
      in .unknown?
        # `foo %(a)` is a literal, even if `foo` is a local variable
        return true unless @reader.current_char == '/'

        # `foo /a/` vs `a /b` - a regex only if `foo` isn't a local variable,
        # which can't be told from the macro code
        return true if regex_closed_on_line?
        return false unless regex_closed_on_line?(spaced: true)

        # `a /b / c` vs `foo /a / if b`
        @ambiguous = true
        @flipped
      end
    end

    # Returns the kind of the operand preceding the reader's position,
    # also one ending the previously scanned macro literals
    private def preceding_operand : Operand
      return @last_operand if skip_blanks_back(@reader.pos - 1).negative?

      operand_before(@reader.pos)
    end

    # Returns the kind of the operand preceding the given byte *index*
    # (skipping the blanks in between)
    private def operand_before(index : Int32) : Operand
      # Local variables can't end with `?` or `!`
      return Operand::Call if char_at(skip_blanks_back(index - 1)).in?('?', '!')

      word, index = preceding_identifier(index)
      prefix = char_at(index)

      case
      when word.empty?                   then Operand::Value
      when word[0].ascii_number?         then Operand::Value
      when word[0].uppercase?            then Operand::Value
      when prefix.in?('@', '$')          then Operand::Value
      when prefix == ':'                 then char_at(index - 1) == ':' ? Operand::Call : Operand::Value
      when prefix == '.'                 then char_at(index - 1) == '.' ? Operand::Unknown : Operand::Call
      when word.in?(VALUE_KEYWORDS)      then Operand::Value
      when word.in?(EXPRESSION_KEYWORDS) then Operand::Call
      else                                    Operand::Unknown
      end
    end

    # Returns the identifier preceding the given byte *index* (skipping
    # the blanks in between), along with the byte index preceding it.
    private def preceding_identifier(index : Int32 = @reader.pos) : {String, Int32}
      index = skip_blanks_back(index - 1)
      word_end = index + 1

      while index >= 0 && ident_byte?(index)
        index -= 1
      end
      {@reader.string.byte_slice(index + 1, word_end - index - 1), index}
    end

    # Returns `true` if the `/` at the reader's position is followed
    # by an unescaped `/` on the same line, which might close a regex,
    # unless it's surrounded by blanks, as a division operator (`a /b / c`)
    # - also then, if *spaced* is `true`.
    private def regex_closed_on_line?(*, spaced = false) : Bool
      index = @reader.pos + 1

      while index < @reader.string.bytesize
        case char_at(index)
        when '\n' then return false
        when '\\' then index += 1
        when '/'
          return true if spaced || !(char_at(index - 1).in?(' ', '\t') &&
                         char_at(index + 1).in?(' ', '\t'))
        end
        index += 1
      end
      false
    end

    # Returns `true` if the operator at the reader's position is used
    # as a name: of a symbol (`:/`), a method being called (`a./(b)`)
    # or defined (`def /(other)`).
    private def operator_name? : Bool
      @prev_char.in?(':', '.') || after_def_keyword?
    end

    # Returns `true` if the reader's position follows a `def` keyword
    private def after_def_keyword? : Bool
      preceding_identifier[0] == "def"
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

    # Returns the byte index of the last non-blank character at or before
    # the given byte *index* of the scanned macro literal (`-1` if none)
    private def skip_blanks_back(index : Int32) : Int32
      while char_at(index).in?(' ', '\t')
        index -= 1
      end
      index
    end

    # Returns `true` if the byte at the given *index* of the scanned macro
    # literal is a part of an identifier (including the non-ASCII ones)
    private def ident_byte?(index : Int32) : Bool
      byte = @reader.string.byte_at(index)
      byte >= 0x80 || ident_part?(byte.unsafe_chr)
    end

    # Returns the character at the given byte *index* of the scanned
    # macro literal (`'\0'` if there's none, or it's not an ASCII one).
    private def char_at(index : Int32) : Char
      return '\0' if index.negative?

      byte = @reader.string.byte_at?(index)
      byte && byte < 0x80 ? byte.unsafe_chr : '\0'
    end

    # Advances the reader by one (skipped) character, unless it's
    # at the last one. Returns `true` if it did.
    #
    # NOTE: Skipped characters are considered to be blanked out.
    private def advance : Bool
      unless @reader.pos + @reader.current_char_width < @reader.string.bytesize
        return false
      end
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
