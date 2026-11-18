module Ameba::AST
  # Matches the code of the macro literals within a node (that is, without
  # the comments and literals) against a regex.
  #
  # As the macro branches and loops might leave the code in different
  # lexical states (i.e. `{% if foo %}# bar{% end %}baz`), the code following
  # them is scanned in each of these, matching if it does in any of them.
  #
  # NOTE: Beyond `MAX_STATES` lexical states, the code is assumed to match,
  # as their number might grow exponentially with the number of branches.
  class MacroCodeMatcher < Crystal::Visitor
    # Maximum number of the lexical states followed
    MAX_STATES = 64

    getter? matches = false

    # Scanners in each of the lexical states the macro code might be in
    @scanners = [MacroCodeScanner.new]

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
      @matches ||= @scanners.any?(&.scan(code).matches?(@regex))
    end

    def visit(node : Crystal::MacroExpression)
      @scanners.each(&.after_value!) if node.output?

      !(@matches ||= macro_code_matches?(node.exp))
    end

    def visit(node : Crystal::MacroFor)
      return false if @matches ||= macro_code_matches?(node.exp)

      # The loop body might be expanded no times at all
      visit_alternatives(node.body, Crystal::Nop.new)
    end

    def visit(node : Crystal::MacroIf)
      return false if @matches ||= macro_code_matches?(node.cond)
      return visit_alternatives(node.then, node.else) unless taken = static_branch(node)

      # A branch never taken (i.e. `{% if false %}`, or the `else` of
      # `{% begin %}`) is still searched, but the code following it
      # continues only in the lexical states of the other one
      skipped = taken.same?(node.then) ? node.else : node.then
      scanners, @scanners = @scanners, @scanners.map(&.clone)
      skipped.accept(self)
      @scanners = scanners
      taken.accept(self) unless @matches
      false
    end

    # Returns the branch taken if the condition is a literal
    private def static_branch(node : Crystal::MacroIf) : Crystal::ASTNode?
      case cond = node.cond
      when Crystal::BoolLiteral then cond.value ? node.then : node.else
      when Crystal::NilLiteral  then node.else
      end
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
      @scanners = final_scanners.uniq
      @matches = true if @scanners.size > MAX_STATES
      false
    end

    def visit(node : Crystal::ASTNode)
      !@matches
    end
  end
end
