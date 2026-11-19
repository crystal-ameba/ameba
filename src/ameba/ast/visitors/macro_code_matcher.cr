module Ameba::AST
  # Matches the code of the macro literals within a node (that is, without
  # the comments and literals) against a regex.
  #
  # As the macro branches and loops might leave the code in different
  # lexical states (i.e. `{% if foo %}# bar{% end %}baz`), the code following
  # them is scanned in each of these, matching if it does in any of them.
  # The same goes for the ambiguous `/` (see `MacroCodeScanner#ambiguous?`),
  # which is followed in both of its readings.
  #
  # NOTE: Beyond `MAX_STATES` lexical states, the code following them
  # is also matched as is (that is, with the comments and literals), as
  # their number might grow exponentially with the number of branches.
  # The same goes for the code following `MAX_SCANNED_BYTES` bytes scanned
  # (in all of the lexical states), as the nested loops are expanded
  # repeatedly - beyond it the lexical states aren't followed anymore.
  class MacroCodeMatcher < Crystal::Visitor
    # Maximum number of the lexical states followed
    MAX_STATES = 64

    # Maximum number of bytes scanned, in all of the lexical states
    MAX_SCANNED_BYTES = 256 * 1024

    # Number of bytes each scan is counted as on top of the scanned ones,
    # as its overhead outweighs the scanning of a short macro literal
    SCAN_OVERHEAD_BYTES = 64

    getter? matches = false

    # Scanners in each of the lexical states the macro code might be in
    @scanners = [MacroCodeScanner.new]

    # Whether there were more lexical states than `MAX_STATES`
    @overflown = false

    # Number of bytes left to scan, before the lexical states
    # aren't followed anymore
    @scan_budget = MAX_SCANNED_BYTES

    def initialize(node, @regex : Regex)
      node.accept(self)
    end

    # Returns `true` if the macro code *node* (i.e. the `{{ ... }}`
    # expression or the `{% if ... %}` condition) matches.
    protected def macro_code_matches?(node : Crystal::ASTNode) : Bool
      false
    end

    def visit(node : Crystal::MacroLiteral)
      scan(node.value)
      false
    end

    # Scans the subsequent macro literals as a whole, as the macro lexer
    # splits them i.e. at each `#`, while a regex literal isn't known
    # to be one before its end (`/a#{b}c/` is split into `/a`, `#`, `{b}c/`).
    def visit(node : Crystal::Expressions)
      literals = [] of String

      node.expressions.each do |exp|
        if exp.is_a?(Crystal::MacroLiteral)
          literals << exp.value
          next
        end
        scan(literals.join) unless literals.empty?
        literals.clear
        exp.accept(self) unless @matches
      end
      scan(literals.join) unless literals.empty?
      false
    end

    private def scan(code : String) : Nil
      @scan_budget -= (code.bytesize + SCAN_OVERHEAD_BYTES) * @scanners.size unless exhausted?
      return if @matches ||= (@overflown || exhausted?) && code.matches?(@regex)
      return if exhausted?

      # Only a `/` might be ambiguous
      return scan_unambiguous(code) unless code.includes?('/')

      scanners = [] of MacroCodeScanner

      @scanners.each do |scanner|
        flipped = scanner.flipped
        scanners << scanner
        return if @matches ||= scanner.scan(code).matches?(@regex)

        # Follows the other reading of the ambiguous `/`
        next unless scanner.ambiguous?
        scanners << flipped
        return if @matches ||= flipped.scan(code).matches?(@regex)
      end
      self.scanners = scanners
    end

    private def scan_unambiguous(code : String) : Nil
      @matches ||= @scanners.any?(&.scan(code).matches?(@regex))
      self.scanners = @scanners
    end

    # Returns `true` if the lexical states aren't followed anymore
    private def exhausted? : Bool
      @scan_budget.negative?
    end

    private def scanners=(scanners : Array(MacroCodeScanner)) : Nil
      @scanners = scanners.uniq
      return unless @scanners.size > MAX_STATES

      @scanners = @scanners.first(MAX_STATES)
      @overflown = true
    end

    def visit(node : Crystal::MacroExpression)
      @scanners.each(&.after_value!) if node.output?

      !(@matches ||= macro_code_matches?(node.exp))
    end

    def visit(node : Crystal::MacroFor)
      return false if @matches ||= macro_code_matches?(node.exp)

      case iterations = static_iterations(node)
      when nil
        visit_repeatedly(node.body)
      when 0
        visit_skipped(node.body)
      else
        iterations.times do
          scanners = @scanners.map(&.clone)
          node.body.accept(self)
          # Each of the following iterations would end in the same states
          break if @matches || exhausted? || @scanners == scanners
        end
      end
      false
    end

    # Returns the number of the loop iterations if it iterates over
    # a literal (i.e. `{% for x in [1, 2] %}`)
    private def static_iterations(node : Crystal::MacroFor) : Int32?
      case exp = node.exp
      when Crystal::ArrayLiteral, Crystal::TupleLiteral
        exp.elements.size unless exp.elements.any?(Crystal::Splat)
      when Crystal::HashLiteral, Crystal::NamedTupleLiteral
        exp.entries.size
      end
    end

    def visit(node : Crystal::MacroIf)
      return false if @matches ||= macro_code_matches?(node.cond)
      return visit_alternatives(node.then, node.else) unless taken = static_branch(node)

      visit_skipped(taken.same?(node.then) ? node.else : node.then)
      taken.accept(self) unless @matches
      false
    end

    # Returns the branch taken if the condition is a literal
    private def static_branch(node : Crystal::MacroIf) : Crystal::ASTNode?
      case cond = node.cond
      when Crystal::BoolLiteral
        cond.value ? node.then : node.else
      when Crystal::NilLiteral
        node.else
      when Crystal::NumberLiteral, Crystal::CharLiteral,
           Crystal::StringLiteral, Crystal::StringInterpolation,
           Crystal::SymbolLiteral, Crystal::RegexLiteral,
           Crystal::ArrayLiteral, Crystal::TupleLiteral,
           Crystal::HashLiteral, Crystal::NamedTupleLiteral,
           Crystal::RangeLiteral
        # Any other literal is truthy
        node.then
      end
    end

    # Visits the *node* never expanded (i.e. the branch of `{% if false %}`,
    # or the `else` of `{% begin %}`) - it's still searched, but the code
    # following it continues in the current lexical states.
    private def visit_skipped(node : Crystal::ASTNode) : Nil
      scanners, overflown = @scanners, @overflown
      @scanners = @scanners.map(&.clone)
      node.accept(self)
      @scanners, @overflown = scanners, overflown
    end

    # Visits the *node* expanded any number of times (no times at all
    # included), starting in the current lexical states, until it leaves
    # the code in no new ones - the code following it continues in any of them.
    private def visit_repeatedly(node : Crystal::ASTNode) : Nil
      states = @scanners.to_set
      expanded = @scanners

      until expanded.empty?
        @scanners = expanded.map(&.clone)
        node.accept(self)
        return if @matches || exhausted?

        expanded = @scanners.select { |scanner| states.add?(scanner) }
        next unless states.size > MAX_STATES

        # The lexical states left unfollowed are covered by
        # matching the node as is
        @overflown = true
        node.accept(self)
        break
      end
      self.scanners = states.to_a unless @matches
    end

    # Visits each of the alternative *nodes* starting in the current lexical
    # states, continuing in any of the states they end in. Returns `false`.
    private def visit_alternatives(*nodes : Crystal::ASTNode) : Bool
      initial_scanners = @scanners
      final_scanners = [] of MacroCodeScanner

      nodes.each_with_index do |node, index|
        # The last alternative can take over the initial scanners
        @scanners = index == nodes.size - 1 ? initial_scanners : initial_scanners.map(&.clone)
        node.accept(self)
        return false if @matches

        final_scanners.concat(@scanners)
      end
      self.scanners = final_scanners
      false
    end

    def visit(node : Crystal::ASTNode)
      !@matches
    end
  end
end
