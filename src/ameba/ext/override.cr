# TODO: remove in a next release
# (preserves backward compatibility of crystal <= 1.3.2 )
{% if compare_versions(Crystal::VERSION, "1.3.2") < 1 %}
  struct Symbol
    def comment?
      self == :COMMENT
    end

    def delimiter_start?
      self == :DELIMITER_START
    end

    def delimiter_end?
      self == :DELIMITER_END
    end

    def interpolation_start?
      self == :INTERPOLATION_START
    end

    def string_array_start?
      self == :STRING_ARRAY_START
    end

    def string_array_end?
      self == :STRING_ARRAY_END
    end

    def symbol_array_start?
      self == :SYMBOL_ARRAY_START
    end

    def eof?
      self == :EOF
    end

    def op_rcurly?
      self == :"}"
    end

    def begin?
      self == :begin
    end

    def op_minus_gt?
      self == :"->"
    end

    def ident?
      self == :IDENT
    end

    def op_lparen?
      self == :"("
    end

    def op_rparen?
      self == :")"
    end

    def newline?
      self == :NEWLINE
    end

    def space?
      self == :SPACE
    end

    def number?
      self == :NUMBER
    end

    def string?
      self == :STRING
    end
  end

  struct Crystal::Token::Kind
    #
  end
{% end %}
