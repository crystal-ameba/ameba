require "llvm/lib_llvm"
require "compiler/crystal/annotatable"
require "compiler/crystal/tools/dependencies"
require "compiler/crystal/compiler"
require "compiler/crystal/config"
require "compiler/crystal/crystal_path"
require "compiler/crystal/error"
require "compiler/crystal/exception"
require "compiler/crystal/formatter"
require "compiler/crystal/loader"
require "compiler/crystal/macros"
require "compiler/crystal/program"
require "compiler/crystal/progress_tracker"
require "compiler/crystal/semantic"
require "compiler/crystal/syntax"
require "compiler/crystal/types"
require "compiler/crystal/syntax/**"
require "compiler/crystal/semantic/**"
require "compiler/crystal/macros/**"
require "compiler/crystal/codegen/**"

class Ameba::SemanticContext
  def self.for_entrypoint(sources : Array(Source)) : SemanticContext
    EnvironmentConfig.run

    crystal_sources = sources.map { |i| Crystal::Compiler::Source.new(i.path, i.code) }

    result = semantic(crystal_sources)

    new(result.program, result.node)
  end

  def self.for_entrypoint(path : String) : SemanticContext
    EnvironmentConfig.run

    sources = [Crystal::Compiler::Source.new(path, File.read(path))]

    result = semantic(sources)

    new(result.program, result.node)
  end

  # Generates a top-level semantic of just the primitives (Int32, String, etc)
  def self.primitive_context(code : String) : SemanticContext
    EnvironmentConfig.run

    source = Source.new("", %(require "primitive"\n#{code}))
    node = source.ast

    dev_null = File.open(File::NULL, "w")

    program = Crystal::Program.new
    program.color = false
    program.wants_doc = false
    program.stdout = dev_null

    node = program.normalize node
    root, _ = program.top_level_semantic(node)

    new(program, root)
  end

  # Executes the Crystal compiler to generate top-level semantic information about
  # the given code. Will raise if there are semantic errors.
  def self.semantic(sources : Array(Crystal::Compiler::Source)) : Crystal::Compiler::Result
    EnvironmentConfig.run

    reply_channel = Channel(Crystal::Compiler::Result | Exception).new

    spawn do
      dev_null = File.open(File::NULL, "w")

      compiler = Crystal::Compiler.new
      compiler.no_codegen = true
      compiler.color = false
      compiler.no_cleanup = true
      compiler.wants_doc = false
      compiler.stdout = dev_null
      compiler.stderr = dev_null

      reply = compiler.top_level_semantic(sources)

      reply_channel.send(reply)
    rescue e : Exception
      reply_channel.send(e)
    ensure
      dev_null.try &.close
    end

    result = reply_channel.receive

    # Should fail `Lint/Semantic`
    raise result if result.is_a? Exception

    result
  end

  getter program : Crystal::Program
  getter node : Crystal::ASTNode

  def initialize(@program, @node)
  end
end
