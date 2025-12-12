require "./ameba/cli/cmd"

begin
  exit Ameba::CLI.run ? 0 : 1
rescue ex
  STDERR.puts "Error: #{ex.message}"
  exit 255
end
