module Ameba::AST
  # Represents the branch in Crystal code.
  # Branch is a part of a branchable statement.
  # For example, the branchable if statement contains 3 branches:
  #
  # ```
  # if a = something # --> cond branch (Crystal::Assign)
  #   a = 1          # --> then branch (Crystal::Expressions)
  #   put a
  # else
  #   do_something a # --> else branch (Crystal::Call)
  # end
  # ```
  #
  class Branch
    # The actual branch node.
    getter node

    delegate to_s, to: @node
    delegate location, to: @node

    # Creates a new branch.
    #
    # ```
    # Branch.new(if_node)
    # ```
    def initialize(@node : Crystal::ASTNode)
    end

    # Constructs a new branch based on the node in some parent node.
    #
    # ```
    # Branch.of(assign_node, def_node)
    # ```
    def self.of(node : Crystal::ASTNode, parent : Crystal::ASTNode)
      visitor = BranchVisitor.new(node).tap &.accept(parent)
      if branch_node = visitor.branch_node
        Branch.new(branch_node)
      end
    end

    # :nodoc:
    private class BranchVisitor < Crystal::Visitor
      @current_branch : Crystal::ASTNode?

      property branch_node : Crystal::ASTNode?

      def initialize(@node : Crystal::ASTNode)
      end

      def visit(node : Crystal::ASTNode)
        return false if @branch_node

        if node.class == @node.class && node.location == @node.location
          @branch_node = @current_branch
        end

        true
      end

      def visit(node : Crystal::If)
        search_branch_in node.cond, node.then, node.else
      end

      def visit(node : Crystal::Unless)
        search_branch_in node.cond, node.then, node.else
      end

      def visit(node : Crystal::BinaryOp)
        search_branch_in node.left, node.right
      end

      def visit(node : Crystal::Case)
        search_branch_in [node.cond, node.whens, node.else].flatten
      end

      def visit(node : Crystal::While)
        search_branch_in node.cond, node.body
      end

      def visit(node : Crystal::Until)
        search_branch_in node.cond, node.body
      end

      def visit(node : Crystal::ExceptionHandler)
        search_branch_in [node.body, node.rescues, node.else, node.ensure].flatten
      end

      def visit(node : Crystal::Rescue)
        search_branch_in node.body
      end

      private def search_branch_in(*branches)
        search_branch_in(branches)
      end

      private def search_branch_in(branches : Array | Tuple)
        branches.each do |branch|
          break if branch_node # branch found
          next unless branch
          @current_branch = branch
          branch.accept(self)
        end

        false
      end
    end
  end
end
