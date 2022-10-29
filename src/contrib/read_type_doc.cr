require "compiler/crystal/syntax/*"

private class DocFinder < Crystal::Visitor
  getter type_name : String
  getter doc : String?

  def initialize(nodes, @type_name)
    self.accept(nodes)
  end

  def visit(node : Crystal::ASTNode)
    return false if @doc

    if node.responds_to?(:name) && (name = node.name).is_a?(Crystal::Path)
      @doc = node.doc if name.names.last? == @type_name
    end

    true
  end
end

type_name, path_to_source_file = ARGV

source = File.read(path_to_source_file)
nodes = Crystal::Parser.new(source)
  .tap(&.wants_doc = true)
  .parse

puts DocFinder.new(nodes, type_name).doc
