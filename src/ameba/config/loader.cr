class Ameba::Config
  # By default config loads `.ameba.yml` file located in a current
  # working directory.
  #
  # If it cannot be found until reaching the root directory, then it will be
  # searched for in the user’s global config locations, which consists of a
  # dotfile or a config file inside the XDG Base Directory specification.
  #
  # - `~/.ameba.yml`
  # - `$XDG_CONFIG_HOME/ameba/config.yml` (expands to `~/.config/ameba/config.yml`
  #   if `$XDG_CONFIG_HOME` is not set)
  #
  # If both files exist, the dotfile will be selected.
  #
  # As an example, if Ameba is invoked from inside `/path/to/project/lib/utils`,
  # then it will use the config as specified inside the first of the following files:
  #
  # - `/path/to/project/lib/utils/.ameba.yml`
  # - `/path/to/project/lib/.ameba.yml`
  # - `/path/to/project/.ameba.yml`
  # - `/path/to/.ameba.yml`
  # - `/path/.ameba.yml`
  # - `/.ameba.yml`
  # - `~/.ameba.yml`
  # - `~/.config/ameba/config.yml`
  module Loader
    extend self

    XDG_CONFIG_HOME = ENV.fetch("XDG_CONFIG_HOME", "~/.config")

    FILENAME      = ".ameba.yml"
    DEFAULT_PATH  = Path[Dir.current] / FILENAME
    DEFAULT_PATHS = {
      Path["~"] / FILENAME,
      Path[XDG_CONFIG_HOME] / "ameba" / "config.yml",
    }

    # Creates a new instance of `Ameba::Config` based on YAML parameters.
    #
    # `Config.load` uses this constructor to instantiate new config by YAML file.
    protected def from_yaml(config : YAML::Any, root = nil)
      config = YAML.parse("{}") if config.raw.nil?
      config.raw.is_a?(Hash) ||
        raise "Invalid config file format"

      rules = Rule.rules.map(&.new(config).as(Rule::Base))

      new(
        rules: rules,
        root: root,
        excluded: load_array_section(config, "Excluded", DEFAULT_EXCLUDED.dup).to_set,
        globs: load_array_section(config, "Globs", DEFAULT_GLOBS.dup).to_set,
        version: load_string_key(config, "Version"),
        formatter: load_string_key(config, "Formatter", "Name"),
      )
    end

    # Loads YAML configuration file by `path`.
    #
    # ```
    # config = Ameba::Config.load
    # ```
    def load(path : Path | String? = nil, root : Path? = nil, skip_reading_config : Bool = false)
      unless skip_reading_config
        content =
          if path
            read_config(path: path)
          else
            read_config(root: root)
          end
      end
      content ||= "{}"

      from_yaml(YAML.parse(content), root)
    rescue ex
      raise "Unable to load config file: #{ex.message}"
    end

    protected def read_config(*, path : Path | String)
      unless File.exists?(path)
        raise "Config file #{path.to_s.inspect} does not exist"
      end
      File.read(path)
    end

    protected def read_config(*, root : Path?)
      path = root ? root / FILENAME : DEFAULT_PATH

      if config_path = find_config_path(path)
        File.read(config_path)
      end
    end

    # Returns the closest directory containing either a config file or a `shard.yml`,
    # starting from *path* if it's a directory, or from its parent otherwise.
    #
    # Returns `nil` if there's no such directory.
    #
    # ```
    # Ameba::Config.find_root_path("/path/to/project/src/foo.cr") # => Path["/path/to/project"]
    # ```
    def find_root_path(path : Path | String) : Path?
      path = Path[path]

      search_paths = path.parents
      search_paths << path if File.directory?(path)

      search_paths
        .reverse_each
        .find(&->root_path?(Path))
        .try(&.expand(home: true))
    end

    private def root_path?(path : Path) : Bool
      File.exists?(path / FILENAME) ||
        File.exists?(path / "shard.yml")
    end

    # Returns the path of the config file that applies to *path*, which should
    # point to a config file. Looks for a `.ameba.yml` file in the directories
    # of *path*, from the closest one up to the root directory, then in the
    # user’s global config locations (see `DEFAULT_PATHS`).
    #
    # Returns `nil` if there's no such file.
    #
    # ```
    # Ameba::Config.find_config_path("/path/to/project/.ameba.yml") # => Path["/path/to/.ameba.yml"]
    # ```
    def find_config_path(path : Path | String) : Path?
      path = Path[path]

      path.parents.reverse_each do |search_path|
        config_path =
          search_path / FILENAME
        return config_path if File.exists?(config_path)
      end

      DEFAULT_PATHS.each do |default_path|
        return default_path if File.exists?(default_path)
      end
    end

    private def load_string_key(config, *path)
      config.dig?(*path).try(&.as_s).presence
    end

    private def load_array_section(config, section_name, default = [] of String)
      case value = config[section_name]?
      when .nil?  then default
      when .as_s? then [value.as_s]
      when .as_a? then value.as_a.map(&.as_s)
      else
        raise "Incorrect `#{section_name}` section in a config file"
      end
    end
  end
end
