require "./ameba/cli/cmd"

{% if Fiber.has_constant?(:ExecutionContext) %}
  Fiber::ExecutionContext
    .default
    .resize(Fiber::ExecutionContext.default_workers_count)
{% end %}

begin
  exit Ameba::CLI.run ? 0 : 1
rescue ex
  STDERR.puts "Error: #{ex.message}"
  exit 255
end
