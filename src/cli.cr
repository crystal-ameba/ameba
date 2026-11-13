require "./ameba/cli/cmd"

{% if Fiber.has_constant?(:ExecutionContext) %}
  Fiber::ExecutionContext
    .default
    .resize(Fiber::ExecutionContext.default_workers_count)
{% end %}

begin
  exit Ameba::CLI.exit_code.value
rescue ex
  STDERR.puts "Error: #{ex.message}"
  exit Ameba::CLI::ExitCode::Aborted.value
end
