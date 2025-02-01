# Need to point to the stdlib of the current Crystal installation.
# TODO: verify this works on Windows
#
# https://github.com/elbywan/crystalline/blob/bfb0b3b912c64f4f316d56a8e7481261c0edfdca/src/crystalline/main.cr#L25
module Ameba::EnvironmentConfig
  # Add the `crystal env` environment variables to the current env.
  def self.run : Nil
    initialize_from_crystal_env.each do |k, v|
      ENV[k] = v
    end
  end

  private def self.initialize_from_crystal_env
    crystal_env
      .lines
      .map(&.split('='))
      .to_h
  end

  private def self.crystal_env
    String.build do |io|
      Process.run("crystal", ["env"], output: io)
    end
  end
end
